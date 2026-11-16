class_name Loc
extends RefCounted
## Project-owned localization (SimKit has none). Nothing here knows about the simulation.
##
## Files in res://locale/ (plain JSON, editable without touching code):
##   registry.json        which languages exist, in button order, and which is the default
##   <code>.json          one flat catalog per language: "key": "text"   ({name} marks a value put in by code)
##   simkit_strings.json  the English literals hard-coded inside SimKit, each mapped to a catalog key
##
##   Loc.t("status.day", {"day": 12})          text in the current language
##   Loc.main.bind(button, "text", "ui.help")  keeps a property in step with the language
##   Loc.main.cycle()                          switch to the next language in the registry
##
## The language is never saved: every visit starts in the registry's default (English).
## Adding a language = one catalog file + one registry line. No code or model changes.
##
## SimKit's own text is covered two ways, without editing SimKit:
##   - text on its Buttons and Labels goes through Godot's TranslationServer (controls auto-translate),
##     so each literal ("Start", "Reset"...) is registered as a message for every language;
##   - its screen-reader announcements are fixed English strings sent straight to the page, so on the web
##     a small wrapper around window.skAnnounce swaps them (translate_announcement() is the same rule here).

# === SIGNALS ===
signal changed

# === CONSTANTS ===
const DIR: String = "res://locale/"
const WRAP_JS: String = "(function(){if(window.__pmWrap){return;}window.__pmWrap=true;" \
		+ "window.__pmMap={exact:{},prefix:{},suffix:{}};var orig=window.skAnnounce;" \
		+ "window.skAnnounce=function(t,a){var m=window.__pmMap,k;t=String(t);" \
		+ "if(Object.prototype.hasOwnProperty.call(m.exact,t)){t=m.exact[t];}else{" \
		+ "for(k in m.prefix){if(t.indexOf(k)===0){t=m.prefix[k]+t.slice(k.length);break;}}" \
		+ "for(k in m.suffix){if(t.length>=k.length&&t.lastIndexOf(k)===t.length-k.length){t=t.slice(0,t.length-k.length)+m.suffix[k];break;}}}" \
		+ "if(orig){orig(t,a);}};})();"

# === STATIC VARIABLES ===
## The catalog set the whole UI reads. Set once at start-up (tests may make their own).
static var main: Loc = null

# === PUBLIC VARIABLES ===
## [{"code": "en", "name": "English"}, ...] in button order.
var languages: Array[Dictionary] = []
var default_code: String = "en"
var code: String = "en"
## Keys asked for that no catalog had. Empty in a correct build; tests check it.
var missing: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()

# === PRIVATE VARIABLES ===
var _catalogs: Dictionary = {}
var _simkit: Dictionary = {}
var _translations: Dictionary = {}
var _bound: Array[Dictionary] = []


# === PUBLIC METHODS ===
static func t(key: String, args: Dictionary = {}) -> String:
	return main.text(key, args) if main != null else key


func load_all() -> bool:
	errors.clear()
	var registry: Variant = SimData.read_json(DIR + "registry.json")
	if not (registry is Dictionary):
		errors.append("registry.json")
		return false
	default_code = str(registry.get("default", "en"))
	for entry: Variant in registry.get("languages", []):
		var lang: String = str(entry.get("code", ""))
		var catalog: Variant = SimData.read_json(DIR + str(entry.get("file", lang + ".json")))
		if lang == "" or not (catalog is Dictionary):
			errors.append("language " + lang)
			continue
		_catalogs[lang] = catalog
		languages.append({"code": lang, "name": str(entry.get("name", lang))})
	var sk: Variant = SimData.read_json(DIR + "simkit_strings.json")
	_simkit = sk if sk is Dictionary else {}
	if not _catalogs.has(default_code):
		errors.append("default language")
		return false
	for lang: String in _catalogs:
		var tr_res: Translation = Translation.new()
		tr_res.locale = lang
		for literal: String in _simkit.get("ui", {}):
			tr_res.add_message(literal, _lookup(lang, str(_simkit["ui"][literal])))
		_translations[lang] = tr_res
		TranslationServer.add_translation(tr_res)
	code = default_code
	TranslationServer.set_locale(code)
	_push_web()
	return errors.is_empty()


func has_language(lang: String) -> bool:
	return _catalogs.has(lang)


func keys(lang: String) -> Array:
	return (_catalogs.get(lang, {}) as Dictionary).keys()


func has_key(key: String, lang: String = "") -> bool:
	return (_catalogs.get(lang if lang != "" else code, {}) as Dictionary).has(key)


## Text for `key` in the current language, with {name} places filled from `args`.
func text(key: String, args: Dictionary = {}) -> String:
	var s: String = _lookup(code, key)
	return s.format(args) if not args.is_empty() else s


func text_in(lang: String, key: String, args: Dictionary = {}) -> String:
	var s: String = _lookup(lang, key)
	return s.format(args) if not args.is_empty() else s


## Switches language now. Changes text only: no model, clock or setting is touched.
func set_language(lang: String) -> bool:
	if not _catalogs.has(lang):
		return false
	code = lang
	TranslationServer.set_locale(lang)
	for i: int in range(_bound.size() - 1, -1, -1):
		var b: Dictionary = _bound[i]
		var target: Object = (b["ref"] as WeakRef).get_ref()
		if target == null:
			_bound.remove_at(i)
		else:
			target.set(str(b["prop"]), text(str(b["key"])))
	_push_web()
	changed.emit()
	return true


## The language the button offers: the next one in the registry (with two languages, the other one).
func next_language() -> Dictionary:
	for i: int in range(languages.size()):
		if languages[i]["code"] == code:
			return languages[(i + 1) % languages.size()]
	return languages[0]


func cycle() -> void:
	set_language(str(next_language()["code"]))


## Sets `target.prop` to the text for `key` now and after every language change.
func bind(target: Object, prop: String, key: String) -> void:
	target.set(prop, text(key))
	_bound.append({"ref": weakref(target), "prop": prop, "key": key})


## Registers the translation of one more SimKit-built literal for the current language (for the strings
## SimKit assembles itself, such as "Observe: " + your prompt).
func add_literal(source: String, translated: String) -> void:
	if _translations.has(code):
		(_translations[code] as Translation).add_message(source, translated)


## What a SimKit announcement becomes in the current language (the web wrapper applies the same rule).
func translate_announcement(source: String) -> String:
	var m: Dictionary = announcement_map()
	if (m["exact"] as Dictionary).has(source):
		return str(m["exact"][source])
	var out: String = source
	for k: String in m["prefix"]:
		if out.begins_with(k):
			out = str(m["prefix"][k]) + out.substr(k.length())
			break
	for k: String in m["suffix"]:
		if out.ends_with(k):
			out = out.substr(0, out.length() - k.length()) + str(m["suffix"][k])
			break
	return out


func announcement_map() -> Dictionary:
	var out: Dictionary = {"exact": {}, "prefix": {}, "suffix": {}}
	var rules: Dictionary = _simkit.get("announce", {})
	for kind: String in out:
		for literal: String in rules.get(kind, {}):
			out[kind][literal] = _lookup(code, str(rules[kind][literal]))
	return out


## Every literal the SimKit table lists, with its catalog key (tests check the keys exist).
func simkit_keys() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for literal: String in _simkit.get("ui", {}):
		out.append(str(_simkit["ui"][literal]))
	for kind: String in _simkit.get("announce", {}):
		for literal: String in _simkit["announce"][kind]:
			out.append(str(_simkit["announce"][kind][literal]))
	return out


# === PRIVATE METHODS ===
func _lookup(lang: String, key: String) -> String:
	var catalog: Dictionary = _catalogs.get(lang, {})
	if catalog.has(key):
		return str(catalog[key])
	missing[lang + ":" + key] = true
	var fallback: Dictionary = _catalogs.get(default_code, {})
	if fallback.has(key):
		return str(fallback[key])
	return "[" + key + "]"


## Page-side language: <html lang>, the canvas label, the title and the announcement wrapper. Web only.
func _push_web() -> void:
	if self != main and main != null:
		return
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(WRAP_JS)
	JavaScriptBridge.eval("window.__pmMap=%s;document.documentElement.lang=%s;document.title=%s;" % [
			JSON.stringify(announcement_map()), JSON.stringify(code), JSON.stringify(_lookup(code, "app.title"))]
			+ "var c=document.getElementById('canvas');if(c){c.setAttribute('aria-label',%s);}" % JSON.stringify(_lookup(code, "app.canvas_label")))
