class_name DecompositionModel
extends RefCounted
## One stored food sample being used by microbes. Matter is never lost: what leaves the food is counted
## as microbial biomass, CO2, other released products, or transformed residue (total() stays constant).
## Growth = r_max x f(temperature) x f(water) x f(oxygen) x f(substrate), each f in 0..1.
## Fat rancidity is a separate chemical index: it is not microbial and moves no matter between pools here.
## Illustrative only: not a validated growth law for any species or food.

# === STATE ===
var food: float = 1.0
var microbes: float = 0.0
var co2: float = 0.0
var other: float = 0.0
var residue: float = 0.0
## Water available to microbes in the sample (water activity, 0..1). Drifts toward the storage air.
var water: float = 0.6
var rancidity: float = 0.0
var day: float = 0.0
## Growth factor during the last step (0..1), for the read-out.
var activity: float = 0.0

# === PRIVATE VARIABLES ===
var _cfg: Dictionary = {}
var _sample: Dictionary = {}


# === PUBLIC METHODS ===
func setup(cfg: Dictionary, sample: Dictionary) -> void:
	_cfg = cfg
	_sample = sample
	reset()


func reset() -> void:
	food = 1.0
	microbes = float(_cfg.get("start_microbes", 0.002))
	co2 = 0.0
	other = 0.0
	residue = 0.0
	water = float(_sample.get("moisture_factor", 0.6))
	rancidity = 0.0
	day = 0.0
	activity = 0.0


func total() -> float:
	return food + microbes + co2 + other + residue


static func water_factor(aw: float, cfg: Dictionary) -> float:
	var lo: float = float(cfg["aw_min"])
	var hi: float = float(cfg["aw_max"])
	return pow(clampf((aw - lo) / (hi - lo), 0.0, 1.0), float(cfg["aw_power"]))


## `temp`, `humidity` and `air` are indices into the config's option lists.
func growth_factor(temp: int, air: int) -> float:
	var substrate: float = float(_sample.get("spoilage_susceptibility", 1.0)) * food / (food + float(_cfg["k_substrate"]))
	return clampf(float(_cfg["temp_factor"][temp]) * water_factor(water, _cfg) * float(_cfg["oxygen_factor"][air]) * substrate, 0.0, 1.0)


func step(dt: float, temp: int, humidity: int, air: int) -> void:
	if dt <= 0.0:
		return
	# Split into small pieces so the explicit update stays stable.
	var n: int = maxi(int(ceil(dt / 0.05 - 1e-9)), 1)
	var h: float = dt / float(n)
	for i: int in range(n):
		water = clampf(water + float(_sample.get("moisture_exchange", 0.1)) * (float(_cfg["ambient_aw"][humidity]) - water) * h, 0.0, 1.0)
		activity = growth_factor(temp, air)
		var uptake: float = minf(float(_cfg["r_max"]) * activity * microbes * h, food)
		var growth: float = float(_cfg["yield"]) * uptake
		var released: float = uptake - growth
		var to_co2: float = released * float(_cfg["co2_share"][air])
		var died: float = minf(float(_cfg["death"]) * microbes * h, microbes)
		food -= uptake
		microbes += growth - died
		co2 += to_co2
		other += released - to_co2
		residue += died
		var fat: float = float(_sample.get("lipid_content", 0.0))
		rancidity = clampf(rancidity + float(_cfg["rancidity_rate"]) * fat * float(_cfg["rancid_oxygen"][air]) \
				* float(_cfg["rancid_temp"][temp]) * (1.0 - rancidity) * h, 0.0, 1.0)
	day += dt


func state_dict() -> Dictionary:
	return {"food": food, "microbes": microbes, "co2": co2, "other": other, "residue": residue, "water": water,
			"rancidity": rancidity, "day": day}
