class_name PopulationView
extends HBoxContainer
## The community scale of the same state: people grouped in households, a line graph of the modeled share
## who are strained or at risk, and conceptual tissue indicators for the person shown in the cell view.
## A person's state is shown by the SHAPE of the symbol (filled, half filled with a bar, outline with a
## slash), never by skin tone or by colour alone. Everything here is model output, labelled as such.

# === PUBLIC VARIABLES ===
var controller: SimController = null
var a11y: SkA11y = null
var graph: SkLineGraph = SkLineGraph.new()
var field: PeopleField = PeopleField.new()
var organs: OrganBars = OrganBars.new()

# === PRIVATE VARIABLES ===
var _plotted: int = 0


# === PUBLIC METHODS ===
func setup(p_controller: SimController, p_a11y: SkA11y) -> void:
	controller = p_controller
	a11y = p_a11y
	add_theme_constant_override("separation", 8)
	field.view = self
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field.size_flags_stretch_ratio = 1.25
	add_child(field)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	add_child(right)
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size = Vector2(200.0, 120.0)
	graph.auto_y = false
	graph.y_range = Vector2(0.0, 100.0)
	graph.y_format = "%.0f%%"
	right.add_child(graph)
	organs.view = self
	organs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(organs)
	controller.history_changed.connect(rebuild_graph)
	a11y.changed.connect(refresh)
	rebuild_graph()


## Language changed or a full redraw is needed.
func refresh_text() -> void:
	rebuild_graph()
	refresh()


func refresh() -> void:
	if controller == null or not is_visible_in_tree():
		return
	_append_new_points()
	field.queue_redraw()
	organs.queue_redraw()


func rebuild_graph() -> void:
	if controller == null:
		return
	graph.clear()
	graph.title = Loc.t("pop.graph_title")
	graph.x_label = Loc.t("pop.graph_x")
	_plotted = 0
	graph.set_series("now", Loc.t("graph.now"), PackedVector2Array())
	for slot: String in SimController.SNAPSHOT_SLOTS:
		if controller.snapshots.has(slot):
			var snap: Dictionary = controller.snapshots[slot]
			var pts: PackedVector2Array = PackedVector2Array()
			var d: PackedFloat64Array = snap["days"]
			var r: PackedFloat64Array = snap["risk"]
			for i: int in range(d.size()):
				pts.append(Vector2(d[i] / 30.4, r[i]))
			graph.set_series("kept_" + slot, Loc.t("snapshot.short." + slot), pts, true)
	_append_new_points()


func describe() -> String:
	var c: PackedInt32Array = controller.population.counts()
	return Loc.t("pop.describe", {"cohort": Loc.t("cohort." + str(controller.cohort()["id"])), "months": "%.1f" % (controller.days / 30.4),
			"ok": c[0], "strained": c[1], "risk": c[2], "n": controller.population.size})


# === PRIVATE METHODS ===
func _append_new_points() -> void:
	var d: PackedFloat64Array = controller.hist_days
	var r: PackedFloat64Array = controller.hist_risk
	while _plotted < d.size():
		graph.append_point("now", Loc.t("graph.now"), d[_plotted] / 30.4, r[_plotted])
		_plotted += 1
	graph.x_range = Vector2(0.0, maxf(12.0, ceilf(controller.days / 30.4)))
	var kept_max: float = 0.0
	for slot: String in controller.snapshots:
		var kd: PackedFloat64Array = controller.snapshots[slot]["days"]
		if not kd.is_empty():
			kept_max = maxf(kept_max, kd[kd.size() - 1] / 30.4)
	graph.x_range.y = maxf(graph.x_range.y, ceilf(kept_max))


func _palette() -> Dictionary:
	return SkTheme.palette(a11y.palette_name() if a11y != null else "dark")


## People in households. One symbol = one modeled person.
class PeopleField extends Control:
	var view: PopulationView = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		custom_minimum_size = Vector2(220.0, 160.0)

	func _draw() -> void:
		if view == null or view.controller == null:
			return
		var pal: Dictionary = view._palette()
		var pop: PopulationModel = view.controller.population
		var font: Font = get_theme_default_font()
		var fs: int = maxi(get_theme_default_font_size() - 3, 12)
		var line: float = float(fs) + 5.0
		draw_rect(Rect2(Vector2.ZERO, size), pal["panel"])
		draw_rect(Rect2(Vector2.ZERO, size), pal["panel_edge"], false, 1.0)
		var cohort_id: String = str(view.controller.cohort()["id"])
		draw_string(font, Vector2(8.0, line), Loc.t("pop.community", {"name": Loc.t("cohort." + cohort_id)}), HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, fs + 1, pal["text"])
		draw_string(font, Vector2(8.0, line * 2.0), Loc.t("pop.time", {"months": "%.1f" % (view.controller.days / 30.4)}) + "  " + Loc.t("pop.model_note"),
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, fs, pal["text_dim"])
		# Legend with counts: the symbol shapes carry the meaning
		var counts: PackedInt32Array = pop.counts()
		var keys: PackedStringArray = ["pop.meeting", "pop.strained", "pop.risk"]
		var lx: float = 8.0
		var ly: float = line * 2.0 + 8.0
		for s: int in range(3):
			var label: String = "%s: %d" % [Loc.t(keys[s]), counts[s]]
			var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x + 30.0
			if lx + w > size.x - 6.0 and lx > 8.0:
				lx = 8.0
				ly += line + 6.0
			_person(Vector2(lx + 8.0, ly + line * 0.55), 7.0, line + 2.0, s, pal)
			draw_string(font, Vector2(lx + 20.0, ly + line * 0.55 + float(fs) * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, pal["text"])
			lx += w + 10.0
		var top: float = ly + line + 12.0
		# Grid of households
		var per_house: int = maxi(pop.household, 1)
		var houses: int = int(ceil(float(pop.size) / float(per_house)))
		var per_row: int = clampi(int(floor((size.x - 16.0) / (float(per_house) * 13.0 + 14.0))), 1, houses)
		var rows: int = int(ceil(float(houses) / float(per_row)))
		var cell_w: float = (size.x - 16.0) / float(per_row)
		var cell_h: float = clampf((size.y - top - 6.0) / float(maxi(rows, 1)), 14.0, 64.0)
		var person_w: float = minf((cell_w - 12.0) / float(per_house), 18.0)
		for h: int in range(houses):
			var origin: Vector2 = Vector2(8.0 + float(h % per_row) * cell_w, top + float(h / per_row) * cell_h)
			draw_rect(Rect2(origin, Vector2(person_w * float(per_house) + 6.0, cell_h - 5.0)), Color(pal["panel_edge"].r, pal["panel_edge"].g, pal["panel_edge"].b, 0.5), false, 1.0)
			for k: int in range(per_house):
				var i: int = h * per_house + k
				if i >= pop.size:
					break
				_person(origin + Vector2(3.0 + person_w * (float(k) + 0.5), (cell_h - 5.0) * 0.5), person_w * 0.38, cell_h - 12.0, int(pop.status(i)), pal)

	## state 0 meeting needs: filled.  1 strained: outline, lower half filled, bar above.  2 risk: outline with a slash.
	func _person(c: Vector2, r: float, h: float, state: int, pal: Dictionary) -> void:
		var ink: Color = pal["text"]
		var body_h: float = maxf(h * 0.5, r * 1.6)
		var head: Vector2 = c + Vector2(0.0, -body_h * 0.5 - r * 0.4)
		var body: Rect2 = Rect2(c.x - r, c.y - body_h * 0.35, r * 2.0, body_h * 0.85)
		match state:
			0:
				draw_circle(head, r * 0.8, ink)
				draw_rect(body, ink)
			1:
				draw_arc(head, r * 0.8, 0.0, TAU, 12, pal["warn"], 1.5, true)
				draw_rect(body, pal["warn"], false, 1.5)
				draw_rect(Rect2(body.position.x, body.get_center().y, body.size.x, body.size.y * 0.5), pal["warn"])
			2:
				draw_arc(head, r * 0.8, 0.0, TAU, 12, ink, 1.5, true)
				draw_rect(body, ink, false, 1.5)
				draw_line(body.position + Vector2(-2.0, body.size.y + 2.0), body.position + Vector2(body.size.x + 2.0, -2.0), pal["warn"], 2.5)


## Conceptual tissue indicators for the cell view's person. Bars with numbers; not a diagnosis.
class OrganBars extends Control:
	const IDS: PackedStringArray = ["muscle", "nerve", "gut", "skin"]
	var view: PopulationView = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(200.0, 140.0)

	func _draw() -> void:
		if view == null or view.controller == null:
			return
		var pal: Dictionary = view._palette()
		var font: Font = get_theme_default_font()
		var fs: int = maxi(get_theme_default_font_size() - 3, 12)
		var head: float = float(fs) + 8.0
		var line: float = (size.y - head - 4.0) / 4.0
		draw_rect(Rect2(Vector2.ZERO, size), pal["panel"])
		draw_rect(Rect2(Vector2.ZERO, size), pal["panel_edge"], false, 1.0)
		draw_string(font, Vector2(8.0, float(fs) + 4.0), Loc.t("organ.title"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, fs, pal["text_dim"])
		# Each row: the words and the number on one line, the bar under them (so long translations fit).
		for i: int in range(IDS.size()):
			var f: float = view.controller.organ_function(IDS[i])
			var y: float = head + line * float(i)
			draw_string(font, Vector2(8.0, y + float(fs)), "%s: %d%%" % [Loc.t("organ." + IDS[i]), roundi(f * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, fs, pal["text"])
			PmDraw.bar(self, Rect2(8.0, y + float(fs) + 5.0, size.x - 16.0, 6.0), f, pal["ok"] if f > 0.9 else pal["warn"], pal["panel_edge"], pal["bg"])
