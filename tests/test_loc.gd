extends "res://tests/pm_test.gd"
## Localization checks that need no window: the catalogs agree with each other, with the code, with the data
## files and with the English text hard-coded in SimKit; the font has every character; the rules that
## translate SimKit's announcements work.

const TEXT_EXTENSIONS: PackedStringArray = [".json", ".gd", ".tscn", ".png", ".csv", ".cfg", ".svg", ".html"]
## English literals in SimKit that need no catalog entry, each with the reason.
const SIMKIT_HANDLED: Dictionary = {
	"Text size": "label replaced through ParamText (param.text_size.label)",
	"High contrast": "label replaced through ParamText",
	"Reduced motion": "label replaced through ParamText",
	"Normal": "choice replaced through ParamText",
	"Large": "choice replaced through ParamText",
	"Extra large": "choice replaced through ParamText",
	"Makes all text and controls larger.": "help replaced through ParamText",
	"Black background, white text, thick outlines.": "help replaced through ParamText",
	"Stops drifting, pulsing and sliding animation. Results do not change.": "help replaced through ParamText",
	"On": "announcement ending, covered by the ': On' rule",
	"Off": "announcement ending, covered by the ': Off' rule",
	"Lesson: %s (hide)": "registered at run time with the title (sk.lesson_hide / sk.lesson_show)",
	"Lesson (hide)": "not shown: the prompts always have a title",
	"Predict": "not shown: no prediction prompt is used",
	"Reflect": "not shown: no reflection prompts are used",
	"Observe": "registered at run time with each prompt (sk.observe)",
	"Speed %sx": "not shown: both transport bars hide the speed button",
	"Value": "SkGauge.describe() is not used",
	"Reset settings": "in the table (sk.reset_settings); every panel here hides that button",
}


func _placeholders(s: String) -> Array:
	var out: Array = []
	var from: int = 0
	while true:
		var a: int = s.find("{", from)
		if a < 0:
			break
		var b: int = s.find("}", a)
		if b < 0:
			break
		out.append(s.substr(a, b - a + 1))
		from = b + 1
	out.sort()
	return out


func _files(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_files(dir_path + "/" + sub, out)
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path + "/" + file)


## Every double-quoted literal in a script, skipping comment lines.
func _literals(path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	for line: String in file.get_as_text().split("\n"):
		var code: String = line.strip_edges()
		if code.begins_with("#"):
			continue
		var from: int = 0
		while true:
			var a: int = code.find("\"", from)
			if a < 0:
				break
			var b: int = a + 1
			while b < code.length() and (code[b] != "\"" or code[b - 1] == "\\"):
				b += 1
			if b >= code.length():
				break
			out.append(code.substr(a + 1, b - a - 1))
			from = b + 1
	return out


func _is_key(s: String) -> bool:
	if not s.contains(".") or s.begins_with(".") or s.ends_with(".") or s.ends_with("_") or s.contains("://") or s.contains(".."):
		return false
	for ext: String in TEXT_EXTENSIONS:
		if s.ends_with(ext):
			return false
	for i: int in range(s.length()):
		var ch: String = s[i]
		if not ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "."):
			return false
	return true


func run() -> void:
	test_name = "localization"
	var loc: Loc = Loc.new()
	Loc.main = loc
	check(loc.load_all(), "catalogs load without errors: %s" % str(loc.errors))
	check(loc.default_code == "en" and loc.code == "en", "the default language is English")
	check(loc.languages.size() >= 2 and loc.has_language("es"), "English and Spanish are registered")
	check(TranslationServer.get_locale() == "en", "the engine locale is forced to English at start, whatever the device says")
	check(str(loc.next_language()["name"]) == "Español", "in English the button offers: Español")

	# --- The two catalogs agree
	var en: Array = loc.keys("en")
	var es: Array = loc.keys("es")
	var only_en: Array = en.filter(func(k: String) -> bool: return not es.has(k))
	var only_es: Array = es.filter(func(k: String) -> bool: return not en.has(k))
	check(only_en.is_empty(), "every English key has Spanish text (missing: %s)" % str(only_en))
	check(only_es.is_empty(), "no Spanish key lacks English text (extra: %s)" % str(only_es))
	var bad_places: Array = []
	var empty: Array = []
	var same: Array = []
	for key: String in en:
		var a: String = loc.text_in("en", key)
		var b: String = loc.text_in("es", key)
		if _placeholders(a) != _placeholders(b):
			bad_places.append(key)
		if a.strip_edges() == "" or b.strip_edges() == "":
			empty.append(key)
		if a == b and a.length() > 8:
			same.append(key)
	check(bad_places.is_empty(), "both languages use the same {places} in every text (differ: %s)" % str(bad_places))
	check(empty.is_empty(), "no text is empty (%s)" % str(empty))
	check(same.is_empty(), "no longer text is identical in both languages, i.e. left untranslated (%s)" % str(same))

	# --- Every key the code uses exists; every key in the catalog is used
	var scripts: PackedStringArray = PackedStringArray()
	_files("res://scripts", scripts)
	var used: Dictionary = {}
	for path: String in scripts:
		for lit: String in _literals(path):
			if _is_key(lit):
				used[lit] = path
	var data: SimData = SimData.new()
	data.load_all()
	var c: SimController = make_controller()
	for id: String in data.foods["profiles"]:
		for prefix: String in ["profile.", "kernel.caption.", "kernel.explain."]:
			used[prefix + id] = "data"
	for id: Variant in data.sample_ids():
		for prefix: String in ["sample.", "param.sample_a.", "param.sample_b."]:
			used[prefix + str(id)] = "data"
	for food: String in data.foods["foods"]:
		used["proc.caption." + food] = "data"
	for cohort: Dictionary in data.cohorts:
		used["cohort." + str(cohort["id"])] = "data"
	for study: Dictionary in data.studies:
		for part: String in ["title", "caption", "note"]:
			used["hist.%s.%s" % [study["id"], part]] = "data"
		for row: Dictionary in study["rows"]:
			used["hist.%s.row.%s" % [study["id"], row["key"]]] = "data"
	var a11y: SkA11y = SkA11y.new()
	var ui_params: SkParams = SkParams.new()
	ui_params.add(SkParam.choice_param("metric", "metric", PackedStringArray(["atp", "nad"]), 0))
	for set: Variant in [[c.params, {}], [c.decomp_params, {}], [ui_params, {}], [a11y.params, {"text_size": PackedStringArray(["normal", "large", "xlarge"])}]]:
		var params: SkParams = set[0]
		for id: String in params.ids():
			used["param.%s.label" % id] = "param"
			if loc.has_key("param.%s.help" % id):
				used["param.%s.help" % id] = "param"
			for choice: String in (set[1] as Dictionary).get(id, params.spec(id).choices):
				used["param.%s.%s" % [id, choice]] = "param"
	for id: String in ["cell", "day", "week", "month"]:
		used["status.lapse_" + id] = "code"
	for id: String in ["cell", "population"]:
		used["ui.view_" + id] = "code"
		used["a11y.view_" + id] = "code"
	for id: String in ["food", "evidence", "help"]:
		used["ui.open_" + id] = "code"
		used["a11y.opened_" + id] = "code"
	for id: String in ["diet", "community", "graph", "advanced", "prompts", "display"]:
		used["section." + id] = "code"
	for id: String in ["baseline", "a", "b"]:
		used["snapshot.keep_" + id] = "code"
		used["snapshot.short." + id] = "code"
	for id: String in ["atp", "nad"]:
		used["graph.title_" + id] = "code"
	for id: String in ["food", "microbes", "co2", "other", "residue"]:
		used["decomp.pool." + id] = "code"
	for id: String in ["muscle", "nerve", "gut", "skin"]:
		used["organ." + id] = "code"
	for id: String in ["nad", "nadh", "atp", "adp", "glucose", "pyruvate", "oxygen", "co2", "proton", "electrons", "niacin"]:
		used["key." + id] = "code"
	for key: String in loc.simkit_keys():
		used[key] = "simkit table"
	var absent: Array = []
	for key: String in used:
		if not loc.has_key(key, "en"):
			absent.append("%s (%s)" % [key, used[key]])
	check(absent.is_empty(), "every text the code, the data files and the SimKit table ask for exists (absent: %s)" % str(absent))
	var unused: Array = en.filter(func(k: String) -> bool: return not used.has(k))
	check(unused.is_empty(), "the catalog holds no text that nothing uses (%s)" % str(unused))
	check(used.size() > 250, "the scan found the keys (%d)" % used.size())

	# --- SimKit's hard-coded English: every literal is in the table or has a stated reason
	var sk_files: PackedStringArray = PackedStringArray()
	for folder: String in ["res://addons/simkit/ui", "res://addons/simkit/edu", "res://addons/simkit/viz"]:
		_files(folder, sk_files)
	sk_files.append("res://addons/simkit/core/sk_a11y.gd")
	sk_files.append("res://addons/simkit/core/sk_param.gd")
	var table: Dictionary = SimData.read_json("res://locale/simkit_strings.json")
	var known: Dictionary = {}
	for literal: String in table["ui"]:
		known[literal] = true
	for kind: String in table["announce"]:
		for literal: String in table["announce"][kind]:
			known[literal] = true
			known[literal.strip_edges().trim_prefix(":").trim_suffix(":").strip_edges()] = true
	var uncovered: Array = []
	var seen: int = 0
	for path: String in sk_files:
		for lit: String in _literals(path):
			# Player-facing English starts with a capital letter and has a lower-case word in it.
			if lit.length() < 2 or not (lit[0] >= "A" and lit[0] <= "Z") or lit.to_upper() == lit or lit.begins_with("Sk"):
				continue
			seen += 1
			var bare: String = lit.strip_edges().trim_suffix(":").strip_edges()
			if not known.has(lit) and not known.has(bare) and not SIMKIT_HANDLED.has(lit) and not SIMKIT_HANDLED.has(bare) \
					and not lit.contains("range") and not lit.contains("points") and not lit.contains("no data yet"):
				uncovered.append("%s  <- %s" % [lit, path.get_file()])
	check(uncovered.is_empty(), "no English text inside SimKit is left without a translation route (%s)" % str(uncovered))
	check(seen > 20, "the SimKit scan found its literals (%d)" % seen)
	var gone: Array = []
	var all_sk: String = ""
	for path: String in sk_files:
		all_sk += FileAccess.get_file_as_string(path)
	for literal: String in known:
		if not all_sk.contains("\"" + literal.strip_edges().trim_prefix(":").strip_edges()):
			gone.append(literal)
	check(gone.is_empty(), "every literal in the table still exists in this SimKit copy (%s)" % str(gone))

	# --- The font can draw everything
	var font: Font = ThemeDB.fallback_font
	var no_glyph: Dictionary = {}
	for lang: String in ["en", "es"]:
		for key: String in loc.keys(lang):
			var s: String = loc.text_in(lang, key)
			for i: int in range(s.length()):
				var code: int = s.unicode_at(i)
				if code != 10 and not font.has_char(code):
					no_glyph[s[i]] = key
	check(no_glyph.is_empty(), "the built-in font has every character both languages use (%s)" % str(no_glyph))
	var special: String = "ñáéíóúü¿¡ÑÁÉÍÓÚ⁺₂"
	var have: bool = true
	for i: int in range(special.length()):
		have = have and font.has_char(special.unicode_at(i))
	check(have, "Spanish accents, ñ, inverted punctuation and the formula characters are in the font")

	# --- Switching
	var digest: String = c.state_digest()
	check(loc.set_language("es") and loc.code == "es", "Spanish can be selected")
	check(c.state_digest() == digest, "selecting a language changes no model state")
	check(str(loc.next_language()["name"]) == "English", "in Spanish the button offers: English")
	check(Loc.t("sk.start") == "Iniciar" and TranslationServer.translate("Start") == "Iniciar", "SimKit's Start button text is translated by the engine")
	check(TranslationServer.translate("Reset") == "Reiniciar" and TranslationServer.translate("Pause") == "Pausar", "and so are Reset and Pause")
	check(loc.translate_announcement("Paused") == "En pausa", "a whole SimKit announcement is translated")
	check(loc.translate_announcement("Movimiento reducido: On") == "Movimiento reducido: activado", "an On/Off ending is translated")
	check(loc.translate_announcement("Chosen: maíz") == "Elegido: maíz", "a fixed start is translated")
	check(loc.translate_announcement("Maíz entero") == "Maíz entero", "text that is already ours is left alone")
	check(Loc.t("status.lapse_week").contains("semana") and Loc.t("cell.carriers", {"n": 3, "max": 16}).contains("3 de 16"), "values are placed into Spanish text")
	check(Loc.t("mol.glucose") == "Glucosa" and Loc.t("key.nadh").begins_with("NADH"), "formulas stay as they are; the words around them are translated")
	check(not loc.set_language("xx") and loc.code == "es", "an unknown language is refused")
	loc.set_language("en")
	check(loc.missing.is_empty(), "no key was ever missing (%s)" % str(loc.missing.keys()))
	finish(31)
