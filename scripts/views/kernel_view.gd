class_name KernelView
extends Control
## Cross-section of a corn kernel that shows what each processing step does:
##   degerming      - the germ and the bran leave the kernel (with the niacin they hold);
##   nixtamalizing  - cooking in alkaline limewater frees bound niacin; none is created;
##   fortifying     - niacin is added after milling.
## Dots are niacin: a filled dot can be absorbed, a ring with a bar is bound, a square is added.
## The numbers of dots come from the food profile data, so the picture and the model agree.
## The change plays as a short animation when the food or processing changes (a still final frame with
## reduced motion). It reads the controller and never changes it.

# === CONSTANTS ===
const DOTS: int = 14
const DURATION: float = 3.0
const OUTLINE: Array[Vector2] = [
	Vector2(0.18, 0.12), Vector2(0.35, 0.03), Vector2(0.65, 0.03), Vector2(0.82, 0.12), Vector2(0.93, 0.32),
	Vector2(0.92, 0.55), Vector2(0.80, 0.78), Vector2(0.62, 0.93), Vector2(0.50, 0.98), Vector2(0.38, 0.93),
	Vector2(0.20, 0.78), Vector2(0.08, 0.55), Vector2(0.07, 0.32),
]
## Where each niacin dot sits: 0-4 endosperm, 5-8 germ, 9-13 bran.
const DOT_HOME: Array[Vector2] = [
	Vector2(0.30, 0.25), Vector2(0.50, 0.20), Vector2(0.70, 0.27), Vector2(0.27, 0.45), Vector2(0.73, 0.45),
	Vector2(0.45, 0.60), Vector2(0.55, 0.63), Vector2(0.46, 0.76), Vector2(0.54, 0.80),
	Vector2(0.26, 0.085), Vector2(0.74, 0.085), Vector2(0.105, 0.45), Vector2(0.895, 0.45), Vector2(0.29, 0.855),
]
const BRAN: Color = Color(0.66, 0.45, 0.20)
const ENDOSPERM: Color = Color(0.97, 0.86, 0.48)
const GERM: Color = Color(0.92, 0.52, 0.16)
const DOT: Color = Color(0.10, 0.20, 0.62)
const ADDED: Color = Color(0.62, 0.10, 0.45)

# === PUBLIC VARIABLES ===
var controller: SimController = null
var a11y: SkA11y = null
## Small version for the control panel: no part labels.
var compact: bool = false

# === PRIVATE VARIABLES ===
var _from: String = ""
var _to: String = ""
var _t: float = 1.0


# === LIFECYCLE METHODS ===
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	if _t < 1.0 and is_visible_in_tree():
		_t = minf(_t + delta / DURATION, 1.0)
		queue_redraw()


# === PUBLIC METHODS ===
func setup(p_controller: SimController, p_a11y: SkA11y) -> void:
	controller = p_controller
	a11y = p_a11y
	_to = controller.profile_id()
	_from = _to
	controller.diet_changed.connect(_on_diet_changed)
	controller.updated.connect(queue_redraw)
	a11y.changed.connect(queue_redraw)


## Plays the processing step again, starting from the whole kernel.
func replay() -> void:
	_from = "whole_untreated"
	_start()


## Jumps to the finished picture for the current food (used at start-up, so nothing moves before input).
func settle() -> void:
	_to = controller.profile_id()
	_from = _to
	_t = 1.0
	queue_redraw()


func is_playing() -> bool:
	return _t < 1.0


func shown_profile() -> String:
	return _to


# === PRIVATE METHODS ===
func _on_diet_changed(_food_changed: bool) -> void:
	var now: String = controller.profile_id()
	if now == _to:
		return
	# Degermed cornmeal always starts from the whole kernel, so the germ is seen leaving.
	_from = _to if (_to == "degermed_unfortified" and now == "degermed_fortified") else "whole_untreated"
	_to = now
	_start()


func _start() -> void:
	_t = 1.0 if (a11y != null and a11y.reduced_motion()) else 0.0
	queue_redraw()


static func _window(t: float, a: float, b: float) -> float:
	return smoothstep(a, b, t)


## Final picture values for a profile.
func _pose(id: String) -> Dictionary:
	var p: Dictionary = controller.data.profile(id)
	var b: Dictionary = NutritionModel.breakdown(p)
	return {
		"germ_out": 0.0 if bool(p.get("germ", true)) else 1.0,
		"bran_out": 1.0 if id.begins_with("degermed") else (0.6 if id == "whole_nixtamalized" else 0.0),
		"total": roundi(float(b["content"]) * float(DOTS) / 0.9) if not id.begins_with("degermed") else 5,
		"free": roundi(float(b["absorbed"]) * float(DOTS) / 0.9),
		"added": roundi(float(b["fortification"]) * 12.0 / 0.9),
	}


func _draw() -> void:
	if controller == null:
		return
	var pal: Dictionary = SkTheme.palette(a11y.palette_name() if a11y != null else "dark")
	var font: Font = get_theme_default_font()
	var fs: int = maxi(get_theme_default_font_size() - 3, 12)
	draw_rect(Rect2(Vector2.ZERO, size), pal["panel"])
	draw_rect(Rect2(Vector2.ZERO, size), pal["panel_edge"], false, 1.0)
	var pad: float = 8.0
	var kh: float = size.y - pad * 2.0 - (0.0 if compact else float(fs) + 6.0)
	var kw: float = minf(kh * 0.82, size.x * 0.24)
	var box: Rect2 = Rect2(pad + (6.0 if compact else size.x * 0.03), pad, kw, kh)
	var pile: Vector2 = Vector2(box.end.x + kw * 0.75, box.position.y + kh * 0.55)
	if _to == "diverse":
		_draw_mixed(box, font, fs, pal)
	else:
		_draw_kernel(box, pile, font, fs, pal)
	_draw_numbers(Rect2(pile.x + kw * 0.75, pad, size.x - (pile.x + kw * 0.75) - pad, size.y - pad * 2.0), font, fs, pal)


func _unit(box: Rect2, v: Vector2) -> Vector2:
	return box.position + Vector2(v.x * box.size.x, v.y * box.size.y)


func _draw_kernel(box: Rect2, pile: Vector2, font: Font, fs: int, pal: Dictionary) -> void:
	var a: Dictionary = _pose(_from)
	var b: Dictionary = _pose(_to)
	var germ_out: float = lerpf(float(a["germ_out"]), float(b["germ_out"]), _window(_t, 0.08, 0.55))
	var bran_out: float = lerpf(float(a["bran_out"]), float(b["bran_out"]), _window(_t, 0.3, 0.8))
	var free: float = lerpf(float(a["free"]), float(b["free"]), _window(_t, 0.3, 0.85))
	var added: float = lerpf(float(a["added"]), float(b["added"]), _window(_t, 0.5, 1.0))
	var lime: float = sin(PI * _t) if (_to == "whole_nixtamalized" and _t < 1.0) else 0.0
	var total_now: int = int(b["total"]) if _t > 0.6 else maxi(int(a["total"]), int(b["total"]))

	# Limewater (alkaline cooking), drawn behind the kernel while nixtamalizing
	if lime > 0.01:
		var level: float = box.end.y - box.size.y * 0.9 * lime
		draw_rect(Rect2(box.position.x - 6.0, level, box.size.x + 12.0, box.end.y - level + 4.0), Color(0.55, 0.75, 0.85, 0.45))
		if not compact:
			PmDraw.text(self, font, Vector2(box.get_center().x, level - 8.0), Loc.t("kernel.limewater"), fs, pal["text"], box.size.x * 1.6)
	# Bran (outer layers), endosperm on top of it so the bran shows as a ring
	var outer: PackedVector2Array = PackedVector2Array()
	var inner: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in OUTLINE:
		outer.append(_unit(box, v))
		inner.append(_unit(box, Vector2(0.5, 0.5) + (v - Vector2(0.5, 0.5)) * 0.88))
	var bran_c: Color = BRAN
	bran_c.a = 1.0 - bran_out
	if bran_c.a > 0.02:
		draw_colored_polygon(outer, bran_c)
	draw_colored_polygon(inner, ENDOSPERM)
	var edge: PackedVector2Array = inner.duplicate()
	edge.append(inner[0])
	draw_polyline(edge, PmDraw.DARK, 1.5, true)
	# Germ: slides out to the "removed" pile when the kernel is degermed
	var slide: Vector2 = (pile - _unit(box, Vector2(0.5, 0.7))) * germ_out
	var germ: PackedVector2Array = PackedVector2Array()
	for i: int in range(20):
		var ang: float = TAU * float(i) / 20.0
		germ.append(_unit(box, Vector2(0.5 + cos(ang) * 0.17, 0.7 + sin(ang) * 0.22)) + slide)
	draw_colored_polygon(germ, GERM)
	germ.append(germ[0])
	draw_polyline(germ, PmDraw.DARK, 1.5, true)
	# Bran flakes in the pile
	if bran_out > 0.02 and _to.begins_with("degermed"):
		for i: int in range(5):
			var at: Vector2 = pile + Vector2(-box.size.x * 0.3 + float(i) * box.size.x * 0.15, -box.size.y * 0.42 + float(i % 2) * 6.0)
			draw_rect(Rect2(at, Vector2(box.size.x * 0.13, 5.0)), Color(BRAN.r, BRAN.g, BRAN.b, bran_out))
	# Niacin dots
	var r: float = clampf(box.size.x * 0.045, 3.0, 7.0)
	for i: int in range(DOTS):
		if i >= total_now:
			continue
		var at: Vector2 = _unit(box, DOT_HOME[i])
		if i >= 5 and i <= 8:
			at += slide
		elif i >= 9 and _to.begins_with("degermed"):
			at = at.lerp(pile + Vector2(-box.size.x * 0.24 + float(i - 9) * box.size.x * 0.13, -box.size.y * 0.33), bran_out)
		_niacin_dot(at, r, float(i) < free - 0.5)
	# Added niacin (fortification): squares dropping into the meal
	for i: int in range(roundi(added)):
		var home: Vector2 = _unit(box, Vector2(0.24 + float(i % 4) * 0.17, 0.33 + float(i / 4) * 0.13))
		draw_rect(Rect2(home - Vector2(r, r), Vector2(r, r) * 2.0), ADDED)
		draw_rect(Rect2(home - Vector2(r, r), Vector2(r, r) * 2.0), Color(1, 1, 1), false, 1.0)
	if compact:
		return
	# Part labels with leader lines
	var label_c: Color = pal["text"]
	if bran_out < 0.5:
		_leader(font, fs, _unit(box, Vector2(0.88, 0.2)), Vector2(box.end.x + 10.0, box.position.y + 6.0), Loc.t("kernel.bran"), label_c)
	_leader(font, fs, _unit(box, Vector2(0.62, 0.36)), Vector2(box.end.x + 10.0, box.position.y + box.size.y * 0.26), Loc.t("kernel.endosperm"), label_c)
	if germ_out < 0.5:
		_leader(font, fs, _unit(box, Vector2(0.62, 0.72)), Vector2(box.end.x + 10.0, box.position.y + box.size.y * 0.78), Loc.t("kernel.germ"), label_c)
	if germ_out > 0.6:
		PmDraw.text(self, font, Vector2(pile.x, box.end.y - 2.0), Loc.t("kernel.removed"), fs, pal["warn"], box.size.x * 1.5)
	var caption: String = Loc.t("kernel.caption." + _to)
	draw_string(font, Vector2(8.0, size.y - 8.0), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, fs, pal["text_dim"])


func _niacin_dot(at: Vector2, r: float, free: bool) -> void:
	if free:
		draw_circle(at, r, DOT)
		draw_arc(at, r, 0.0, TAU, 14, Color(1, 1, 1), 1.2, true)
	else:
		draw_circle(at, r, Color(1, 1, 1))
		draw_arc(at, r, 0.0, TAU, 14, DOT, 2.0, true)
		draw_line(at - Vector2(r, 0.0), at + Vector2(r, 0.0), DOT, 2.0)


func _leader(font: Font, fs: int, from: Vector2, to: Vector2, label: String, color: Color) -> void:
	draw_line(from, to, color, 1.0, true)
	draw_string(font, to + Vector2(4.0, float(fs) * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, color)


## A varied diet: several simple foods, each a source of niacin or tryptophan.
func _draw_mixed(box: Rect2, font: Font, fs: int, pal: Dictionary) -> void:
	var area: Rect2 = Rect2(box.position, Vector2(box.size.x * 2.2, box.size.y))
	var u: float = minf(area.size.x / 5.0, area.size.y / 2.4)
	var c: Vector2 = area.position + Vector2(u * 0.9, area.size.y * 0.3)
	# beans
	for i: int in range(3):
		_ellipse(c + Vector2(float(i) * u * 0.5, float(i % 2) * u * 0.25), Vector2(u * 0.3, u * 0.18), Color(0.55, 0.22, 0.18))
	# leafy greens
	var leaf: Vector2 = area.position + Vector2(u * 3.3, area.size.y * 0.3)
	_ellipse(leaf, Vector2(u * 0.6, u * 0.3), Color(0.20, 0.55, 0.25))
	draw_line(leaf - Vector2(u * 0.6, 0.0), leaf + Vector2(u * 0.6, 0.0), Color(0.8, 1.0, 0.8), 1.5)
	# egg
	var egg: Vector2 = area.position + Vector2(u * 0.9, area.size.y * 0.75)
	_ellipse(egg, Vector2(u * 0.32, u * 0.4), Color(0.97, 0.95, 0.88))
	_ellipse(egg, Vector2(u * 0.14, u * 0.14), Color(0.95, 0.72, 0.15))
	# milk
	var milk: Rect2 = Rect2(area.position + Vector2(u * 2.0, area.size.y * 0.52), Vector2(u * 0.5, u * 0.8))
	draw_rect(milk, Color(0.95, 0.96, 0.98))
	draw_rect(milk, PmDraw.DARK, false, 1.5)
	# corn
	var corn: Vector2 = area.position + Vector2(u * 3.4, area.size.y * 0.76)
	_ellipse(corn, Vector2(u * 0.3, u * 0.38), ENDOSPERM)
	_ellipse(corn + Vector2(0.0, u * 0.1), Vector2(u * 0.12, u * 0.18), GERM)
	var r: float = clampf(u * 0.09, 3.0, 6.0)
	for at: Vector2 in [c + Vector2(u * 0.5, -u * 0.3), leaf + Vector2(0.0, -u * 0.42), egg + Vector2(u * 0.5, 0.0),
			milk.get_center() + Vector2(u * 0.5, 0.0), corn + Vector2(-u * 0.5, 0.0), leaf + Vector2(u * 0.3, u * 0.45)]:
		_niacin_dot(at, r, true)
	if not compact:
		draw_string(font, Vector2(8.0, size.y - 8.0), Loc.t("kernel.caption.diverse"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, fs, pal["text_dim"])


func _ellipse(c: Vector2, radii: Vector2, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(18):
		var ang: float = TAU * float(i) / 18.0
		pts.append(c + Vector2(cos(ang) * radii.x, sin(ang) * radii.y))
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, PmDraw.DARK, 1.2, true)


## The numbers behind the picture: where this food's usable niacin comes from (percent of the reference).
func _draw_numbers(area: Rect2, font: Font, fs: int, pal: Dictionary) -> void:
	if area.size.x < 90.0:
		return
	var b: Dictionary = NutritionModel.breakdown(controller.data.profile(_to))
	var usable: float = NutritionModel.usable_niacin(controller.data.profile(_to))
	var rows: Array = [
		["kernel.row_content", float(b["content"]), pal["text_dim"]],
		["kernel.row_absorbed", float(b["absorbed"]), DOT.lightened(0.45)],
		["kernel.row_tryptophan", float(b["tryptophan"]), pal["accent"]],
		["kernel.row_added", float(b["fortification"]), ADDED.lightened(0.4)],
		["kernel.row_usable", usable, pal["ok"]],
	]
	if compact:
		rows = [rows[0], rows[4]]
	var row_h: float = minf(area.size.y / float(rows.size() + (0 if compact else 2)), float(fs) * 2.7)
	var y: float = area.position.y
	if not compact:
		# Legend
		var r: float = 6.0
		_niacin_dot(Vector2(area.position.x + r, y + row_h * 0.3), r, true)
		draw_string(font, Vector2(area.position.x + 20.0, y + row_h * 0.3 + float(fs) * 0.35), Loc.t("kernel.legend_free"), HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 22.0, fs, pal["text"])
		_niacin_dot(Vector2(area.position.x + r, y + row_h * 0.3 + row_h * 0.62), r, false)
		draw_string(font, Vector2(area.position.x + 20.0, y + row_h * 0.92 + float(fs) * 0.35), Loc.t("kernel.legend_bound"), HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 22.0, fs, pal["text"])
		draw_rect(Rect2(area.position.x, y + row_h * 1.54 - r, r * 2.0, r * 2.0), ADDED)
		draw_rect(Rect2(area.position.x, y + row_h * 1.54 - r, r * 2.0, r * 2.0), Color(1, 1, 1), false, 1.0)
		draw_string(font, Vector2(area.position.x + 20.0, y + row_h * 1.54 + float(fs) * 0.35), Loc.t("kernel.legend_added"), HORIZONTAL_ALIGNMENT_LEFT, area.size.x - 22.0, fs, pal["text"])
		y += row_h * 2.0
	for row: Array in rows:
		draw_string(font, Vector2(area.position.x, y + float(fs)), "%s: %d%%" % [Loc.t(str(row[0])), roundi(float(row[1]) * 100.0)],
				HORIZONTAL_ALIGNMENT_LEFT, area.size.x, fs, pal["text"])
		PmDraw.bar(self, Rect2(area.position.x, y + float(fs) + 5.0, area.size.x, maxf(row_h - float(fs) - 12.0, 5.0)), float(row[1]) / 1.3,
				row[2], pal["panel_edge"], pal["bg"])
		y += row_h
