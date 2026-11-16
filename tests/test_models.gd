extends "res://tests/pm_test.gd"
## Scientific regression checks: the design document's section 5.6 matrix, plus bounds, conservation,
## mass balance, stability under every time lapse and reproducibility. No window or view is involved.


func _bounded(c: SimController) -> bool:
	var m: MetabolismModel = c.metabolism
	for v: float in [m.nad_total, m.nadh, m.pyruvate, m.gradient, m.atp, m.glycolysis_flux, m.matrix_flux, m.ferment_flux,
			m.etc_flux, m.synthase_flux, m.atp_production, m.atp_use, c.nutrition.sufficiency]:
		if not is_finite(v) or v < -1e-12:
			return false
	return m.nadh <= m.nad_total + 1e-12 and m.atp <= 1.0 and m.gradient <= 1.0 and m.nad_total <= 1.0 \
			and absf(m.nad_plus() + m.nadh - m.nad_total) < 1e-12


func run() -> void:
	test_name = "models"
	var c: SimController = make_controller()
	var p: SkParams = c.params
	var data: SimData = c.data

	# --- Start-up
	check(c.session.state == SkSession.State.READY, "nothing runs until Start")
	check(approx(c.nutrition.sufficiency, 1.0) and approx(c.metabolism.nad_total, 1.0), "the person starts well nourished with a full NAD pool")
	check(c.metabolism.work_fraction() > 0.97, "a well-nourished resting cell does nearly all the work asked")
	check(c.profile_id() == "whole_untreated" and not c.niacin_custom, "default diet is untreated whole corn, niacin from the food")

	# --- Food profiles (nixtamalize / degerm / fortify rows)
	var usable: Dictionary = {}
	for id: String in data.foods["profiles"]:
		usable[id] = NutritionModel.usable_niacin(data.profile(id))
	check(usable["whole_nixtamalized"] > usable["whole_untreated"] + 0.3, "nixtamalizing raises usable niacin")
	check(float(data.profile("whole_nixtamalized")["niacin_content"]) <= float(data.profile("whole_untreated")["niacin_content"]),
			"nixtamalizing creates no niacin: content does not rise")
	check(float(data.profile("degermed_unfortified")["niacin_content"]) < float(data.profile("whole_untreated")["niacin_content"]) * 0.6,
			"degerming lowers niacin content")
	check(usable["degermed_fortified"] > usable["degermed_unfortified"] + 0.5, "fortifying raises niacin adequacy")
	check(approx(float(data.profile("degermed_fortified")["energy_available"]), float(data.profile("degermed_unfortified")["energy_available"])),
			"fortifying adds no calories")
	check(usable["degermed_unfortified"] < usable["whole_untreated"] and usable["whole_untreated"] < usable["whole_nixtamalized"]
			and usable["whole_nixtamalized"] <= usable["degermed_fortified"] and usable["whole_nixtamalized"] <= usable["diverse"],
			"ordering of usable niacin: degermed < untreated whole < nixtamalized <= fortified and diverse")
	check(usable["whole_untreated"] < 0.6, "untreated whole corn alone is not presented as adequate")

	# --- Reduce niacin and advance nutritional time: gradual decline, then limited ATP
	p.set_value("food", 1)
	check(c.profile_id() == "degermed_unfortified", "choosing degermed cornmeal selects Unfortified explicitly")
	check(approx(p.get_float("niacin"), roundf(usable["degermed_unfortified"] * 100.0)), "the niacin indicator follows the food")
	check(approx(c.metabolism.nad_total, 1.0), "changing the food changes nothing in the cell at once")
	c.session.start()
	run_main(c, 0.2)
	check(c.metabolism.nad_total > 0.93, "after 1.4 days the NAD pool has barely moved (no instant collapse)")
	var last: float = c.metabolism.nad_total
	var monotonic: bool = true
	for i: int in range(20):
		run_main(c, 1.0)
		monotonic = monotonic and c.metabolism.nad_total <= last + 1e-12 and _bounded(c)
		last = c.metabolism.nad_total
	check(monotonic, "the NAD pool declines steadily, never jumps, and stays in bounds")
	run_main(c, 40.0)
	check(c.metabolism.nad_total < 0.35, "after about a year on degermed cornmeal the NAD pool is small")
	var deficient_work: float = c.metabolism.work_fraction()
	var deficient_atp: float = c.metabolism.atp
	check(deficient_work < 0.9 and deficient_atp < 0.6, "ATP supply no longer meets resting demand")
	check(c.days > 400.0, "nutritional time advanced with the time lapse")

	# --- More glucose while niacin stays deficient
	p.set_value("calories", 2)
	run_main(c, 10.0)
	check(c.metabolism.work_fraction() < 0.92, "high calories do not restore a niacin-deficient cell")
	check(c.metabolism.work_fraction() - deficient_work < 0.08, "extra fuel helps only slightly")
	p.set_value("calories", 1)

	# --- More workload: demand rises, no nutrient appears
	var nad_before: float = c.metabolism.nad_total
	var usable_before: float = c.usable_now()
	p.set_value("workload", 1)
	check(c.metabolism.demand > 0.8 and approx(c.usable_now(), usable_before) and approx(c.metabolism.nad_total, nad_before),
			"workload raises ATP demand without creating nutrients")
	run_main(c, 6.0)
	check(c.metabolism.work_fraction() < deficient_work, "a deficient cell falls further behind when active")
	p.set_value("workload", 0)

	# --- Restore niacin: gradual recovery
	p.set_value("proc_degermed", 1)
	check(c.profile_id() == "degermed_fortified", "fortified cornmeal selected")
	var low: float = c.metabolism.nad_total
	run_main(c, 0.2)
	check(c.metabolism.nad_total < low + 0.05, "recovery is not instant")
	run_main(c, 40.0)
	check(c.metabolism.nad_total > 0.95 and c.metabolism.work_fraction() > 0.97, "the pool and the work recover with time")

	# --- Direct cellular interventions (time lapse off, so only the cell runs)
	p.set_value("lapse", 0)
	var days_before: float = c.days
	run_main(c, 8.0)
	check(approx(c.days, days_before), "with the time lapse off, days do not pass")
	var base_matrix: float = c.metabolism.matrix_flux
	var base_ox: float = c.metabolism.oxidative_atp
	var base_ferment: float = c.metabolism.ferment_flux
	p.set_value("etc_block", 1)
	run_main(c, 12.0)
	check(c.metabolism.nadh_fraction() > 0.7, "impeding NADH oxidation shifts the pool toward NADH")
	check(c.metabolism.matrix_flux < base_matrix * 0.7, "upstream flux then becomes limited")
	p.set_value("etc_block", 0)
	run_main(c, 12.0)
	p.set_value("oxygen", 1)
	run_main(c, 12.0)
	check(c.metabolism.oxidative_atp < base_ox * 0.5, "restricting oxygen lowers oxidative ATP")
	check(c.metabolism.glycolysis_flux > 0.01 and c.metabolism.ferment_flux > base_ferment * 3.0 and c.metabolism.substrate_atp > 0.01,
			"limited glycolysis continues because fermentation regenerates NAD+")
	p.set_value("oxygen", 0)

	# --- Pause: nothing moves; Step moves exactly one step
	c.session.pause()
	var frozen: String = c.state_digest()
	for i: int in range(50):
		c.session.advance(0.1)
	check(c.state_digest() == frozen, "paused: no state progresses")
	var t: float = c.session.sim_time
	c.session.step_once()
	check(approx(c.session.sim_time, t + float(data.model["step_seconds"])) and c.state_digest() != frozen, "Step advances exactly one step")

	# --- Custom niacin is explicit and reversible
	p.set_value("niacin", 150.0)
	check(c.niacin_custom and approx(c.usable_now(), 1.5), "moving the niacin slider is an explicit custom setting")
	p.set_value("food", 0)
	check(not c.niacin_custom and approx(p.get_float("niacin"), roundf(usable["whole_untreated"] * 100.0)),
			"choosing a food again returns niacin to the food's value")
	p.set_value("niacin", 20.0)
	c.use_food_niacin()
	check(not c.niacin_custom and approx(c.usable_now(), usable["whole_untreated"]), "the custom value can be undone")
	p.set_value("proc_whole", 1)
	p.set_value("food", 1)
	p.set_value("food", 0)
	check(p.get_int("proc_whole") == 0 and p.get_int("proc_degermed") == 0, "a newly chosen food starts from its default processing")

	# --- Reset: starting state back, settings kept
	p.set_value("food", 1)
	c.session.reset()
	check(approx(c.days, 0.0) and approx(c.nutrition.sufficiency, 1.0) and c.session.state == SkSession.State.READY and p.get_int("food") == 1,
			"Reset restores the starting state and keeps the settings")

	# --- Stability and bounds at every time lapse, with settings changing all the time
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var all_ok: bool = true
	c.session.start()
	for i: int in range(3000):
		if i % 40 == 0:
			p.set_value("lapse", rng.randi_range(0, 3))
			p.set_value("food", rng.randi_range(0, 2))
			p.set_value("calories", rng.randi_range(0, 2))
			p.set_value("workload", rng.randi_range(0, 1))
			p.set_value("oxygen", rng.randi_range(0, 1))
			p.set_value("etc_block", rng.randi_range(0, 1))
			if rng.randf() < 0.3:
				p.set_value("niacin", float(rng.randi_range(0, 200)))
		c.session.advance(0.1)
		all_ok = all_ok and _bounded(c)
	check(all_ok, "3000 steps of random settings at every time lapse: all values finite, non-negative, bounded; NAD+ + NADH = pool")
	var pop_ok: bool = true
	for i: int in range(c.population.size):
		pop_ok = pop_ok and c.population.sufficiency[i] >= 0.0 and c.population.sufficiency[i] <= 1.0 \
				and c.population.exposure[i] >= 0.0 and c.population.exposure[i] <= 1.0
	check(pop_ok, "every modeled person stays in bounds")
	c.queue_free()

	# --- The population's table and the live cell agree
	var d: SimController = make_controller()
	d.params.set_value("food", 1)
	d.session.start()
	run_main(d, 80.0)
	var from_table: float = PopulationModel.lookup(d.work_table(), d.metabolism.nad_total, d.nutrition.nad_min)
	check(absf(from_table - d.metabolism.work_fraction()) < 0.03, "the population's steady-state table matches the live cell (%.3f vs %.3f)" % [from_table, d.metabolism.work_fraction()])

	# --- Population presets differ in the expected direction
	var affected: Dictionary = {}
	for index: int in range(1, data.cohorts.size()):
		var e: SimController = make_controller()
		e.params.set_value("cohort", index)
		e.params.set_value("lapse", 3)
		e.session.start()
		run_main(e, 14.0)
		affected[str(data.cohorts[index]["id"])] = e.population.affected_percent()
		e.queue_free()
	check(affected["tenant"] > 40.0 and affected["institution"] > 40.0, "communities limited to degermed cornmeal show high modeled risk after about 14 months")
	check(affected["diverse"] < 5.0 and affected["nixtamal"] < 10.0 and affected["fortified"] < 5.0,
			"diverse, nixtamalized and fortified communities show little modeled risk")
	check(affected["tenant"] < affected["institution"], "households with some access to other foods lower the tenant community's share")
	var f: SimController = make_controller()
	f.params.set_value("cohort", 1)
	check(f.food_id() == "degermed" and f.processing_id() == "unfortified", "a preset sets the shared food and processing")
	f.params.set_value("proc_degermed", 1)
	check(f.params.get_int("cohort") == 0, "changing the diet by hand returns the preset to None")
	f.queue_free()

	# --- Whole untreated corn is marginal, not safe
	var w: SimController = make_controller()
	w.session.start()
	run_main(w, 80.0)
	check(w.metabolism.work_fraction() > 0.95, "untreated whole corn: a resting cell still copes")
	w.params.set_value("workload", 1)
	run_main(w, 10.0)
	check(w.metabolism.work_fraction() < 0.92, "untreated whole corn: an active cell falls short")
	w.queue_free()

	# --- Reproducible
	var a: SimController = make_controller()
	var b: SimController = make_controller()
	for x: SimController in [a, b]:
		x.params.set_value("food", 1)
		x.params.set_value("workload", 1)
		x.session.start()
		run_main(x, 20.0)
	check(a.state_digest() == b.state_digest(), "the same actions give exactly the same state")

	# --- The two clocks are independent
	var main_before: String = JSON.stringify([a.days, a.metabolism.state_dict(), a.session.sim_time])
	a.decomp_session.start()
	for i: int in range(100):
		a.decomp_session.advance(0.1)
	check(a.samples[0].day > 30.0, "the storage clock ran")
	check(JSON.stringify([a.days, a.metabolism.state_dict(), a.session.sim_time]) == main_before, "running the storage clock does not advance the cell or the body")
	var storage_before: String = JSON.stringify([a.samples[0].state_dict(), a.samples[1].state_dict()])
	run_main(a, 5.0)
	check(JSON.stringify([a.samples[0].state_dict(), a.samples[1].state_dict()]) == storage_before, "running the main clock does not advance storage")
	b.params.set_value("food", 2)
	check(b.sample_id(0) == "fruit_veg", "storage sample A follows the food chosen in the main controls")

	# --- Decomposition: matter is conserved and the environment matters
	var cfg: Dictionary = data.model["decomposition"]
	var worst: float = 0.0
	var results: Dictionary = {}
	for id: Variant in data.sample_ids():
		for temp: int in range(3):
			for humid: int in range(3):
				for air: int in range(2):
					var s: DecompositionModel = DecompositionModel.new()
					s.setup(cfg, data.sample(str(id)))
					var start: float = s.total()
					for i: int in range(240):
						s.step(0.25, temp, humid, air)
						worst = maxf(worst, absf(s.total() - start))
					results["%s_%d_%d_%d" % [id, temp, humid, air]] = s
	check(worst < 1e-9, "matter never disappears in any of 108 storage runs (largest drift %s)" % String.num_scientific(worst))
	check((results["degermed_meal_1_0_0"] as DecompositionModel).food > 0.99, "dry cornmeal in dry air barely decomposes")
	check((results["degermed_meal_1_2_0"] as DecompositionModel).food < 0.5, "the same cornmeal in very damp air decomposes")
	check((results["degermed_meal_0_2_0"] as DecompositionModel).food > (results["degermed_meal_2_2_0"] as DecompositionModel).food + 0.2,
			"cold slows decomposition")
	check((results["degermed_meal_1_2_1"] as DecompositionModel).food > (results["degermed_meal_1_2_0"] as DecompositionModel).food,
			"little oxygen slows decomposition")
	check(absf((results["whole_meal_1_1_0"] as DecompositionModel).food - (results["degermed_meal_1_1_0"] as DecompositionModel).food) < 0.25,
			"at matched moisture, whole and degermed meal decompose at a similar rate (no 'processed food cannot rot' rule)")
	check((results["whole_meal_1_0_0"] as DecompositionModel).rancidity > (results["degermed_meal_1_0_0"] as DecompositionModel).rancidity * 2.0,
			"whole-grain meal turns rancid faster than degermed meal: the storage benefit of degerming")
	check((results["fruit_veg_1_0_0"] as DecompositionModel).food < 0.6 and (results["burger_fries_1_0_0"] as DecompositionModel).food > 0.9,
			"in dry air moist fruit decomposes while a burger dries out first")
	check((results["burger_fries_1_2_0"] as DecompositionModel).food < 0.5, "in damp air the burger decomposes too")
	finish(62)
