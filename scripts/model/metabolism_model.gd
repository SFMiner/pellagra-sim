class_name MetabolismModel
extends RefCounted
## One simplified cell: glycolysis, the matrix stage (pyruvate oxidation + citric acid cycle), fermentation,
## electron transport, the proton gradient, ATP synthase and ATP use.
## Every number is a normalized classroom index, not a measured human value (see SCIENCE_MODEL.md).
## The NAD pool is one aggregate pool: NAD_total = NAD+ + NADH. It is conserved by every step here;
## only set_nad_total() (slow nutrition) changes it. Nothing in this file knows about nodes or drawing.

# === CONSTANTS ===
const SUBSTEP: float = 0.02
const PYRUVATE_MAX: float = 2.0

# === INPUTS (set by the controller) ===
var nad_total: float = 1.0
## Fuel supply index (calories): 0.5 low, 1.0 adequate, 1.5 high.
var glucose: float = 1.0
var oxygen: float = 1.0
## 0 = normal, up to 1 = NADH oxidation by the electron transport chain fully impeded.
var etc_block: float = 0.0
## ATP demand (work the cell is asked to do), in ATP units per second.
var demand: float = 0.45

# === STATE ===
var nadh: float = 0.35
var pyruvate: float = 0.1
var gradient: float = 0.5
## Fraction of the adenine pool that is ATP (the rest is ADP).
var atp: float = 0.8

# === OUTPUTS (rates during the last substep, per second) ===
var glycolysis_flux: float = 0.0
var matrix_flux: float = 0.0
var ferment_flux: float = 0.0
var etc_flux: float = 0.0
var synthase_flux: float = 0.0
var substrate_atp: float = 0.0
var oxidative_atp: float = 0.0
var atp_production: float = 0.0
var atp_use: float = 0.0

# === PRIVATE VARIABLES ===
var _p: Dictionary = {}


# === LIFECYCLE METHODS ===
func _init(parameters: Dictionary) -> void:
	_p = parameters


# === PUBLIC METHODS ===
func nad_plus() -> float:
	return maxf(nad_total - nadh, 0.0)


func nadh_fraction() -> float:
	return clampf(nadh / maxf(nad_total, 1e-6), 0.0, 1.0)


## Slow change of the carrier pool. A smaller pool loses NAD+ and NADH in proportion (turnover without
## enough replacement); a larger pool gains new carriers as NAD+.
func set_nad_total(value: float) -> void:
	var v: float = clampf(value, 0.01, 1.0)
	if v < nad_total:
		nadh *= v / nad_total
	nad_total = v
	nadh = clampf(nadh, 0.0, nad_total)


## Advances `dt` seconds of cell time in stable substeps.
func step(dt: float) -> void:
	if not is_finite(dt) or dt <= 0.0:
		return
	var n: int = maxi(int(ceil(dt / SUBSTEP - 1e-9)), 1)
	var h: float = dt / float(n)
	for i: int in range(n):
		_substep(h)


## Runs to a steady state for the current inputs (used at reset and for the population table).
func settle(seconds: float = 60.0) -> void:
	var n: int = int(seconds / 0.04)
	for i: int in range(n):
		_substep(0.04)


## Fraction of the demanded work that is actually being done (1 = all of it).
func work_fraction() -> float:
	return clampf(atp_use / maxf(demand, 1e-6), 0.0, 1.0)


## ATP made per second as a fraction of ATP demanded per second.
func supply_ratio() -> float:
	return atp_production / maxf(demand, 1e-6)


func copy_inputs_from(other: MetabolismModel) -> void:
	nad_total = other.nad_total
	glucose = other.glucose
	oxygen = other.oxygen
	etc_block = other.etc_block
	demand = other.demand


func start_state() -> void:
	nadh = nad_total * 0.35
	pyruvate = 0.1
	gradient = 0.5
	atp = 0.8


## Work fraction at steady state for a cell with this NAD pool and the given inputs. Pure: makes its own model.
static func steady_work(parameters: Dictionary, p_nad_total: float, source: MetabolismModel) -> float:
	var m: MetabolismModel = MetabolismModel.new(parameters)
	m.copy_inputs_from(source)
	m.nad_total = clampf(p_nad_total, 0.01, 1.0)
	m.start_state()
	m.settle()
	return m.work_fraction()


func state_dict() -> Dictionary:
	return {"nad_total": nad_total, "nadh": nadh, "pyruvate": pyruvate, "gradient": gradient, "atp": atp}


# === PRIVATE METHODS ===
static func _sat(x: float, k: float) -> float:
	return x / (x + k) if x > 0.0 else 0.0


func _substep(h: float) -> void:
	var np: float = maxf(nad_total - nadh, 0.0)
	var adp: float = 1.0 - atp
	var jg: float = float(_p["v_glycolysis"]) * _sat(glucose, float(_p["k_glucose"])) * _sat(np, float(_p["k_nad_plus"])) \
			* _sat(adp, float(_p["k_adp_glycolysis"]))
	var jm: float = float(_p["v_matrix"]) * _sat(pyruvate, float(_p["k_pyruvate"])) * _sat(np, float(_p["k_nad_plus"]))
	# Fermentation follows the redox balance: it runs when most of the pool is NADH (squared ratio).
	var ratio: float = nadh / maxf(nad_total, 1e-6)
	var jf: float = float(_p["v_ferment"]) * _sat(pyruvate, float(_p["k_pyruvate_ferment"])) * ratio * ratio \
			* _sat(nadh, float(_p["k_nadh_ferment"]))
	var je: float = float(_p["v_etc"]) * _sat(nadh, float(_p["k_nadh"])) * _sat(oxygen, float(_p["k_oxygen"])) \
			* maxf(1.0 - gradient, 0.0) * clampf(1.0 - etc_block, 0.0, 1.0)
	var js: float = float(_p["v_synthase"]) * gradient * _sat(adp, float(_p["k_adp_synthase"]))
	# No step may take more than is there.
	jf = minf(jf, minf(nadh, pyruvate) / h * 0.5)
	jm = minf(jm, maxf(pyruvate / h * 0.5 - jf, 0.0))
	je = minf(je, maxf(nadh / h * 0.5 - jf, 0.0))
	var red: float = jg + float(_p["nadh_per_matrix"]) * jm
	if red * h > np:
		var scale: float = np / maxf(red * h, 1e-12)
		jg *= scale
		jm *= scale
		red *= scale
	var sub_atp: float = float(_p["atp_per_glycolysis"]) * jg + float(_p["atp_per_matrix"]) * jm
	var ox_atp: float = float(_p["atp_per_synthase"]) * js
	var kd: float = float(_p["k_atp_work"])
	var use: float = demand * atp * (1.0 + kd) / (atp + kd) if atp > 0.0 else 0.0

	nadh = clampf(nadh + (red - je - jf) * h, 0.0, nad_total)
	pyruvate = clampf(pyruvate + (jg - jm - jf) * h, 0.0, PYRUVATE_MAX)
	gradient = clampf(gradient + (je - js - float(_p["gradient_leak"]) * gradient) / float(_p["gradient_capacity"]) * h, 0.0, 1.0)
	atp = clampf(atp + (sub_atp + ox_atp - use) / float(_p["atp_capacity"]) * h, 0.0, 1.0)

	glycolysis_flux = jg
	matrix_flux = jm
	ferment_flux = jf
	etc_flux = je
	synthase_flux = js
	substrate_atp = sub_atp
	oxidative_atp = ox_atp
	atp_production = sub_atp + ox_atp
	atp_use = use
