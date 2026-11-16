class_name PmSection
extends VBoxContainer
## A collapsible group of controls with a header button. The header says whether it is open, in words.

# === SIGNALS ===
signal toggled(open: bool)

# === PUBLIC VARIABLES ===
var title_key: String = ""
var header: Button = null
var body: VBoxContainer = null


# === PUBLIC METHODS ===
static func create(p_title_key: String, open: bool) -> PmSection:
	var s: PmSection = PmSection.new()
	s.title_key = p_title_key
	s.add_theme_constant_override("separation", 6)
	s.header = SkUi.button("", true)
	s.header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	s.header.button_pressed = open
	s.header.toggled.connect(s._on_toggled)
	s.add_child(s.header)
	s.body = VBoxContainer.new()
	s.body.add_theme_constant_override("separation", 8)
	s.body.visible = open
	s.add_child(s.body)
	s.refresh_text()
	return s


func is_open() -> bool:
	return body.visible


func set_open(open: bool) -> void:
	header.set_pressed_no_signal(open)
	body.visible = open
	refresh_text()


func refresh_text() -> void:
	header.text = Loc.t("ui.section_open" if body.visible else "ui.section_closed", {"title": Loc.t(title_key)})


# === PRIVATE METHODS ===
func _on_toggled(open: bool) -> void:
	body.visible = open
	refresh_text()
	SkHost.announce(header.text)
	toggled.emit(open)
