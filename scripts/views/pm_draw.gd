class_name PmDraw
extends RefCounted
## Shared drawing helpers for the code-drawn views: molecule icons, arrows, centred text.
## Every molecule has its own shape and a text label; colour is never the only difference.

# === CONSTANTS ===
const NAD: Color = Color(0.0, 0.52, 0.42)
const NAD_EDGE: Color = Color(0.75, 1.0, 0.93)
const ELECTRON: Color = Color(0.99, 0.91, 0.30)
const ATP: Color = Color(0.93, 0.62, 0.05)
const GLUCOSE: Color = Color(0.36, 0.72, 0.93)
const PYRUVATE: Color = Color(0.82, 0.50, 0.68)
const GAS: Color = Color(0.86, 0.90, 0.94)
const DARK: Color = Color(0.05, 0.07, 0.10)
const NIACIN: Color = Color(0.95, 0.90, 0.35)


# === PUBLIC METHODS ===
static func text(ci: CanvasItem, font: Font, center: Vector2, s: String, size: int, color: Color, max_width: float = -1.0) -> void:
	var w: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	if max_width > 0.0 and w > max_width:
		# Too long for one line (longer translations): wrap inside the width instead of clipping.
		var lines: float = ceilf(w / max_width)
		ci.draw_multiline_string(font, Vector2(center.x - max_width * 0.5, center.y - (lines - 1.0) * float(size) * 0.6 + float(size) * 0.35),
				s, HORIZONTAL_ALIGNMENT_CENTER, max_width, size, 3, color)
		return
	ci.draw_string(font, Vector2(center.x - w * 0.5, center.y + float(size) * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


static func text_left(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, color: Color, max_width: float = -1.0) -> void:
	ci.draw_string(font, pos + Vector2(0.0, float(size) * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, max_width, size, color)


static func rounded(ci: CanvasItem, rect: Rect2, fill: Color, edge: Color, radius: float, width: float = 2.0) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(int(width))
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)


static func arrow(ci: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float = 2.0, head: float = 9.0) -> void:
	var dir: Vector2 = to - from
	if dir.length() < 1.0:
		return
	dir = dir.normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	ci.draw_line(from, to - dir * head * 0.8, color, width, true)
	ci.draw_colored_polygon(PackedVector2Array([to, to - dir * head + side * head * 0.5, to - dir * head - side * head * 0.5]), color)


static func path_arrow(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float = 1.5) -> void:
	for i: int in range(points.size() - 2):
		ci.draw_line(points[i], points[i + 1], color, width, true)
	if points.size() >= 2:
		arrow(ci, points[points.size() - 2], points[points.size() - 1], color, width, 8.0)


## NAD carrier: the same capsule for both forms. NAD+ has an empty ring; NADH carries two electron dots.
static func nad(ci: CanvasItem, font: Font, c: Vector2, k: float, reduced: bool, alpha: float = 1.0) -> void:
	var size: Vector2 = Vector2(54.0, 22.0) * k
	var fill: Color = NAD if not reduced else NAD.lightened(0.18)
	fill.a = alpha
	var edge: Color = NAD_EDGE
	edge.a = alpha
	rounded(ci, Rect2(c - size * 0.5, size), fill, edge, size.y * 0.5, 2.0 if not reduced else 3.0)
	var mark: Vector2 = c + Vector2(-size.x * 0.5 + size.y * 0.5, 0.0)
	var dot: Color = ELECTRON
	dot.a = alpha
	if reduced:
		ci.draw_circle(mark + Vector2(0.0, -size.y * 0.18), size.y * 0.15, dot)
		ci.draw_circle(mark + Vector2(0.0, size.y * 0.18), size.y * 0.15, dot)
	else:
		ci.draw_arc(mark, size.y * 0.22, 0.0, TAU, 12, edge, 1.5, true)
	var label: String = "NADH" if reduced else "NAD⁺"
	var fs: int = maxi(int(12.0 * k), 9)
	var white: Color = Color(1, 1, 1, alpha)
	text(ci, font, c + Vector2(size.y * 0.3, 0.0), label, fs, white)


## ATP: a tag with three phosphate dots; ADP: the same tag with two.
static func atp(ci: CanvasItem, font: Font, c: Vector2, k: float, full: bool) -> void:
	var size: Vector2 = Vector2(40.0, 20.0) * k
	var fill: Color = ATP if full else Color(0.25, 0.20, 0.12)
	rounded(ci, Rect2(c - size * 0.5, size), fill, ATP.lightened(0.4), 4.0, 2.0)
	text(ci, font, c + Vector2(0.0, -1.0), "ATP" if full else "ADP", maxi(int(11.0 * k), 9), DARK if full else Color(1, 0.9, 0.7))
	var n: int = 3 if full else 2
	for i: int in range(n):
		ci.draw_circle(c + Vector2((float(i) - float(n - 1) * 0.5) * 7.0 * k, size.y * 0.5 + 3.0 * k), 2.6 * k, ATP.lightened(0.3))


static func glucose(ci: CanvasItem, c: Vector2, k: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		pts.append(c + Vector2.from_angle(TAU * float(i) / 6.0) * 11.0 * k)
	ci.draw_colored_polygon(pts, GLUCOSE)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(1, 1, 1), 1.5, true)


## Pyruvate: three linked carbons in a bent row.
static func pyruvate(ci: CanvasItem, c: Vector2, k: float) -> void:
	var a: Vector2 = c + Vector2(-7.0, 3.0) * k
	var b: Vector2 = c + Vector2(0.0, -3.0) * k
	var d: Vector2 = c + Vector2(7.0, 3.0) * k
	ci.draw_polyline(PackedVector2Array([a, b, d]), Color(1, 1, 1), 1.5, true)
	for p: Vector2 in [a, b, d]:
		ci.draw_rect(Rect2(p - Vector2(3.2, 3.2) * k, Vector2(6.4, 6.4) * k), PYRUVATE)


## O2: two circles. CO2: three in a line with a darker middle.
static func oxygen(ci: CanvasItem, c: Vector2, k: float) -> void:
	for dx: float in [-4.5, 4.5]:
		ci.draw_circle(c + Vector2(dx * k, 0.0), 5.0 * k, GAS)
		ci.draw_arc(c + Vector2(dx * k, 0.0), 5.0 * k, 0.0, TAU, 12, DARK, 1.0, true)


static func co2(ci: CanvasItem, c: Vector2, k: float) -> void:
	for i: int in range(3):
		var p: Vector2 = c + Vector2(float(i - 1) * 8.0 * k, 0.0)
		ci.draw_circle(p, 4.5 * k, GAS if i != 1 else Color(0.45, 0.48, 0.52))
		ci.draw_arc(p, 4.5 * k, 0.0, TAU, 12, Color(1, 1, 1), 1.0, true)


## H+: a small circle with a plus sign.
static func proton(ci: CanvasItem, c: Vector2, k: float) -> void:
	var r: float = 5.5 * k
	ci.draw_circle(c, r, Color(0.98, 0.45, 0.35))
	ci.draw_line(c + Vector2(-r * 0.55, 0.0), c + Vector2(r * 0.55, 0.0), Color(1, 1, 1), 1.6)
	ci.draw_line(c + Vector2(0.0, -r * 0.55), c + Vector2(0.0, r * 0.55), Color(1, 1, 1), 1.6)


static func electron_pair(ci: CanvasItem, c: Vector2, k: float) -> void:
	ci.draw_circle(c + Vector2(-3.0 * k, 0.0), 2.6 * k, ELECTRON)
	ci.draw_circle(c + Vector2(3.0 * k, 0.0), 2.6 * k, ELECTRON)


## Niacin (vitamin B3): a square badge, separate from the NAD capsule.
static func niacin(ci: CanvasItem, font: Font, c: Vector2, k: float) -> void:
	var s: float = 24.0 * k
	ci.draw_rect(Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), NIACIN)
	ci.draw_rect(Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), DARK, false, 1.5)
	text(ci, font, c, "B3", maxi(int(12.0 * k), 9), DARK)


## A horizontal bar with a border and a percent filled; the number is drawn by the caller.
static func bar(ci: CanvasItem, rect: Rect2, fraction: float, fill: Color, edge: Color, back: Color) -> void:
	ci.draw_rect(rect, back)
	ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0.0, 1.0), rect.size.y)), fill)
	ci.draw_rect(rect, edge, false, 1.5)
