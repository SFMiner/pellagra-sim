class_name SimData
extends RefCounted
## Loads the editable data files in res://data/. No model logic here.

# === PUBLIC VARIABLES ===
var model: Dictionary = {}
var foods: Dictionary = {}
var cohorts: Array = []
var studies: Array = []
var errors: PackedStringArray = PackedStringArray()


# === PUBLIC METHODS ===
static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data


func load_all() -> bool:
	errors.clear()
	model = _dict("res://data/model.json")
	foods = _dict("res://data/foods.json")
	var c: Dictionary = _dict("res://data/cohorts.json")
	cohorts = c.get("cohorts", [])
	var h: Dictionary = _dict("res://data/historical.json")
	studies = h.get("studies", [])
	return errors.is_empty()


func profile(id: String) -> Dictionary:
	return (foods["profiles"] as Dictionary).get(id, {})


## "whole" + "nixtamalized" -> "whole_nixtamalized"; a food with no processing choice is its own profile.
func profile_id(food: String, processing: String) -> String:
	var options: Array = (foods["processing"] as Dictionary).get(food, [])
	if options.is_empty():
		return food
	if not options.has(processing):
		processing = str(options[0])
	return food + "_" + processing


func sample(id: String) -> Dictionary:
	return (foods["samples"] as Dictionary).get(id, {})


func sample_ids() -> Array:
	return foods["sample_order"]


# === PRIVATE METHODS ===
func _dict(path: String) -> Dictionary:
	var v: Variant = read_json(path)
	if v is Dictionary:
		return v
	errors.append(path)
	return {}
