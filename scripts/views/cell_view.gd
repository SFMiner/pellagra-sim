class_name CellView
extends Control
## The main picture: cytoplasm on the left, one mitochondrion on the right.
## It only READS the controller's metabolism model. Every moving object is released by a model rate
## (events per second = rate x a fixed scale), so motion stops when a rate is zero and nothing moves
## while the clock is paused. With reduced motion (or particles off) it draws a still frame: carriers
## in their slots, counts and rate labels.
## Layout is in design units (1000 x 440) stretched to the control's size; icons and text keep their shape.

# === CONSTANTS ===
const DW: float = 1000.0
const DH: float = 440.0
const MAX_TOKENS: int = 16
const MAX_CYTO: int = 6
const TOKEN_SPEED: float = 320.0
const MAX_MOVERS: int = 150
## Events per second per unit of model rate. One scale per kind of object, so more flux = more objects.
const SCALE: Dictionary = {
	"cyto": 26.0, "matrix": 6.5, "glucose": 22.0, "pyruvate": 22.0, "co2": 22.0, "oxygen": 5.0,
	"electron": 8.0, "h_up": 13.0, "h_down": 13.0, "atp": 4.0,
}
## Rates shown as a percent of these reference rates (a well-fed active cell), for the text labels.
const REFERENCE: Dictionary = {"glycolysis": 0.075, "matrix": 0.062, "etc": 0.31, "synthase": 0.30, "ferment": 0.075}
const SITE_GLY: Vector2 = Vector2(288.0, 108.0)
const SITE_FERMENT: Vector2 = Vector2(288.0, 214.0)
const SITE_SHUTTLE: Vector2 = Vector2(430.0, 180.0)
const SITE_CYCLE: Vector2 = Vector2(722.0, 290.0)
const SITE_COMPLEX1: Vector2 = Vector2(540.0, 122.0)
const SITE_B3: Vector2 = Vector2(372.0, 336.0)
const COMPLEX_X: Array[float] = [560.0, 640.0, 720.0]
const SYNTHASE_X: float = 900.0
const MEMBRANE_Y: float = 86.0
## ATP leaves the synthase, goes round the outside of the matrix and reaches the work site in the cytoplasm.
const PYRUVATE_ROUTE: Array[Vector2] = [Vector2(236.0, 138.0), Vector2(300.0, 290.0), Vector2(452.0, 290.0), Vector2(490.0, 358.0), Vector2(690.0, 358.0), Vector2(742.0, 326.0)]
const ATP_ROUTE: Array[Vector2] = [Vector2(908.0, 140.0), Vector2(952.0, 170.0), Vector2(952.0, 404.0), Vector2(470.0, 404.0), Vector2(336.0, 424.0), Vector2(306.0, 388.0)]

# === PUBLIC VARIABLES ===
var controller: SimController = null
var a11y: SkA11y = null
## Class setting particles=off: never animate, always the still frame.
var particles_enabled: bool = true
## Class setting detail=advanced: fuller station names.
var detailed: bool = false

# === PRIVATE VARIABLES ===
## Each: {"c": 0 cytoplasm / 1 matrix, "nadh": bool, "pos": Vector2, "slot": int, "mode": 0 idle / 1 to a site / 2 home,
##        "target": Vector2, "becomes": bool, "alpha": float, "dying": bool}
var _tokens: Array[Dictionary] = []
## Each: {"kind": String, "path": PackedVector2Array, "d": float, "len": float, "speed": float, "swap": float}
var _movers: Array[Dictionary] = []
var _acc: Dictionary = {}
var _fix_timer: float = 0.0
var _complex_turn: int = 0
var _k: float = 1.0
var _pal: Dictionary = SkTheme.DARK


# === LIFECYCLE METHODS ===
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size = Vector2(300.0, 200.0)


func _notification(what: int) -> void:
	# Coming back from another view: redraw the carriers from the model, not from where they were left.
	if what == NOTIFICATION_VISIBILITY_CHANGED and controller != null and is_visible_in_tree():
		snap()


func _process(delta: float) -> void:
	if controller == null or not is_visible_in_tree():
		return
	if controller.session.is_running() and animating():
		_advance(minf(delta, 0.1))
		queue_redraw()


# === PUBLIC METHODS ===
func setup(p_controller: SimController, p_a11y: SkA11y) -> void:
	controller = p_controller
	a11y = p_a11y
	controller.updated.connect(_on_updated)
	controller.session.reset_done.connect(snap)
	controller.session.advanced.connect(_on_advanced)
	a11y.changed.connect(snap)
	snap()


func animating() -> bool:
	return particles_enabled and not (a11y != null and a11y.reduced_motion())


## Throws away everything in flight and puts the carriers in their slots to match the model exactly.
func snap() -> void:
	_movers.clear()
	_acc.clear()
	_tokens.clear()
	if controller == null:
		return
	var counts: Vector2i = _wanted_counts()
	for c: int in range(2):
		var n: int = counts.x if c == 0 else counts.y
		var reduced: int = roundi(controller.metabolism.nadh_fraction() * float(n))
		for i: int in range(n):
			_tokens.append({"c": c, "nadh": i < reduced, "pos": _slot(c, i), "slot": i, "mode": 0,
					"target": _slot(c, i), "becomes": false, "alpha": 1.0, "dying": false})
	queue_redraw()


## What a screen reader or a test can be told about the picture.
func describe() -> String:
	var m: MetabolismModel = controller.metabolism
	return Loc.t("cell.describe", {"nad": roundi(m.nad_total * 100.0), "nadh": roundi(m.nadh_fraction() * 100.0),
			"atp": roundi(m.atp * 100.0), "work": roundi(m.work_fraction() * 100.0)})


func token_count() -> int:
	return _tokens.size()


func mover_count() -> int:
	return _movers.size()


# === PRIVATE METHODS ===
## The Step button: one model step while paused moves the picture by the same amount of time.
func _on_advanced(_steps: int) -> void:
	if controller.session.state == SkSession.State.PAUSED and animating() and is_visible_in_tree():
		_advance(controller.session.clock.step)
		queue_redraw()


func _on_updated() -> void:
	if not (controller.session.is_running() and animating()):
		# Still frame: keep the carriers equal to the model after every step or setting change.
		if not animating() or controller.session.state != SkSession.State.PAUSED or _tokens.is_empty():
			snap()
		else:
			_match_pool_size()
	queue_redraw()


func _wanted_counts() -> Vector2i:
	var total: int = clampi(roundi(controller.metabolism.nad_total * float(MAX_TOKENS)), 2, MAX_TOKENS)
	var cyto: int = clampi(roundi(float(total) * 0.375), 1, MAX_CYTO)
	return Vector2i(cyto, total - cyto)


func _slot(c: int, i: int) -> Vector2:
	if c == 0:
		return Vector2(326.0 + float(i % 2) * 66.0, 104.0 + float(i / 2) * 34.0)
	return Vector2(502.0 + float(i % 2) * 68.0, 192.0 + float(i / 2) * 34.0)


func _count(c: int, include_dying: bool = false) -> int:
	var n: int = 0
	for t: Dictionary in _tokens:
		if t["c"] == c and (include_dying or not t["dying"]):
			n += 1
	return n


## Adds or retires carriers so their number follows the slowly changing NAD pool. A retired carrier fades:
## the pool shrinks because turnover is not replaced, not because carriers are damaged.
func _match_pool_size() -> void:
	var counts: Vector2i = _wanted_counts()
	for c: int in range(2):
		var want: int = counts.x if c == 0 else counts.y
		var have: int = _count(c)
		if have < want:
			var used: Dictionary = {}
			for t: Dictionary in _tokens:
				if t["c"] == c:
					used[t["slot"]] = true
			var slot: int = 0
			while used.has(slot):
				slot += 1
			_tokens.append({"c": c, "nadh": false, "pos": SITE_B3 if c == 0 else _slot(c, slot), "slot": slot,
					"mode": 2, "target": _slot(c, slot), "becomes": false, "alpha": 0.0, "dying": false})
		elif have > want:
			for i: int in range(_tokens.size() - 1, -1, -1):
				var t: Dictionary = _tokens[i]
				if t["c"] == c and not t["dying"] and t["mode"] == 0:
					t["dying"] = true
					break


func _advance(dt: float) -> void:
	var m: MetabolismModel = controller.metabolism
	_match_pool_size()
	# Carriers: pairs are sent round the cycle at the pathway's rate.
	var ferment_share: float = clampf(m.ferment_flux / maxf(m.glycolysis_flux, 1e-6), 0.0, 1.0)
	_cycle(0, minf(m.glycolysis_flux, m.etc_flux + m.ferment_flux) * float(SCALE["cyto"]) * dt, SITE_GLY,
			SITE_FERMENT if _roll("ferment_pick", ferment_share) else SITE_SHUTTLE)
	_cycle(1, minf(m.matrix_flux * 4.0, m.etc_flux) * float(SCALE["matrix"]) * dt, SITE_CYCLE, SITE_COMPLEX1)
	_fix_timer += dt
	if _fix_timer >= 0.2:
		_fix_timer = 0.0
		_reconcile(0, SITE_GLY, SITE_SHUTTLE)
		_reconcile(1, SITE_CYCLE, SITE_COMPLEX1)
	for i: int in range(_tokens.size() - 1, -1, -1):
		var t: Dictionary = _tokens[i]
		if t["dying"]:
			t["alpha"] = float(t["alpha"]) - dt * 1.5
			if float(t["alpha"]) <= 0.0:
				_tokens.remove_at(i)
			continue
		t["alpha"] = minf(float(t["alpha"]) + dt * 1.5, 1.0)
		if t["mode"] == 0:
			continue
		var pos: Vector2 = t["pos"]
		var target: Vector2 = t["target"]
		var step: float = TOKEN_SPEED * dt
		if pos.distance_to(target) <= step:
			t["pos"] = target
			if t["mode"] == 1:
				t["nadh"] = t["becomes"]
				t["mode"] = 2
				t["target"] = _slot(int(t["c"]), int(t["slot"]))
			else:
				t["mode"] = 0
		else:
			t["pos"] = pos + (target - pos).normalized() * step
	# Everything else: released at the model's rates.
	for n: int in range(_due("glucose", m.glycolysis_flux * dt)):
		_spawn("glucose", [Vector2(4.0, 108.0), Vector2(92.0, 108.0)], 150.0)
	for n: int in range(_due("pyruvate", m.matrix_flux * dt)):
		_spawn("pyruvate", PYRUVATE_ROUTE, 190.0)
	for n: int in range(_due("pyruvate_f", m.ferment_flux * dt, "pyruvate")):
		_spawn("pyruvate", [Vector2(190.0, 138.0), Vector2(190.0, 192.0)], 90.0)
	for n: int in range(_due("co2", m.matrix_flux * dt)):
		_spawn("co2", [Vector2(790.0, 348.0), Vector2(790.0, 436.0)], 80.0)
	for n: int in range(_due("oxygen", m.etc_flux * dt)):
		_spawn("oxygen", [Vector2(772.0, 4.0), Vector2(728.0, 70.0)], 110.0)
	for n: int in range(_due("electron", m.etc_flux * dt)):
		_spawn("electron", [Vector2(COMPLEX_X[0], 98.0), Vector2(COMPLEX_X[2], 98.0)], 170.0)
	for n: int in range(_due("h_up", m.etc_flux * dt)):
		_complex_turn = (_complex_turn + 1) % 3
		_spawn("proton", [Vector2(COMPLEX_X[_complex_turn], 108.0), Vector2(COMPLEX_X[_complex_turn], 58.0)], 70.0)
	for n: int in range(_due("h_down", m.synthase_flux * dt)):
		_spawn("proton", [Vector2(SYNTHASE_X, 58.0), Vector2(SYNTHASE_X, 118.0)], 70.0)
	for n: int in range(_due("atp_ox", m.oxidative_atp * dt, "atp")):
		_spawn_atp(ATP_ROUTE)
	for n: int in range(_due("atp_sub", m.substrate_atp * dt, "atp")):
		_spawn_atp([Vector2(104.0, 138.0), Vector2(56.0, 240.0), Vector2(104.0, 340.0)])
	for i: int in range(_movers.size() - 1, -1, -1):
		var mv: Dictionary = _movers[i]
		mv["d"] = float(mv["d"]) + float(mv["speed"]) * dt
		if float(mv["d"]) >= float(mv["len"]):
			_movers.remove_at(i)


## How many whole events are due for `rate_dt` of flux. Fractions are kept, so slow rates still show.
func _due(key: String, rate_dt: float, scale_key: String = "") -> int:
	var total: float = float(_acc.get(key, 0.0)) + rate_dt * float(SCALE[scale_key if scale_key != "" else key])
	var n: int = int(floor(total))
	_acc[key] = total - float(n)
	return mini(n, 4)


## Deterministic "share of the time": true for about `share` of the calls, with no randomness.
func _roll(key: String, share: float) -> bool:
	var total: float = float(_acc.get(key, 0.0)) + share
	if total >= 1.0:
		_acc[key] = total - 1.0
		return true
	_acc[key] = total
	return false


func _cycle(c: int, events: float, reduce_site: Vector2, oxidize_site: Vector2) -> void:
	var key: String = "cycle%d" % c
	var total: float = float(_acc.get(key, 0.0)) + events
	while total >= 1.0:
		total -= 1.0
		_send(c, false, reduce_site)
		_send(c, true, oxidize_site)
	_acc[key] = minf(total, 1.0)


## Sends one idle carrier of the given form to a site, where it changes to the other form.
func _send(c: int, from_nadh: bool, site: Vector2) -> bool:
	for t: Dictionary in _tokens:
		if t["c"] == c and t["mode"] == 0 and not t["dying"] and t["nadh"] == from_nadh:
			t["mode"] = 1
			t["target"] = site
			t["becomes"] = not from_nadh
			return true
	return false


## Keeps the share of carriers drawn as NADH equal to the model's NADH share.
func _reconcile(c: int, reduce_site: Vector2, oxidize_site: Vector2) -> void:
	var n: int = 0
	var reduced: int = 0
	for t: Dictionary in _tokens:
		if t["c"] == c and not t["dying"]:
			n += 1
			if (t["becomes"] if t["mode"] == 1 else t["nadh"]):
				reduced += 1
	var want: int = roundi(controller.metabolism.nadh_fraction() * float(n))
	if reduced < want:
		_send(c, false, reduce_site)
	elif reduced > want:
		_send(c, true, oxidize_site)


func _spawn(kind: String, points: Array, speed: float, swap: float = -1.0) -> void:
	if _movers.size() >= MAX_MOVERS:
		return
	var path: PackedVector2Array = PackedVector2Array(points)
	var length: float = 0.0
	for i: int in range(path.size() - 1):
		length += path[i].distance_to(path[i + 1])
	_movers.append({"kind": kind, "path": path, "d": 0.0, "len": length, "speed": speed, "swap": swap})


## ATP travels to the work site, is used there, and comes back along the same route as ADP.
func _spawn_atp(points: Array) -> void:
	var there_and_back: Array = points.duplicate()
	for i: int in range(points.size() - 2, -1, -1):
		there_and_back.append(points[i])
	_spawn("atp", there_and_back, 230.0, 0.5)


static func _along(path: PackedVector2Array, d: float) -> Vector2:
	var left: float = d
	for i: int in range(path.size() - 1):
		var seg: float = path[i].distance_to(path[i + 1])
		if left <= seg or i == path.size() - 2:
			return path[i].lerp(path[i + 1], clampf(left / maxf(seg, 1e-6), 0.0, 1.0))
		left -= seg
	return path[path.size() - 1]


## Design point -> pixels.
func _p(v: Vector2) -> Vector2:
	return Vector2(v.x / DW * size.x, v.y / DH * size.y)


func _pts(points: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in points:
		out.append(_p(v))
	return out


func _rect(x0: float, y0: float, x1: float, y1: float) -> Rect2:
	return Rect2(_p(Vector2(x0, y0)), _p(Vector2(x1, y1)) - _p(Vector2(x0, y0)))


func _rate(key: String, flux: float) -> String:
	return Loc.t("cell.rate", {"pct": roundi(flux / float(REFERENCE[key]) * 100.0)})


func _draw() -> void:
	if controller == null:
		return
	var m: MetabolismModel = controller.metabolism
	_pal = SkTheme.palette(a11y.palette_name() if a11y != null else "dark")
	var hc: bool = a11y != null and a11y.high_contrast()
	var font: Font = get_theme_default_font()
	_k = clampf(minf(size.x / DW, size.y / DH) * 1.15, 0.6, 1.5)
	var fs: int = maxi(int(15.0 * clampf(_k, 0.8, 1.1)), 12)
	var small: int = maxi(fs - 2, 11)
	var text_c: Color = _pal["text"]
	var dim: Color = _pal["text_dim"]
	var line: Color = _pal["panel_edge"]
	var cyto: Color = Color(0.10, 0.17, 0.22) if not hc else Color(0, 0, 0)
	var inter: Color = Color(0.20, 0.16, 0.10) if not hc else Color(0, 0, 0)
	var matrix: Color = Color(0.16, 0.12, 0.20) if not hc else Color(0, 0, 0)
	var station: Color = _pal["button"]

	# Compartments
	PmDraw.rounded(self, Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), cyto, line, 14.0)
	PmDraw.text_left(self, font, _p(Vector2(10.0, 20.0)), Loc.t("cell.cytoplasm"), small, dim)
	PmDraw.rounded(self, _rect(440.0, 22.0, 990.0, 414.0), inter, PmDraw.GAS, 44.0 * _k, 3.0)
	PmDraw.rounded(self, _rect(462.0, MEMBRANE_Y, 968.0, 394.0), matrix, PmDraw.GAS, 34.0 * _k, 3.0)
	PmDraw.text_left(self, font, _p(Vector2(474.0, 40.0)), Loc.t("cell.intermembrane"), small, dim, size.x * 0.24)
	PmDraw.text_left(self, font, _p(Vector2(478.0, 380.0)), Loc.t("cell.matrix"), small, dim, size.x * 0.22)

	# Guide lines: where things travel (always drawn, so a still frame still shows the route)
	var guide: Color = Color(line.r, line.g, line.b, 0.55)
	PmDraw.path_arrow(self, _pts([Vector2(4.0, 108.0), Vector2(92.0, 108.0)]), guide)
	PmDraw.path_arrow(self, _pts(PYRUVATE_ROUTE), guide)
	PmDraw.path_arrow(self, _pts([Vector2(790.0, 348.0), Vector2(790.0, 434.0)]), guide)
	PmDraw.path_arrow(self, _pts([Vector2(772.0, 4.0), Vector2(729.0, 68.0)]), guide)
	PmDraw.path_arrow(self, _pts(ATP_ROUTE), guide)
	PmDraw.path_arrow(self, _pts([Vector2(104.0, 138.0), Vector2(56.0, 240.0), Vector2(104.0, 340.0)]), guide)
	PmDraw.path_arrow(self, _pts([Vector2(COMPLEX_X[0] + 24.0, 98.0), Vector2(COMPLEX_X[2] - 24.0, 98.0)]), PmDraw.ELECTRON.darkened(0.2))
	PmDraw.text_left(self, font, _p(Vector2(8.0, 86.0)), Loc.t("mol.glucose"), small, dim)
	PmDraw.text_left(self, font, _p(Vector2(312.0, 306.0)), Loc.t("mol.pyruvate"), small, dim)
	PmDraw.text_left(self, font, _p(Vector2(802.0, 428.0)), "CO₂", small, dim)
	PmDraw.text_left(self, font, _p(Vector2(782.0, 12.0)), "O₂", small, dim)
	PmDraw.text_left(self, font, _p(Vector2(750.0, 106.0)), "H₂O", small, dim)

	# Stations
	_station(font, fs, small, _rect(96.0, 80.0, 286.0, 138.0), Loc.t("cell.glycolysis"), _rate("glycolysis", m.glycolysis_flux), station, m.glycolysis_flux > 0.002)
	_station(font, fs, small, _rect(96.0, 192.0, 286.0, 238.0), Loc.t("cell.fermentation"), _rate("ferment", m.ferment_flux), station, m.ferment_flux > 0.012)
	var work: Rect2 = _rect(96.0, 340.0, 306.0, 400.0)
	_station(font, fs, small, work, Loc.t("cell.work_active" if controller.params.get_int("workload") == 1 else "cell.work_resting"),
			Loc.t("cell.work_done", {"pct": roundi(m.work_fraction() * 100.0)}), station, true)
	PmDraw.bar(self, Rect2(work.position + Vector2(8.0, work.size.y + 3.0), Vector2(work.size.x - 16.0, 7.0)), m.work_fraction(),
			_pal["ok"] if m.work_fraction() > 0.9 else _pal["warn"], line, _pal["bg"])
	# Shuttle gate on the mitochondrion's edge
	var gate: Vector2 = _p(Vector2(446.0, 180.0))
	PmDraw.rounded(self, Rect2(gate - Vector2(13.0, 22.0) * _k, Vector2(26.0, 44.0) * _k), station, PmDraw.ELECTRON, 6.0)
	PmDraw.electron_pair(self, gate, _k)
	# In a very narrow frame the two longest captions are left out (Help explains both); names and rates stay.
	var roomy: bool = size.x >= 560.0
	if roomy:
		PmDraw.text(self, font, _p(Vector2(364.0, 240.0)), Loc.t("cell.shuttle"), small, dim, size.x * 0.135)
	# Matrix stage
	var cyc: Vector2 = _p(Vector2(790.0, 290.0))
	var rad: float = minf(60.0 * size.x / DW, 58.0 * size.y / DH)
	draw_circle(cyc, rad, station)
	draw_arc(cyc, rad, 0.0, TAU, 40, text_c if m.matrix_flux > 0.002 else dim, 2.0, true)
	draw_arc(cyc, rad * 0.9, 0.4, TAU - 0.5, 28, dim, 1.5, true)
	PmDraw.text(self, font, cyc - Vector2(0.0, rad * 0.28), Loc.t("cell.cycle_detail" if detailed else "cell.cycle"), small, text_c, rad * 1.6)
	PmDraw.text(self, font, cyc + Vector2(0.0, rad * 0.58), _rate("matrix", m.matrix_flux), small, dim)
	# Electron transport complexes and ATP synthase on the inner membrane
	var blocked: bool = m.etc_block > 0.0
	for i: int in range(3):
		var c: Vector2 = _p(Vector2(COMPLEX_X[i], MEMBRANE_Y))
		PmDraw.rounded(self, Rect2(c - Vector2(22.0, 19.0) * _k, Vector2(44.0, 38.0) * _k), Color(0.30, 0.36, 0.56), text_c, 8.0)
		PmDraw.text(self, font, c, ["I", "III", "IV"][i], small, Color(1, 1, 1))
	if blocked:
		var b: Vector2 = _p(Vector2(COMPLEX_X[0], MEMBRANE_Y))
		draw_line(b - Vector2(20.0, 17.0) * _k, b + Vector2(20.0, 17.0) * _k, _pal["warn"], 4.0)
		draw_line(b + Vector2(-20.0, 17.0) * _k, b + Vector2(20.0, -17.0) * _k, _pal["warn"], 4.0)
	PmDraw.text_left(self, font, _p(Vector2(592.0, 134.0)), Loc.t("cell.etc"), small, text_c, size.x * 0.26)
	PmDraw.text_left(self, font, _p(Vector2(592.0, 158.0)), _rate("etc", m.etc_flux), small, dim)
	var syn: Vector2 = _p(Vector2(SYNTHASE_X, MEMBRANE_Y))
	draw_rect(Rect2(syn - Vector2(7.0, 20.0) * _k, Vector2(14.0, 40.0) * _k), PmDraw.ATP.darkened(0.25))
	draw_circle(syn + Vector2(0.0, 30.0) * _k, 16.0 * _k, PmDraw.ATP.darkened(0.25))
	draw_arc(syn + Vector2(0.0, 30.0) * _k, 16.0 * _k, 0.0, TAU, 20, text_c, 2.0, true)
	PmDraw.text(self, font, _p(Vector2(SYNTHASE_X - 36.0, 166.0)), Loc.t("cell.synthase"), small, text_c, size.x * 0.12)
	PmDraw.text(self, font, _p(Vector2(SYNTHASE_X - 36.0, 196.0)), _rate("synthase", m.synthase_flux), small, dim)
	# Protons waiting in the intermembrane space: the gradient
	var waiting: int = roundi(m.gradient * 22.0)
	for i: int in range(waiting):
		PmDraw.proton(self, _p(Vector2(626.0 + float(i % 11) * 25.0, 66.0 - float(i / 11) * 17.0)), _k * 0.85)
	# Niacin keeps the pool stocked
	PmDraw.niacin(self, font, _p(SITE_B3), _k)
	if roomy:
		PmDraw.text(self, font, _p(Vector2(SITE_B3.x, SITE_B3.y + 44.0)), Loc.t("cell.niacin_role"), small, dim, size.x * 0.13)
	PmDraw.text(self, font, _p(Vector2(362.0, 58.0)), Loc.t("cell.carriers", {"n": _count(0) + _count(1), "max": MAX_TOKENS}), small, text_c, size.x * 0.14)

	# Carriers
	for t: Dictionary in _tokens:
		PmDraw.nad(self, font, _p(t["pos"]), _k * 0.92, bool(t["nadh"]), clampf(float(t["alpha"]), 0.0, 1.0))
	# Things in flight
	for mv: Dictionary in _movers:
		var at: Vector2 = _p(_along(mv["path"], float(mv["d"])))
		match str(mv["kind"]):
			"glucose":
				PmDraw.glucose(self, at, _k)
			"pyruvate":
				PmDraw.pyruvate(self, at, _k)
			"co2":
				PmDraw.co2(self, at, _k)
			"oxygen":
				PmDraw.oxygen(self, at, _k)
			"electron":
				PmDraw.electron_pair(self, at, _k)
			"proton":
				PmDraw.proton(self, at, _k)
			"atp":
				PmDraw.atp(self, font, at, _k * 0.9, float(mv["d"]) < float(mv["len"]) * float(mv["swap"]))
	if not animating():
		PmDraw.text_left(self, font, _p(Vector2(130.0, 20.0)), Loc.t("cell.still_note"), small, dim, size.x * 0.3)


func _station(font: Font, fs: int, small: int, rect: Rect2, title: String, sub: String, fill: Color, active: bool) -> void:
	PmDraw.rounded(self, rect, fill, _pal["text"] if active else _pal["text_dim"], 8.0, 3.0 if active else 1.0)
	PmDraw.text(self, font, rect.get_center() - Vector2(0.0, rect.size.y * 0.2), title, fs if rect.size.y > 44.0 else small,
			_pal["text"] if active else _pal["text_dim"], rect.size.x - 8.0)
	PmDraw.text(self, font, rect.get_center() + Vector2(0.0, rect.size.y * 0.27), sub, small, _pal["text_dim"], rect.size.x - 8.0)
