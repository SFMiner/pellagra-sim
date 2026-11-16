class_name ParamText
extends RefCounted
## Gives SkParam specs their words from the language catalogs. A spec's id and its choices' machine names
## never change; only label, choice names, unit and help are rewritten, so values stay exactly as they are.
##   param.<id>.label   param.<id>.help (optional)   param.<id>.unit (optional)   param.<id>.<choice>

# === PRIVATE VARIABLES ===
## SkParams instance id -> {param id -> PackedStringArray of machine choice names}, captured the first time.
static var _machine: Dictionary = {}


# === PUBLIC METHODS ===
## `choice_names` overrides the machine names for params whose spec was built with display words
## (SkA11y's text size).
static func apply(params: SkParams, choice_names: Dictionary = {}) -> void:
	var key: int = params.get_instance_id()
	if not _machine.has(key):
		var captured: Dictionary = {}
		for id: String in params.ids():
			captured[id] = choice_names.get(id, params.spec(id).choices.duplicate())
		_machine[key] = captured
	for id: String in params.ids():
		var spec: SkParam = params.spec(id)
		spec.label = Loc.t("param.%s.label" % id)
		if Loc.main.has_key("param.%s.help" % id, Loc.main.default_code):
			spec.help = Loc.t("param.%s.help" % id)
		if Loc.main.has_key("param.%s.unit" % id, Loc.main.default_code):
			spec.unit = Loc.t("param.%s.unit" % id)
		if spec.kind == SkParam.Kind.CHOICE:
			var names: PackedStringArray = PackedStringArray()
			for machine: String in _machine[key][id]:
				names.append(Loc.t("param.%s.%s" % [id, machine]))
			spec.choices = names


## The machine name of a choice param's current value ("whole", "week"...), whatever the language.
static func machine_value(params: SkParams, id: String) -> String:
	var names: PackedStringArray = _machine.get(params.get_instance_id(), {}).get(id, PackedStringArray())
	var index: int = params.get_int(id)
	return names[index] if index >= 0 and index < names.size() else ""
