class_name EvidencePanel
extends PanelContainer
## Read-only historical evidence, one study per page. The numbers come from data/historical.json (the
## lesson's source summaries) and are never produced, changed or re-enacted by the simulation.
## Each chart keeps its own labels, counts and units, and the page says plainly that it is a record.

# === SIGNALS ===
signal close_requested

# === PUBLIC VARIABLES ===
var data: SimData = null
var a11y: SkA11y = null
var page: int = 0
var close_button: Button = null
var prev_button: Button = null
var next_button: Button = null

# === PRIVATE VARIABLES ===
var _counter: Label = null
var _scroll: KeyScroll = null
var _body: VBoxContainer = null


# === PUBLIC METHODS ===
func setup(p_data: SimData, p_a11y: SkA11y) -> void:
	data = p_data
	a11y = p_a11y
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var head: HFlowContainer = HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 6)
	root.add_child(head)
	prev_button = SkUi.button("")
	prev_button.pressed.connect(_turn.bind(-1))
	Loc.main.bind(prev_button, "text", "hist.previous")
	head.add_child(prev_button)
	next_button = SkUi.button("")
	next_button.pressed.connect(_turn.bind(1))
	Loc.main.bind(next_button, "text", "hist.next")
	head.add_child(next_button)
	close_button = SkUi.button("")
	close_button.pressed.connect(func() -> void: close_requested.emit())
	Loc.main.bind(close_button, "text", "ui.close")
	head.add_child(close_button)
	_counter = SkUi.label("")
	_counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_counter)
	_scroll = KeyScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	_scroll.add_child(_body)
	a11y.changed.connect(refresh_text)
	refresh_text()


func page_count() -> int:
	return data.studies.size() + 1


func focus_controls() -> Array[Control]:
	var out: Array[Control] = []
	out.append(prev_button)
	out.append(next_button)
	out.append(close_button)
	out.append(_scroll)
	return out


func set_focus_color(color: Color) -> void:
	_scroll.focus_color = color


func refresh_text() -> void:
	for child: Node in _body.get_children():
		child.queue_free()
		_body.remove_child(child)
	_counter.text = Loc.t("hist.counter", {"n": page + 1, "of": page_count()})
	prev_button.disabled = page == 0
	next_button.disabled = page >= page_count() - 1
	_scroll.scroll_vertical = 0
	if page == 0:
		_body.add_child(SkUi.heading(Loc.t("hist.title")))
		for key: String in ["hist.intro", "hist.not_model", "hist.ethics", "hist.categories"]:
			_body.add_child(SkUi.label(Loc.t(key), 0, true))
		return
	var study: Dictionary = data.studies[page - 1]
	var id: String = str(study["id"])
	var title: String = Loc.t("hist.%s.title" % id)
	if str(study.get("year", "")) != "":
		title += " (%s)" % str(study["year"])
	_body.add_child(SkUi.heading(title))
	_body.add_child(SkUi.label(Loc.t("hist.record_tag"), 0, true))
	_body.add_child(SkUi.label(Loc.t("hist.%s.caption" % id), 0, true))
	var chart: Chart = Chart.new()
	chart.study = study
	chart.palette = SkTheme.palette(a11y.palette_name())
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(chart)
	_body.add_child(SkUi.label(Loc.t("hist.%s.note" % id), 0, true))


## What a screen reader is told when a page opens: the same facts as the chart, in words.
func describe() -> String:
	if page == 0:
		return Loc.t("hist.title") + ". " + Loc.t("hist.intro")
	var study: Dictionary = data.studies[page - 1]
	var id: String = str(study["id"])
	var parts: PackedStringArray = PackedStringArray([Loc.t("hist.%s.title" % id) + ".", Loc.t("hist.record_tag")])
	for row: Dictionary in study["rows"]:
		parts.append(Chart.row_text(id, row, study))
	return " ".join(parts)


# === PRIVATE METHODS ===
func _turn(direction: int) -> void:
	page = clampi(page + direction, 0, page_count() - 1)
	refresh_text()
	SkHost.announce(describe())


## Horizontal bars for one study: "label: 6 of 11" with a bar of that share, or a rate per 1,000.
class Chart extends Control:
	var study: Dictionary = {}
	var palette: Dictionary = SkTheme.DARK

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_fit()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_fit()

	## A row's sentence wraps onto a second or third line in a narrow panel, so nothing is cut off.
	func _text_lines() -> int:
		var font: Font = get_theme_default_font()
		var fs: int = maxi(get_theme_default_font_size() - 2, 12)
		var widest: float = 0.0
		for row: Dictionary in study.get("rows", []):
			widest = maxf(widest, font.get_string_size(row_text(str(study["id"]), row, study), HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x)
		return clampi(ceili(widest * 1.1 / maxf(size.x - 4.0, 120.0)), 1, 4)

	func _row_height() -> float:
		var fs: int = maxi(get_theme_default_font_size() - 2, 12)
		return float(_text_lines()) * (float(fs) + 5.0) + 30.0

	func _fit() -> void:
		var wanted: Vector2 = Vector2(240.0, float((study.get("rows", []) as Array).size()) * _row_height() + 6.0)
		if not custom_minimum_size.is_equal_approx(wanted):
			custom_minimum_size = wanted
		queue_redraw()

	static func row_text(id: String, row: Dictionary, p_study: Dictionary) -> String:
		var label: String = Loc.t("hist.%s.row.%s" % [id, str(row["key"])])
		if row.has("rate") and row.has("persons"):
			return Loc.t("hist.rate_count_row", {"label": label, "rate": "%.1f" % float(row["rate"]), "per": int(p_study.get("per", 1000)),
					"cases": int(row["cases"]), "persons": int(row["persons"])})
		if row.has("rate"):
			return Loc.t("hist.rate_row", {"label": label, "rate": "%.1f" % float(row["rate"]), "per": int(p_study.get("per", 1000))})
		return Loc.t("hist.count_row", {"label": label, "count": int(row["count"]), "total": int(row["total"])})

	func _draw() -> void:
		var font: Font = get_theme_default_font()
		var fs: int = maxi(get_theme_default_font_size() - 2, 12)
		var rows: Array = study.get("rows", [])
		var lines: int = _text_lines()
		var row_h: float = _row_height()
		var text_h: float = float(lines) * (float(fs) + 5.0)
		var top_rate: float = 1.0
		for row: Dictionary in rows:
			if row.has("rate"):
				top_rate = maxf(top_rate, float(row["rate"]))
		for i: int in range(rows.size()):
			var row: Dictionary = rows[i]
			var y: float = row_h * float(i)
			draw_multiline_string(font, Vector2(2.0, y + float(fs) + 2.0), row_text(str(study["id"]), row, study), HORIZONTAL_ALIGNMENT_LEFT, size.x - 4.0, fs, lines, palette["text"])
			var share: float = float(row["rate"]) / top_rate if row.has("rate") else float(row["count"]) / maxf(float(row["total"]), 1.0)
			PmDraw.bar(self, Rect2(2.0, y + text_h + 8.0, minf(size.x - 4.0, 520.0), 14.0), share, palette["accent"], palette["text"], palette["bg"])
