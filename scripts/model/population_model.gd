class_name PopulationModel
extends RefCounted
## An illustrative community: each person has a slightly different niacin requirement and a slightly
## different share of other, varied foods. Each follows the same slow sufficiency rule as the cell view's
## person, and the same cell model (through a steady-state table) turns their NAD pool into "work done".
## The output is a modeled risk indicator. It is NOT clinical prevalence and reproduces no historical count.
## Model numbers stay in 64-bit floats (PackedFloat64Array).

# === ENUMS ===
enum Status { MEETING, STRAINED, RISK }

# === PUBLIC VARIABLES ===
var size: int = 120
var household: int = 5
var requirement: PackedFloat64Array = PackedFloat64Array()
var share_noise: PackedFloat64Array = PackedFloat64Array()
var sufficiency: PackedFloat64Array = PackedFloat64Array()
## Smoothed shortfall of work done (0..1): rises only after a shortage has lasted.
var exposure: PackedFloat64Array = PackedFloat64Array()

# === PRIVATE VARIABLES ===
var _cfg: Dictionary = {}


# === PUBLIC METHODS ===
func setup(cfg: Dictionary) -> void:
	_cfg = cfg
	size = int(cfg.get("size", 120))
	household = int(cfg.get("household", 5))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1))
	requirement.resize(size)
	share_noise.resize(size)
	sufficiency.resize(size)
	exposure.resize(size)
	var i: int = 0
	while i < size:
		# People in one household share most of their food access.
		var house_noise: float = rng.randfn(0.0, 1.0)
		for k: int in range(household):
			if i >= size:
				break
			requirement[i] = clampf(1.0 + rng.randfn(0.0, float(cfg.get("requirement_sd", 0.1))), 0.7, 1.3)
			share_noise[i] = house_noise * 0.85 + rng.randfn(0.0, 1.0) * 0.15
			i += 1
	reset(1.0)


func reset(start_sufficiency: float) -> void:
	for i: int in range(size):
		sufficiency[i] = clampf(start_sufficiency, 0.0, 1.0)
		exposure[i] = 0.0


## Usable niacin for person i: mostly the selected diet, partly other varied foods.
func usable_for(i: int, usable_diet: float, cohort: Dictionary) -> float:
	var share: float = clampf(float(cohort.get("diverse_share", 0.0)) + float(cohort.get("share_sd", 0.0)) * share_noise[i], 0.0, 0.6)
	return (1.0 - share) * usable_diet + share * float(_cfg.get("diverse_usable", 1.25))


## `work_table` holds steady-state work fractions for NAD pools evenly spaced from nad_min to 1.
func step(days: float, usable_diet: float, cohort: Dictionary, work_table: PackedFloat64Array, tau_days: float, nad_min: float) -> void:
	if days <= 0.0 or work_table.is_empty():
		return
	var gain: float = 1.0 - exp(-days / maxf(float(_cfg.get("exposure_tau_days", 30.0)), 1e-6))
	for i: int in range(size):
		var target: float = NutritionModel.target_for(usable_for(i, usable_diet, cohort) / requirement[i])
		sufficiency[i] = NutritionModel.relax(sufficiency[i], target, days, tau_days)
		var strain: float = 1.0 - lookup(work_table, NutritionModel.nad_for(sufficiency[i], nad_min), nad_min)
		exposure[i] = clampf(exposure[i] + (strain - exposure[i]) * gain, 0.0, 1.0)


static func lookup(table: PackedFloat64Array, nad: float, nad_min: float) -> float:
	var n: int = table.size()
	if n == 0:
		return 1.0
	if n == 1:
		return table[0]
	var x: float = clampf((nad - nad_min) / maxf(1.0 - nad_min, 1e-9), 0.0, 1.0) * float(n - 1)
	var lo: int = mini(int(floor(x)), n - 2)
	var f: float = x - float(lo)
	return table[lo] * (1.0 - f) + table[lo + 1] * f


func status(i: int) -> Status:
	if exposure[i] >= float(_cfg.get("risk_threshold", 0.15)):
		return Status.RISK
	if exposure[i] >= float(_cfg.get("strained_threshold", 0.05)):
		return Status.STRAINED
	return Status.MEETING


## [meeting, strained, risk]
func counts() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array([0, 0, 0])
	for i: int in range(size):
		out[int(status(i))] += 1
	return out


## Share of people whose smoothed shortfall is past the "strained" line, as a percent (strained + risk).
func affected_percent() -> float:
	var c: PackedInt32Array = counts()
	return 100.0 * float(c[1] + c[2]) / float(maxi(size, 1))


func mean_sufficiency() -> float:
	var total: float = 0.0
	for i: int in range(size):
		total += sufficiency[i]
	return total / float(maxi(size, 1))


func state_dict() -> Dictionary:
	return {"sufficiency": Array(sufficiency), "exposure": Array(exposure)}
