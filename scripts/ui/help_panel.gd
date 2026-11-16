class_name HelpPanel
extends PanelContainer
## Help: what the sandbox is, how to use it, the molecule key, the keyboard keys and its limits.

# === SIGNALS ===
signal close_requested

# === CONSTANTS ===
const PARAGRAPHS: PackedStringArray = ["help.what", "help.start", "help.diet", "help.time", "help.views", "help.food",
		"help.compare", "help.model", "help.keyboard", "help.limits"]

# === PUBLIC VARIABLES ===
var a11y: SkA11y = null
var close_button: Button = null

# === PRIVATE VARIABLES ===
var _scroll: KeyScroll = null
var _body: VBoxContainer = null


# === PUBLIC METHODS ===
func setup(p_a11y: SkA11y) -> void:
	a11y = p_a11y
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	close_button = SkUi.button("")
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close_button.pressed.connect(func() -> void: close_requested.emit())
	Loc.main.bind(close_button, "text", "ui.close")
	root.add_child(close_button)
	_scroll = KeyScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)
	a11y.changed.connect(refresh_text)
	refresh_text()


func focus_controls() -> Array[Control]:
	var out: Array[Control] = []
	out.append(close_button)
	out.append(_scroll)
	return out


func set_focus_color(color: Color) -> void:
	_scroll.focus_color = color


func refresh_text() -> void:
	for child: Node in _body.get_children():
		child.queue_free()
		_body.remove_child(child)
	_body.add_child(SkUi.heading(Loc.t("help.title")))
	for i: int in range(PARAGRAPHS.size()):
		_body.add_child(SkUi.label(Loc.t(PARAGRAPHS[i]), 0, true))
		if PARAGRAPHS[i] == "help.views":
			_body.add_child(SkUi.label(Loc.t("help.key_title"), 0, true))
			var key: MoleculeKey = MoleculeKey.new()
			key.palette = SkTheme.palette(a11y.palette_name())
			key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_body.add_child(key)


## The molecule key: each icon exactly as the cell view draws it, with its name.
class MoleculeKey extends Control:
	const ROWS: PackedStringArray = ["nad", "nadh", "atp", "adp", "glucose", "pyruvate", "oxygen", "co2", "proton", "electrons", "niacin"]
	var palette: Dictionary = SkTheme.DARK

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		custom_minimum_size = Vector2(240.0, float(ROWS.size()) * 30.0 + 6.0)

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var fs: int = maxi(get_theme_default_font_size() - 2, 12)
		for i: int in range(ROWS.size()):
			var c: Vector2 = Vector2(34.0, 18.0 + float(i) * 30.0)
			match ROWS[i]:
				"nad":
					PmDraw.nad(self, font, c, 1.0, false)
				"nadh":
					PmDraw.nad(self, font, c, 1.0, true)
				"atp":
					PmDraw.atp(self, font, c, 1.0, true)
				"adp":
					PmDraw.atp(self, font, c, 1.0, false)
				"glucose":
					PmDraw.glucose(self, c, 1.0)
				"pyruvate":
					PmDraw.pyruvate(self, c, 1.2)
				"oxygen":
					PmDraw.oxygen(self, c, 1.2)
				"co2":
					PmDraw.co2(self, c, 1.2)
				"proton":
					PmDraw.proton(self, c, 1.3)
				"electrons":
					PmDraw.electron_pair(self, c, 1.4)
				"niacin":
					PmDraw.niacin(self, font, c, 0.95)
			draw_string(font, Vector2(76.0, c.y + float(fs) * 0.35), Loc.t("key." + ROWS[i]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 80.0, fs, palette["text"])
