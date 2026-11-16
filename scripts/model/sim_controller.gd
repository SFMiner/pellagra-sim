class_name SimController
extends Node
## The one authority over the scientific state. It owns the parameters, the two clocks (SkSession) and
## the four models, and it is the only thing that changes them. Views read from it and never write.
##   main clock (session): live cell time; with a time lapse chosen it also advances nutritional
##                         and population time (the same body-time domain, in days).
##   decomposition clock (decomp_session): storage days for the two food samples. Independent.
## Display choices (view, language, open panels) are NOT stored here and can never change this state.

# === SIGNALS ===
## Any scientific state changed (a step, a setting, a reset).
signal updated
## The food or its processing changed. `food_changed` is true when the food source itself changed.
signal diet_changed(food_changed: bool)
## The run history or the kept runs changed in a way that needs graphs rebuilt.
signal history_changed
signal decomp_updated

# === CONSTANTS ===
const TABLE_POINTS: int = 17
const SNAPSHOT_SLOTS: PackedStringArray = ["baseline", "a", "b"]
const HISTORY_COLUMNS: PackedStringArray = ["day", "niacin_sufficiency_pct", "nad_pool_pct", "atp_pct", "work_done_pct", "modeled_strained_or_risk_pct"]

# === PUBLIC VARIABLES ===
var data: SimData = null
var params: SkParams = SkParams.new()
var decomp_params: SkParams = SkParams.new()
var session: SkSession = SkSession.new()
var decomp_session: SkSession = SkSession.new()
var log: SkLog = SkLog.new()
var nutrition: NutritionModel = NutritionModel.new()
var metabolism: MetabolismModel = null
var population: PopulationModel = PopulationModel.new()
var samples: Array[DecompositionModel] = [DecompositionModel.new(), DecompositionModel.new()]
## True while the niacin slider, not the food, sets usable niacin.
var niacin_custom: bool = false
## Nutritional / population time, in days.
var days: float = 0.0
var hist_days: PackedFloat64Array = PackedFloat64Array()
var hist_atp: PackedFloat64Array = PackedFloat64Array()
var hist_nad: PackedFloat64Array = PackedFloat64Array()
var hist_risk: PackedFloat64Array = PackedFloat64Array()
## slot -> {"profile", "custom", "niacin", "calories", "workload", "days", "atp", "nad", "risk"}
var snapshots: Dictionary = {}

# === PRIVATE VARIABLES ===
var _work_table: PackedFloat64Array = PackedFloat64Array()
var _table_dirty: bool = true
var _applying: bool = false
var _next_sample: float = 0.0


# === PUBLIC METHODS ===
func setup(p_data: SimData) -> void:
	data = p_data
	metabolism = MetabolismModel.new(data.model["metabolism"])
	nutrition.tau_days = float(data.model["nutrition"]["tau_days"])
	nutrition.nad_min = float(data.model["nutrition"]["nad_min"])
	population.setup(data.model["population"])
	_define_params()
	params.changed.connect(_on_param_changed)
	decomp_params.changed.connect(_on_decomp_param_changed)

	session.name = "MainClock"
	session.mode = SkSession.Mode.FIXED_STEP
	session.clock.step = float(data.model["step_seconds"])
	session.speed = 1.0
	session.params = params
	session.on_step = _on_step
	session.on_reset = _on_reset
	add_child(session)
	log.app_name = "pellagra-mystery"
	log.attach(session, params)

	decomp_session.name = "DecompositionClock"
	decomp_session.mode = SkSession.Mode.FIXED_STEP
	decomp_session.clock.step = float(data.model["decomposition"]["step_days"])
	decomp_session.speed = float(data.model["decomposition"]["days_per_second"])
	decomp_session.duration = float(data.model["decomposition"]["days"])
	decomp_session.on_step = _on_decomp_step
	decomp_session.on_reset = _on_decomp_reset
	add_child(decomp_session)

	_sync_niacin()
	session.reset()
	decomp_session.reset()


func food_id() -> String:
	return str(data.foods["foods"][params.get_int("food")])


## "untreated", "nixtamalized", "unfortified", "fortified" or "" (a food with no processing choice).
func processing_id() -> String:
	var options: Array = data.foods["processing"][food_id()]
	if options.is_empty():
		return ""
	return str(options[params.get_int("proc_" + food_id())])


func profile_id() -> String:
	return data.profile_id(food_id(), processing_id())


func profile() -> Dictionary:
	return data.profile(profile_id())


## Usable niacin index the food alone would give.
func food_usable() -> float:
	return NutritionModel.usable_niacin(profile())


## Usable niacin index in force now (the food's value, or the custom slider value).
func usable_now() -> float:
	return params.get_float("niacin") / 100.0 if niacin_custom else food_usable()


func use_food_niacin() -> void:
	niacin_custom = false
	_sync_niacin()
	log.record("niacin_custom", {"on": false})
	updated.emit()


func cohort() -> Dictionary:
	return data.cohorts[params.get_int("cohort")]


func lapse_days_per_second() -> float:
	return float(data.model["lapse_days_per_second"][params.get_int("lapse")])


## Conceptual tissue indicator: the cell's work fraction raised to a tissue's energy sensitivity.
func organ_function(id: String) -> float:
	return pow(metabolism.work_fraction(), float(data.model["organs"].get(id, 1.0)))


func work_table() -> PackedFloat64Array:
	_ensure_table()
	return _work_table


## Keeps a copy of this run's curves under "baseline", "a" or "b". The label is generated from settings.
func keep_snapshot(slot: String) -> void:
	if not SNAPSHOT_SLOTS.has(slot):
		return
	snapshots[slot] = {
		"profile": profile_id(), "custom": niacin_custom, "niacin": params.get_float("niacin"),
		"calories": params.get_int("calories"), "workload": params.get_int("workload"),
		"days": hist_days.duplicate(), "atp": hist_atp.duplicate(), "nad": hist_nad.duplicate(), "risk": hist_risk.duplicate(),
	}
	log.keep_run(slot, {"day": Array(hist_days), "atp_pct": Array(hist_atp), "nad_pool_pct": Array(hist_nad),
			"modeled_strained_or_risk_pct": Array(hist_risk)}, {"profile": profile_id(), "custom_niacin": niacin_custom})
	history_changed.emit()


func clear_snapshots() -> void:
	snapshots.clear()
	log.kept_runs.clear()
	history_changed.emit()


## Everything scientific, as text. Two equal digests mean nothing in any model or clock changed.
func state_digest() -> String:
	return JSON.stringify({
		"params": params.to_dict(), "decomp_params": decomp_params.to_dict(), "custom": niacin_custom,
		"days": days, "s": nutrition.sufficiency, "cell": metabolism.state_dict(),
		"time": session.sim_time, "steps": session.step_count, "state": int(session.state),
		"pop": population.state_dict(), "d_time": decomp_session.sim_time, "d_state": int(decomp_session.state),
		"a": samples[0].state_dict(), "b": samples[1].state_dict(),
		"hist": hist_days.size(), "snaps": snapshots.keys(),
	})


func sample_id(index: int) -> String:
	return str(data.sample_ids()[decomp_params.get_int("sample_a" if index == 0 else "sample_b")])


# === PRIVATE METHODS ===
func _define_params() -> void:
	# Labels and choice names are placeholders here: the UI sets them from the language catalogs.
	params.add(SkParam.choice_param("food", "food", PackedStringArray(["whole", "degermed", "diverse"]), 0))
	params.add(SkParam.choice_param("proc_whole", "proc_whole", PackedStringArray(["untreated", "nixtamalized"]), 0))
	params.add(SkParam.choice_param("proc_degermed", "proc_degermed", PackedStringArray(["unfortified", "fortified"]), 0))
	var niacin: SkParam = SkParam.float_param("niacin", "niacin", 100.0, 0.0, 200.0, 1.0)
	niacin.decimals = 0
	params.add(niacin.with_unit("%"))
	params.add(SkParam.choice_param("calories", "calories", PackedStringArray(["low", "adequate", "high"]), 1))
	params.add(SkParam.choice_param("workload", "workload", PackedStringArray(["resting", "active"]), 0))
	params.add(SkParam.choice_param("lapse", "lapse", PackedStringArray(["cell", "day", "week", "month"]), 2))
	var cohort_ids: PackedStringArray = PackedStringArray()
	for c: Dictionary in data.cohorts:
		cohort_ids.append(str(c["id"]))
	params.add(SkParam.choice_param("cohort", "cohort", cohort_ids, 0))
	params.add(SkParam.choice_param("oxygen", "oxygen", PackedStringArray(["normal", "low"]), 0))
	params.add(SkParam.choice_param("etc_block", "etc_block", PackedStringArray(["normal", "impeded"]), 0))
	var sample_ids: PackedStringArray = PackedStringArray()
	for s: Variant in data.sample_ids():
		sample_ids.append(str(s))
	decomp_params.add(SkParam.choice_param("sample_a", "sample_a", sample_ids, 0))
	decomp_params.add(SkParam.choice_param("sample_b", "sample_b", sample_ids, 1))
	decomp_params.add(SkParam.choice_param("temperature", "temperature", PackedStringArray(["cold", "room", "warm"]), 1))
	decomp_params.add(SkParam.choice_param("humidity", "humidity", PackedStringArray(["dry", "humid", "wet"]), 1))
	decomp_params.add(SkParam.choice_param("air", "air", PackedStringArray(["open", "sealed"]), 0))


func _sync_niacin() -> void:
	if niacin_custom:
		return
	var was: bool = _applying
	_applying = true
	params.set_value("niacin", roundf(food_usable() * 100.0))
	_applying = was


func _apply_inputs() -> void:
	var inputs: Dictionary = data.model["inputs"]
	metabolism.glucose = float(inputs["calories"][params.get_int("calories")])
	metabolism.demand = float(inputs["demand"][params.get_int("workload")])
	metabolism.oxygen = float(inputs["oxygen"][params.get_int("oxygen")])
	metabolism.etc_block = float(inputs["etc_block"][params.get_int("etc_block")])


func _on_param_changed(id: String, _value: Variant) -> void:
	if _applying:
		return
	_applying = true
	match id:
		"food":
			# A new food starts from its own default processing, shown explicitly, and from its own niacin.
			params.reset("proc_whole")
			params.reset("proc_degermed")
			niacin_custom = false
			params.set_value("cohort", 0)
			_follow_sample()
		"proc_whole", "proc_degermed":
			niacin_custom = false
			params.set_value("cohort", 0)
			_follow_sample()
		"cohort":
			_apply_cohort()
		"niacin":
			# Any niacin change that is not the controller's own (the slider) is an explicit custom setting.
			niacin_custom = true
		"calories", "workload", "oxygen", "etc_block":
			_table_dirty = true
	_applying = false
	_sync_niacin()
	_apply_inputs()
	if session.state == SkSession.State.READY and id != "lapse" and id != "niacin":
		_equilibrate()
	if id == "food" or id == "proc_whole" or id == "proc_degermed" or id == "cohort":
		diet_changed.emit(id == "food" or id == "cohort")
	updated.emit()


func _apply_cohort() -> void:
	var c: Dictionary = cohort()
	var food: String = str(c.get("food", ""))
	if food == "":
		return
	var foods: Array = data.foods["foods"]
	params.set_value("food", foods.find(food))
	params.reset("proc_whole")
	params.reset("proc_degermed")
	var options: Array = data.foods["processing"][food]
	if not options.is_empty():
		params.set_value("proc_" + food, maxi(options.find(str(c.get("processing", ""))), 0))
	niacin_custom = false
	_follow_sample()


## Storage sample A follows the food chosen in the main controls (the one piece of shared state).
func _follow_sample() -> void:
	var index: int = data.sample_ids().find(str(profile().get("sample", "")))
	if index >= 0:
		decomp_params.set_value("sample_a", index)


func _equilibrate() -> void:
	metabolism.set_nad_total(nutrition.nad_capacity())
	metabolism.start_state()
	metabolism.settle()


func _ensure_table() -> void:
	if not _table_dirty and not _work_table.is_empty():
		return
	_work_table.resize(TABLE_POINTS)
	var lo: float = nutrition.nad_min
	for i: int in range(TABLE_POINTS):
		var nad: float = lo + (1.0 - lo) * float(i) / float(TABLE_POINTS - 1)
		_work_table[i] = MetabolismModel.steady_work(data.model["metabolism"], nad, metabolism)
	_table_dirty = false


func _on_reset() -> void:
	nutrition.sufficiency = float(data.model["nutrition"]["start_sufficiency"])
	days = 0.0
	_apply_inputs()
	_table_dirty = true
	_equilibrate()
	population.reset(nutrition.sufficiency)
	hist_days.clear()
	hist_atp.clear()
	hist_nad.clear()
	hist_risk.clear()
	log.table("history", HISTORY_COLUMNS)
	_sample()
	_next_sample = float(data.model["sample_every_days"])
	history_changed.emit()
	updated.emit()


func _on_step(dt: float) -> void:
	var day_step: float = dt * lapse_days_per_second()
	if day_step > 0.0:
		nutrition.step(day_step, usable_now())
		metabolism.set_nad_total(nutrition.nad_capacity())
	metabolism.step(dt)
	if day_step > 0.0:
		_ensure_table()
		population.step(day_step, usable_now(), cohort(), _work_table, nutrition.tau_days, nutrition.nad_min)
		days += day_step
		var every: float = float(data.model["sample_every_days"])
		if days + 1e-9 >= _next_sample:
			_sample()
			_next_sample = (floorf(days / every) + 1.0) * every
	updated.emit()


func _sample() -> void:
	var risk: float = population.affected_percent()
	hist_days.append(days)
	hist_atp.append(metabolism.atp * 100.0)
	hist_nad.append(metabolism.nad_total * 100.0)
	hist_risk.append(risk)
	if hist_days.size() > 6000:
		# A very long run keeps every other point, so memory and drawing stay bounded.
		hist_days = _every_other(hist_days)
		hist_atp = _every_other(hist_atp)
		hist_nad = _every_other(hist_nad)
		hist_risk = _every_other(hist_risk)
		history_changed.emit()
	log.add_row("history", [snappedf(days, 0.01), snappedf(nutrition.sufficiency * 100.0, 0.1),
			snappedf(metabolism.nad_total * 100.0, 0.1), snappedf(metabolism.atp * 100.0, 0.1),
			snappedf(metabolism.work_fraction() * 100.0, 0.1), snappedf(risk, 0.1)])


static func _every_other(series: PackedFloat64Array) -> PackedFloat64Array:
	var kept: PackedFloat64Array = PackedFloat64Array()
	for i: int in range(0, series.size(), 2):
		kept.append(series[i])
	return kept


func _on_decomp_param_changed(id: String, _value: Variant) -> void:
	# A different sample is a different experiment: start it again. Conditions may change mid-run.
	if id == "sample_a" or id == "sample_b":
		decomp_session.reset()
	decomp_updated.emit()


func _on_decomp_reset() -> void:
	for i: int in range(2):
		samples[i].setup(data.model["decomposition"], data.sample(sample_id(i)))
	decomp_updated.emit()


func _on_decomp_step(dt: float) -> void:
	for s: DecompositionModel in samples:
		s.step(dt, decomp_params.get_int("temperature"), decomp_params.get_int("humidity"), decomp_params.get_int("air"))
	decomp_updated.emit()
