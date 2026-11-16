class_name FoodInspector
extends PanelContainer
## The food panel that opens over the main view: a labelled kernel cross-section (what processing does)
## and a storage experiment with its own clock (two samples, same conditions).
## The storage clock is separate: starting it never advances the cell or the community.

# === SIGNALS ===
signal close_requested

# === PUBLIC VARIABLES ===
var controller: SimController = null
var a11y: SkA11y = null
var kernel: KernelView = KernelView.new()
var decomp: DecompView = DecompView.new()
var bar: SkTransportBar = SkTransportBar.new()
var panel: SkParamPanel = SkParamPanel.new()
var graph: SkLineGraph = SkLineGraph.new()
var close_button: Button = null
var tab_kernel: Button = null
var tab_storage: Button = null
var replay_button: Button = null

# === PRIVATE VARIABLES ===
var _kernel_page: VBoxContainer = null
var _storage_page: HBoxContainer = null
var _kernel_text: Label = null
var _status: Label = null
var _note: Label = null
var _scroll: KeyScroll = null


# === PUBLIC METHODS ===
func setup(p_controller: SimController, p_a11y: SkA11y) -> void:
	controller = p_controller
	a11y = p_a11y
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var head: HFlowContainer = HFlowContainer.new()
	head.add_theme_constant_override("h_separation", 6)
	root.add_child(head)
	var group: ButtonGroup = ButtonGroup.new()
	tab_kernel = SkUi.button("", true)
	tab_kernel.button_group = group
	tab_kernel.button_pressed = true
	tab_kernel.pressed.connect(show_tab.bind(0))
	Loc.main.bind(tab_kernel, "text", "food.tab_kernel")
	head.add_child(tab_kernel)
	tab_storage = SkUi.button("", true)
	tab_storage.button_group = group
	tab_storage.pressed.connect(show_tab.bind(1))
	Loc.main.bind(tab_storage, "text", "food.tab_storage")
	head.add_child(tab_storage)
	close_button = SkUi.button("")
	close_button.pressed.connect(func() -> void: close_requested.emit())
	Loc.main.bind(close_button, "text", "ui.close")
	head.add_child(close_button)

	# Page 1: the kernel
	_kernel_page = VBoxContainer.new()
	_kernel_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_kernel_page)
	kernel.setup(controller, a11y)
	kernel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kernel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kernel.custom_minimum_size = Vector2(300.0, 150.0)
	_kernel_page.add_child(kernel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_kernel_page.add_child(row)
	replay_button = SkUi.button("")
	replay_button.pressed.connect(_on_replay)
	Loc.main.bind(replay_button, "text", "food.replay")
	row.add_child(replay_button)
	_kernel_text = SkUi.label("", 0, true)
	row.add_child(_kernel_text)

	# Page 2: storage and decomposition
	_storage_page = HBoxContainer.new()
	_storage_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_storage_page.add_theme_constant_override("separation", 8)
	_storage_page.visible = false
	root.add_child(_storage_page)
	decomp.setup(controller, a11y)
	decomp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decomp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	decomp.size_flags_stretch_ratio = 1.15
	_storage_page.add_child(decomp)
	var side: VBoxContainer = VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	_scroll = KeyScroll.new()
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(side)
	_storage_page.add_child(_scroll)
	bar.show_speed = false
	bar.hotkeys = false
	bar.bind(controller.decomp_session)
	side.add_child(bar)
	_status = SkUi.label("", 0, true)
	side.add_child(_status)
	panel.show_reset = false
	side.add_child(panel)
	graph.custom_minimum_size = Vector2(220.0, 170.0)
	graph.auto_y = false
	graph.y_range = Vector2(0.0, 100.0)
	graph.y_format = "%.0f%%"
	graph.x_range = Vector2(0.0, controller.decomp_session.duration)
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(graph)
	_note = SkUi.label("", 0, true)
	side.add_child(_note)

	controller.decomp_updated.connect(refresh)
	controller.decomp_session.reset_done.connect(_restart_graph)
	controller.decomp_session.state_changed.connect(func(_s: int) -> void: refresh())
	controller.updated.connect(_refresh_kernel_text)
	_restart_graph()
	refresh_text()


func show_tab(index: int) -> void:
	_kernel_page.visible = index == 0
	_storage_page.visible = index == 1
	tab_kernel.set_pressed_no_signal(index == 0)
	tab_storage.set_pressed_no_signal(index == 1)


func focus_controls() -> Array[Control]:
	var out: Array[Control] = [tab_kernel, tab_storage, close_button, replay_button, _scroll]
	out.append_array(bar.focus_controls())
	out.append_array(panel.focus_controls())
	return out


func set_focus_color(color: Color) -> void:
	_scroll.focus_color = color


## Language changed: rebuild everything that holds words.
func refresh_text() -> void:
	ParamText.apply(controller.decomp_params)
	panel.bind(controller.decomp_params)
	graph.title = Loc.t("decomp.graph_title")
	graph.x_label = Loc.t("decomp.graph_x")
	_note.text = Loc.t("decomp.note")
	_refresh_kernel_text()
	refresh()
	kernel.queue_redraw()
	decomp.queue_redraw()


func refresh() -> void:
	var s: SkSession = controller.decomp_session
	var state_key: String = "decomp.state_ready"
	if s.state == SkSession.State.RUNNING:
		state_key = "decomp.state_running"
	elif s.state == SkSession.State.PAUSED:
		state_key = "decomp.state_paused"
	elif s.state == SkSession.State.FINISHED:
		state_key = "decomp.state_finished"
	_status.text = Loc.t("decomp.status", {"day": roundi(s.sim_time), "days": roundi(s.duration), "state": Loc.t(state_key),
			"rate": roundi(s.speed)})
	for i: int in range(2):
		var m: DecompositionModel = controller.samples[i]
		var id: String = "a" if i == 0 else "b"
		if graph.point_count(id) == 0 or m.day > graph.series_points(id)[graph.point_count(id) - 1].x + 0.99:
			graph.append_point(id, _series_label(i), m.day, m.food / m.total() * 100.0)


# === PRIVATE METHODS ===
func _series_label(i: int) -> String:
	return "A" if i == 0 else "B"


func _restart_graph() -> void:
	graph.clear()
	for i: int in range(2):
		var m: DecompositionModel = controller.samples[i]
		graph.append_point("a" if i == 0 else "b", _series_label(i), m.day, m.food / m.total() * 100.0)


func _refresh_kernel_text() -> void:
	if _kernel_text != null:
		_kernel_text.text = Loc.t("kernel.explain." + controller.profile_id())


func _on_replay() -> void:
	kernel.replay()
	SkHost.announce(Loc.t("kernel.explain." + controller.profile_id()))
