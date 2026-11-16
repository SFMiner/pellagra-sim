class_name DecompView
extends Control
## Two stored food samples side by side under the same conditions. For each: a picture of the sample,
## a bar showing where its matter is now (nothing disappears), the water available to microbes, how
## active the microbes are, and a separate fat-rancidity bar (a chemical change, not microbes).
## Each pool has its own pattern and a text row with numbers, so colour is not needed to read it.

# === CONSTANTS ===
const POOLS: PackedStringArray = ["food", "microbes", "co2", "other", "residue"]
const POOL_COLORS: Array[Color] = [Color(0.93, 0.80, 0.42), Color(0.45, 0.70, 0.45), Color(0.70, 0.76, 0.84),
		Color(0.55, 0.62, 0.86), Color(0.50, 0.38, 0.28)]
const SAMPLE_COLORS: Dictionary = {
	"whole_meal": Color(0.90, 0.74, 0.36), "degermed_meal": Color(0.96, 0.88, 0.58), "masa_flour": Color(0.94, 0.86, 0.66),
	"fortified_meal": Color(0.96, 0.88, 0.58), "fruit_veg": Color(0.80, 0.36, 0.26), "burger_fries": Color(0.62, 0.42, 0.24),
}

# === PUBLIC VARIABLES ===
var controller: SimController = null
var a11y: SkA11y = null


# === LIFECYCLE METHODS ===
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(300.0, 300.0)


# === PUBLIC METHODS ===
func setup(p_controller: SimController, p_a11y: SkA11y) -> void:
	controller = p_controller
	a11y = p_a11y
	controller.decomp_updated.connect(queue_redraw)
	a11y.changed.connect(queue_redraw)


func describe() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i: int in range(2):
		var s: DecompositionModel = controller.samples[i]
		parts.append(Loc.t("decomp.describe", {"name": Loc.t("sample." + controller.sample_id(i)), "day": roundi(s.day),
				"food": roundi(s.food / s.total() * 100.0), "microbes": roundi(s.microbes / s.total() * 100.0),
				"co2": roundi(s.co2 / s.total() * 100.0)}))
	return " ".join(parts)


# === PRIVATE METHODS ===
static func _pool(s: DecompositionModel, index: int) -> float:
	match index:
		0:
			return s.food
		1:
			return s.microbes
		2:
			return s.co2
		3:
			return s.other
	return s.residue


func _draw() -> void:
	if controller == null:
		return
	var pal: Dictionary = SkTheme.palette(a11y.palette_name() if a11y != null else "dark")
	var font: Font = get_theme_default_font()
	var fs: int = maxi(get_theme_default_font_size() - 3, 12)
	draw_rect(Rect2(Vector2.ZERO, size), pal["panel"])
	draw_rect(Rect2(Vector2.ZERO, size), pal["panel_edge"], false, 1.0)
	var line: float = float(fs) + 5.0
	var legend_h: float = line * 6.0 + 6.0
	var col_w: float = (size.x - 24.0) * 0.5
	for i: int in range(2):
		var s: DecompositionModel = controller.samples[i]
		var x: float = 8.0 + float(i) * (col_w + 8.0)
		var y: float = 6.0
		var id: String = controller.sample_id(i)
		draw_string(font, Vector2(x, y + float(fs)), "%s: %s" % ["A" if i == 0 else "B", Loc.t("param.sample_a." + id)],
				HORIZONTAL_ALIGNMENT_LEFT, col_w, fs + 1, pal["text"])
		y += line + 4.0
		var pic_h: float = maxf(size.y - legend_h - line * 5.0 - 44.0, 40.0)
		_draw_sample(Rect2(x, y, col_w, pic_h), s, SAMPLE_COLORS.get(id, Color(0.8, 0.7, 0.4)))
		y += pic_h + 6.0
		# Where the matter is now
		var bar: Rect2 = Rect2(x, y, col_w, 22.0)
		var bx: float = bar.position.x
		for p: int in range(POOLS.size()):
			var w: float = bar.size.x * _pool(s, p) / maxf(s.total(), 1e-9)
			if w > 0.5:
				var seg: Rect2 = Rect2(bx, bar.position.y, w, bar.size.y)
				draw_rect(seg, POOL_COLORS[p])
				_pattern(seg, p)
			bx += w
		draw_rect(bar, pal["text"], false, 1.5)
		y += 28.0
		draw_string(font, Vector2(x, y + float(fs)), Loc.t("decomp.water", {"aw": "%.2f" % s.water}), HORIZONTAL_ALIGNMENT_LEFT, col_w, fs, pal["text"])
		y += line
		draw_string(font, Vector2(x, y + float(fs)), Loc.t("decomp.activity", {"pct": roundi(s.activity * 100.0)}), HORIZONTAL_ALIGNMENT_LEFT, col_w, fs, pal["text"])
		y += line
		draw_string(font, Vector2(x, y + float(fs)), Loc.t("decomp.rancidity", {"pct": roundi(s.rancidity * 100.0)}), HORIZONTAL_ALIGNMENT_LEFT, col_w, fs, pal["text"])
		y += line + 2.0
		PmDraw.bar(self, Rect2(x, y, col_w, 8.0), s.rancidity, pal["warn"], pal["panel_edge"], pal["bg"])
	# Legend with numbers: pool, A %, B %
	var ly: float = size.y - legend_h
	draw_string(font, Vector2(8.0, ly + float(fs)), Loc.t("decomp.legend_title"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, fs, pal["text_dim"])
	ly += line
	for p: int in range(POOLS.size()):
		var sw: Rect2 = Rect2(8.0, ly + 2.0, 22.0, line - 5.0)
		draw_rect(sw, POOL_COLORS[p])
		_pattern(sw, p)
		draw_rect(sw, pal["text"], false, 1.0)
		var a: DecompositionModel = controller.samples[0]
		var b: DecompositionModel = controller.samples[1]
		draw_string(font, Vector2(38.0, ly + float(fs)), "%s   A %d%%   B %d%%" % [Loc.t("decomp.pool." + POOLS[p]),
				roundi(_pool(a, p) / a.total() * 100.0), roundi(_pool(b, p) / b.total() * 100.0)],
				HORIZONTAL_ALIGNMENT_LEFT, size.x - 46.0, fs, pal["text"])
		ly += line


## A heap of the food. It gets lower as solid matter leaves; specks are microbial colonies.
func _draw_sample(area: Rect2, s: DecompositionModel, color: Color) -> void:
	var solids: float = clampf((s.food + s.residue + s.microbes) / maxf(s.total(), 1e-9), 0.0, 1.0)
	var base_y: float = area.end.y - 4.0
	var top: float = area.size.y * (0.25 + 0.6 * solids)
	var mid: float = area.get_center().x
	var half: float = area.size.x * 0.42
	var heap: PackedVector2Array = PackedVector2Array()
	for i: int in range(21):
		var u: float = float(i) / 20.0
		heap.append(Vector2(mid - half + u * half * 2.0, base_y - sin(u * PI) * top))
	# The transformed share darkens the heap.
	var aged: float = clampf(1.0 - s.food / maxf(s.food + s.residue + s.microbes, 1e-9), 0.0, 1.0)
	draw_colored_polygon(heap, color.lerp(POOL_COLORS[4], aged * 0.8))
	heap.append(heap[0])
	draw_polyline(heap, PmDraw.DARK, 1.5, true)
	draw_line(Vector2(area.position.x, base_y), Vector2(area.end.x, base_y), Color(0.7, 0.7, 0.7), 2.0)
	var colonies: int = mini(roundi(s.microbes / maxf(s.total(), 1e-9) * 260.0), 60)
	for i: int in range(colonies):
		var fx: float = fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
		var fy: float = fposmod(sin(float(i) * 78.233) * 24634.6345, 1.0)
		var px: float = mid - half * 0.85 + fx * half * 1.7
		var u2: float = (px - (mid - half)) / (half * 2.0)
		var py: float = base_y - fy * sin(u2 * PI) * top * 0.9 - 2.0
		draw_circle(Vector2(px, py), 3.0, POOL_COLORS[1])
		draw_arc(Vector2(px, py), 3.0, 0.0, TAU, 8, Color(1, 1, 1), 1.0)


func _pattern(r: Rect2, pool: int) -> void:
	var ink: Color = Color(0.05, 0.07, 0.1, 0.8)
	match pool:
		1:
			var x: float = r.position.x + 4.0
			while x < r.end.x - 1.0:
				draw_circle(Vector2(x, r.get_center().y), 1.6, ink)
				x += 7.0
		2:
			var x2: float = r.position.x + 2.0
			while x2 < r.end.x - 1.0:
				draw_line(Vector2(x2, r.end.y - 1.0), Vector2(minf(x2 + r.size.y * 0.6, r.end.x), r.position.y + 1.0), ink, 1.0)
				x2 += 7.0
		3:
			var x3: float = r.position.x + 3.0
			while x3 < r.end.x - 1.0:
				draw_line(Vector2(x3, r.position.y + 1.0), Vector2(x3, r.end.y - 1.0), ink, 1.0)
				x3 += 6.0
		4:
			draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(1, 1, 1, 0.8), 1.5)
