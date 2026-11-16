class_name NutritionModel
extends RefCounted
## Diet -> usable niacin -> slow body sufficiency S (0..1) -> size of the cell's NAD pool.
## Indices only (1.0 usable niacin = the illustrative reference). See SCIENCE_MODEL.md.

# === PUBLIC VARIABLES ===
## Days for S to close about 63% of the gap to its target. A teaching time scale, not a clinical one.
var tau_days: float = 40.0
var nad_min: float = 0.08
var sufficiency: float = 1.0


# === PUBLIC METHODS ===
## The parts of usable niacin for a food profile.
static func breakdown(profile: Dictionary) -> Dictionary:
	var content: float = float(profile.get("niacin_content", 0.0))
	var available: float = content * float(profile.get("niacin_bioavailability", 0.0))
	return {
		"content": content,
		"absorbed": available,
		"bound": content - available,
		"tryptophan": float(profile.get("tryptophan_contribution", 0.0)),
		"fortification": float(profile.get("fortification", 0.0)),
	}


## niacin content x bioavailable fraction + simplified tryptophan equivalents + fortification.
static func usable_niacin(profile: Dictionary) -> float:
	var b: Dictionary = breakdown(profile)
	return float(b["absorbed"]) + float(b["tryptophan"]) + float(b["fortification"])


static func target_for(usable: float) -> float:
	return clampf(usable, 0.0, 1.0)


## S_next = S + (S_target - S) * (1 - exp(-dt / tau)). Exact for any dt, so any time lapse is stable.
static func relax(s: float, target: float, days: float, tau: float) -> float:
	if days <= 0.0:
		return s
	return clampf(s + (target - s) * (1.0 - exp(-days / maxf(tau, 1e-6))), 0.0, 1.0)


func step(days: float, usable: float) -> void:
	sufficiency = relax(sufficiency, target_for(usable), days, tau_days)


static func nad_for(s: float, p_nad_min: float) -> float:
	return p_nad_min + (1.0 - p_nad_min) * clampf(s, 0.0, 1.0)


func nad_capacity() -> float:
	return nad_for(sufficiency, nad_min)
