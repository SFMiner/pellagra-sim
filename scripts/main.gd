extends Control
## The Pellagra Mystery: top-level wiring. Built in code on SimKit (addons/simkit, unedited).
##   SimController      the one scientific state (params, two clocks, four models)
##   Loc                the language catalogs (project-owned; the language is never saved)
##   SkA11y/SkViewScaler/SkFocusRing/SkHost   display settings, scaling, keyboard exit, page contract
## This file only builds the interface and passes player actions to the controller. View, language and
## open panels are display state: changing them never touches the model.

# === CONSTANTS ===
const BASE_SIZE: Vector2 = Vector2(1300.0, 550.0)
const VIEW_IDS: PackedStringArray = ["cell", "population"]
const OVERLAY_IDS: PackedStringArray = ["food", "evidence", "help"]
const PROMPT_KEYS: PackedStringArray = ["prompt.engage", "prompt.explore1", "prompt.explain1", "prompt.explore2",
		"prompt.explain2", "prompt.elaborate", "prompt.evaluate"]

# === PUBLIC VARIABLES ===
var loc: Loc = Loc.new()
var data: SimData = SimData.new()
var controller: SimController = SimController.new()
var a11y: SkA11y = SkA11y.new()
var scaler: SkViewScaler = SkViewScaler.new()
var ring: SkFocusRing = SkFocusRing.new()
## Optional settings from the page address (?view=population&food=degermed). Machine words, never shown.
var class_settings: SkParams = SkParams.new()
## Display-only choices that use SimKit's parameter panel (which graph line to show).
var ui_params: SkParams = SkParams.new()
var view_id: String = "cell"
var overlay_id: String = ""
var booted: bool = false

var cell_view: CellView = CellView.new()
var pop_view: PopulationView = PopulationView.new()
var inspector: FoodInspector = FoodInspector.new()
var evidence: EvidencePanel = EvidencePanel.new()
var help: HelpPanel = HelpPanel.new()
var transport: SkTransportBar = SkTransportBar.new()
var lang_button: Button = null
var view_buttons: Array[Button] = []
var open_buttons: Dictionary = {}
var graph: SkLineGraph = SkLineGraph.new()
var gauge_atp: SkGauge = SkGauge.new()
var gauge_nad: SkGauge = SkGauge.new()
var mini_kernel: KernelView = KernelView.new()
var food_panel: SkParamPanel = SkParamPanel.new()
var proc_panel: SkParamPanel = SkParamPanel.new()
var niacin_panel: SkParamPanel = SkParamPanel.new()
var rest_panel: SkParamPanel = SkParamPanel.new()
var cohort_panel: SkParamPanel = SkParamPanel.new()
var metric_panel: SkParamPanel = SkParamPanel.new()
var advanced_panel: SkParamPanel = SkParamPanel.new()
var a11y_panel: SkParamPanel = SkParamPanel.new()
var lesson_panel: SkLessonPanel = null
var sections: Dictionary = {}
var status: Label = null
var niacin_button: Button = null
var snapshot_buttons: Array[Button] = []
var csv_button: Button = null

# === PRIVATE VARIABLES ===
var _background: ColorRect = null
var _top_flow: HFlowContainer = null
var _title: Label = null
var _corner: Control = null
var _top_bar: HBoxContainer = null
var _split: SkSplitView = null
var _stage: Control = null
var _gauge_row: HFlowContainer = null
var _proc_caption: Label = null
var _diet_now: Label = null
var _niacin_note: Label = null
var _cohort_note: Label = null
var _kept_label: Label = null
var _save_note: Label = null
var _readout: Label = null
var _dirty: bool = true
var _plotted: int = 0
var _opened_from: Control = null
var _prompts_on: bool = false


# === LIFECYCLE METHODS ===
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--query=") and SkHost.query_override == "":
			SkHost.query_override = arg.substr(8)
	Loc.main = loc
	if not loc.load_all() or not data.load_all():
		_show_failure()
		return
	add_child(controller)
	controller.setup(data)
	_define_class_settings()
	var applied: Dictionary = class_settings.apply_query(SkHost.query_string())
	a11y.load_saved()
	a11y.read_browser()
	if applied.has("motion"):
		# An explicit class setting wins over the browser preference; it is not written to storage here.
		a11y.persist = false
		a11y.params.set_value(SkA11y.ID_MOTION, class_settings.get_int("motion") == 1)
		a11y.persist = true
	scaler.base_size = BASE_SIZE
	add_child(scaler)
	a11y.bind(self, scaler)
	ui_params.add(SkParam.choice_param("metric", "metric", PackedStringArray(["atp", "nad"]), 0))
	_prompts_on = class_settings.get_int("prompts") == 1
	_build_ui()
	_apply_class_settings()
	_localize()

	loc.changed.connect(_localize)
	a11y.changed.connect(_on_a11y_changed)
	controller.updated.connect(func() -> void: _dirty = true)
	controller.diet_changed.connect(_on_diet_changed)
	controller.history_changed.connect(_rebuild_graph)
	controller.session.state_changed.connect(_on_state_changed)
	ui_params.changed.connect(func(_id: String, _v: Variant) -> void: _rebuild_graph())
	scaler.scale_changed.connect(_on_scale_changed)
	_on_scale_changed(scaler.css_scale, scaler.view_size)
	_on_a11y_changed()
	ring.provider = _ring
	ring.close_topmost = close_overlay
	add_child(ring)
	booted = true
	print("pellagra-mystery: boot ok")


func _process(_delta: float) -> void:
	if booted and _dirty:
		_dirty = false
		_refresh()


# === PUBLIC METHODS ===
## Changes what is shown. The model is not told and does not change.
func set_view(id: String) -> void:
	if not VIEW_IDS.has(id):
		return
	view_id = id
	for i: int in range(view_buttons.size()):
		view_buttons[i].set_pressed_no_signal(VIEW_IDS[i] == id)
	_show_stage()
	_dirty = true
	SkHost.announce(Loc.t("a11y.view_" + id))


func open_overlay(id: String) -> void:
	if not OVERLAY_IDS.has(id):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if overlay_id == "":
		_opened_from = focused
	overlay_id = id
	_show_stage()
	SkHost.announce(Loc.t("a11y.opened_" + id))
	if focused != null:
		_overlay().focus_controls()[0].grab_focus()


## Closes the open panel and returns to the view that was showing. Returns false if none was open.
func close_overlay() -> bool:
	if overlay_id == "":
		return false
	overlay_id = ""
	_show_stage()
	SkHost.announce(Loc.t("a11y.closed"))
	if _opened_from != null and is_instance_valid(_opened_from) and _opened_from.is_visible_in_tree():
		_opened_from.grab_focus()
	_opened_from = null
	return true


## Switches to the language named on the button. Text only: no clock, model or setting is touched.
func switch_language() -> void:
	var before: Array[Control] = ring.current_ring()
	var index: int = before.find(get_viewport().gui_get_focus_owner())
	loc.cycle()
	if index >= 0:
		var after: Array[Control] = ring.current_ring()
		if index < after.size():
			after[index].grab_focus()
	SkHost.announce(Loc.t("a11y.language"))


func keep_snapshot(slot: String) -> void:
	controller.keep_snapshot(slot)
	SkHost.announce(Loc.t("a11y.kept", {"label": _snapshot_label(slot)}))


# === PRIVATE METHODS ===
func _show_failure() -> void:
	# Shown only if the bundled data or language files are missing, so it cannot come from a catalog.
	var label: Label = SkUi.label("The simulation's files did not load. Reload the page.\nNo se cargaron los archivos de la simulación. Vuelve a cargar la página.", 20, true)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(label)
	push_error("pellagra-mystery: data or language files missing: %s %s" % [loc.errors, data.errors])


func _define_class_settings() -> void:
	class_settings.add(SkParam.choice_param("view", "View", VIEW_IDS, 0).as_class_setting()
			.with_help("Which view opens first."))
	class_settings.add(SkParam.choice_param("food", "Food", PackedStringArray(["whole", "degermed", "diverse"]), 0).as_class_setting()
			.with_help("Food source selected at the start."))
	class_settings.add(SkParam.choice_param("processing", "Processing", PackedStringArray(["untreated", "nixtamalized", "degermed", "fortified"]), 0)
			.as_class_setting().with_help("Processing selected at the start. Used only where it fits the food: whole corn takes untreated or nixtamalized; degermed cornmeal takes degermed (unfortified) or fortified. Anything else falls back to the food's default."))
	class_settings.add(SkParam.choice_param("detail", "Detail", PackedStringArray(["basic", "advanced"]), 0).as_class_setting()
			.with_help("advanced opens the Advanced data section and uses fuller pathway names."))
	class_settings.add(SkParam.choice_param("particles", "Particles", PackedStringArray(["on", "off"]), 0).as_class_setting()
			.with_help("off shows the cell as a still frame with counts and rate labels."))
	class_settings.add(SkParam.choice_param("motion", "Motion", PackedStringArray(["normal", "reduced"]), 0).as_class_setting()
			.with_help("reduced turns on Reduced motion. When the key is absent the browser's preference is used."))
	class_settings.add(SkParam.choice_param("prompts", "Prompts", PackedStringArray(["off", "on"]), 0).as_class_setting()
			.with_help("on adds the optional discussion prompts section. Nothing is ever required or blocked."))


func _apply_class_settings() -> void:
	var food: int = class_settings.get_int("food")
	controller.params.set_value("food", food)
	var wanted: String = ["untreated", "nixtamalized", "degermed", "fortified"][class_settings.get_int("processing")]
	if wanted == "degermed":
		wanted = "unfortified"
	var options: Array = data.foods["processing"][controller.food_id()]
	if options.has(wanted):
		controller.params.set_value("proc_" + controller.food_id(), options.find(wanted))
	mini_kernel.settle()
	inspector.kernel.settle()
	cell_view.detailed = class_settings.get_int("detail") == 1
	cell_view.particles_enabled = class_settings.get_int("particles") == 0
	(sections["advanced"] as PmSection).set_open(cell_view.detailed)
	view_id = VIEW_IDS[class_settings.get_int("view")]
	for i: int in range(view_buttons.size()):
		view_buttons[i].set_pressed_no_signal(VIEW_IDS[i] == view_id)
	_show_stage()


func _overlay() -> Control:
	match overlay_id:
		"food":
			return inspector
		"evidence":
			return evidence
		"help":
			return help
	return null


func _show_stage() -> void:
	cell_view.visible = overlay_id == "" and view_id == "cell"
	pop_view.visible = overlay_id == "" and view_id == "population"
	inspector.visible = overlay_id == "food"
	evidence.visible = overlay_id == "evidence"
	help.visible = overlay_id == "help"
	# In a short or a stacked (narrow) frame the gauges give their room to the picture; the status line
	# under it always states the same two numbers in words.
	_gauge_row.visible = cell_view.visible and scaler.view_size.y >= 500.0 \
			and scaler.view_size.x - 16.0 >= _split.narrow_below
	(sections["community"] as PmSection).set_open(view_id == "population" or (sections["community"] as PmSection).is_open())
	if pop_view.visible:
		pop_view.refresh()
	cell_view.queue_redraw()


## The controls Tab walks, in reading order. Hidden ones are skipped by SkFocusRing.
func _ring() -> Array:
	var out: Array = []
	out.append_array(view_buttons)
	out.append_array(transport.focus_controls())
	out.append(lang_button)
	if overlay_id != "":
		out.append_array(_overlay().call("focus_controls"))
	for id: String in OVERLAY_IDS:
		out.append(open_buttons[id])
	var diet: PmSection = sections["diet"]
	out.append(diet.header)
	out.append_array(food_panel.focus_controls())
	out.append_array(proc_panel.focus_controls())
	out.append_array(niacin_panel.focus_controls())
	out.append(niacin_button)
	out.append_array(rest_panel.focus_controls())
	out.append((sections["community"] as PmSection).header)
	out.append_array(cohort_panel.focus_controls())
	out.append((sections["graph"] as PmSection).header)
	out.append_array(metric_panel.focus_controls())
	out.append_array(snapshot_buttons)
	out.append(csv_button)
	out.append((sections["advanced"] as PmSection).header)
	out.append_array(advanced_panel.focus_controls())
	if lesson_panel != null:
		out.append((sections["prompts"] as PmSection).header)
		out.append_array(lesson_panel.focus_controls())
	out.append((sections["display"] as PmSection).header)
	out.append_array(a11y_panel.focus_controls())
	return out


func _build_ui() -> void:
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 4)
	add_child(root_box)

	# Top bar: title, view switch, clock, language. The right end is left empty for the site's button.
	_top_bar = HBoxContainer.new()
	root_box.add_child(_top_bar)
	var pad: Control = Control.new()
	pad.custom_minimum_size.x = 8.0
	_top_bar.add_child(pad)
	_top_flow = HFlowContainer.new()
	_top_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_flow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_top_flow.add_theme_constant_override("h_separation", 8)
	_top_flow.add_theme_constant_override("v_separation", 4)
	_top_bar.add_child(_top_flow)
	_title = SkUi.label("", 21)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	loc.bind(_title, "text", "app.title")
	_top_flow.add_child(_title)
	var group: ButtonGroup = ButtonGroup.new()
	for id: String in VIEW_IDS:
		var b: Button = SkUi.button("", true)
		b.button_group = group
		b.pressed.connect(set_view.bind(id))
		loc.bind(b, "text", "ui.view_" + id)
		loc.bind(b, "tooltip_text", "ui.view_tip")
		_top_flow.add_child(b)
		view_buttons.append(b)
	transport.show_speed = false
	transport.bind(controller.session)
	_top_flow.add_child(transport)
	lang_button = SkUi.button("")
	lang_button.pressed.connect(switch_language)
	_top_flow.add_child(lang_button)
	_corner = Control.new()
	_top_bar.add_child(_corner)

	var content: MarginContainer = MarginContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 8)
	root_box.add_child(content)

	# Main pane: the stage (one view or one open panel), the two gauges, the status line
	var main_pane: VBoxContainer = VBoxContainer.new()
	main_pane.add_theme_constant_override("separation", 4)
	_stage = Control.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(300.0, 200.0)
	_stage.clip_contents = true
	main_pane.add_child(_stage)
	cell_view.setup(controller, a11y)
	pop_view.setup(controller, a11y)
	inspector.setup(controller, a11y)
	evidence.setup(data, a11y)
	help.setup(a11y)
	for panel: Control in [cell_view, pop_view, inspector, evidence, help]:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_stage.add_child(panel)
	for overlay: Variant in [inspector, evidence, help]:
		overlay.close_requested.connect(close_overlay)
	# A flow, so that in a narrow frame the second gauge drops below the first instead of pushing the page wider.
	_gauge_row = HFlowContainer.new()
	_gauge_row.add_theme_constant_override("h_separation", 16)
	main_pane.add_child(_gauge_row)
	for g: SkGauge in [gauge_atp, gauge_nad]:
		g.unit = "%"
		g.min_value = 0.0
		g.max_value = 100.0
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_gauge_row.add_child(g)
	status = SkUi.label("", 0, true)
	main_pane.add_child(status)

	# Side pane: every control, in collapsible sections (SkSplitView scrolls it)
	var side: VBoxContainer = VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	var open_row: HFlowContainer = HFlowContainer.new()
	open_row.add_theme_constant_override("h_separation", 6)
	open_row.add_theme_constant_override("v_separation", 6)
	side.add_child(open_row)
	for id: String in OVERLAY_IDS:
		var ob: Button = SkUi.button("")
		ob.pressed.connect(open_overlay.bind(id))
		loc.bind(ob, "text", "ui.open_" + id)
		open_row.add_child(ob)
		open_buttons[id] = ob

	var diet: PmSection = _section(side, "diet", true)
	food_panel.show_reset = false
	diet.body.add_child(food_panel)
	_proc_caption = SkUi.label("", 0, true)
	diet.body.add_child(_proc_caption)
	mini_kernel.compact = true
	mini_kernel.custom_minimum_size = Vector2(200.0, 104.0)
	mini_kernel.setup(controller, a11y)
	diet.body.add_child(mini_kernel)
	proc_panel.show_reset = false
	diet.body.add_child(proc_panel)
	_diet_now = SkUi.label("", 0, true)
	diet.body.add_child(_diet_now)
	niacin_panel.show_reset = false
	diet.body.add_child(niacin_panel)
	_niacin_note = SkUi.label("", 0, true)
	diet.body.add_child(_niacin_note)
	niacin_button = SkUi.button("")
	niacin_button.pressed.connect(_on_use_food_niacin)
	loc.bind(niacin_button, "text", "niacin.use_food")
	diet.body.add_child(niacin_button)
	rest_panel.show_reset = false
	diet.body.add_child(rest_panel)

	var community: PmSection = _section(side, "community", false)
	cohort_panel.show_reset = false
	community.body.add_child(cohort_panel)
	_cohort_note = SkUi.label("", 0, true)
	community.body.add_child(_cohort_note)

	var graph_section: PmSection = _section(side, "graph", true)
	metric_panel.show_reset = false
	graph_section.body.add_child(metric_panel)
	graph.custom_minimum_size = Vector2(240.0, 200.0)
	graph.auto_y = false
	graph.y_range = Vector2(0.0, 100.0)
	graph.y_format = "%.0f%%"
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_section.body.add_child(graph)
	_kept_label = SkUi.label("", 0, true)
	graph_section.body.add_child(_kept_label)
	var snap_row: HFlowContainer = HFlowContainer.new()
	snap_row.add_theme_constant_override("h_separation", 6)
	snap_row.add_theme_constant_override("v_separation", 6)
	graph_section.body.add_child(snap_row)
	for slot: String in SimController.SNAPSHOT_SLOTS:
		var sb: Button = SkUi.button("")
		sb.pressed.connect(keep_snapshot.bind(slot))
		loc.bind(sb, "text", "snapshot.keep_" + slot)
		snap_row.add_child(sb)
		snapshot_buttons.append(sb)
	var clear_button: Button = SkUi.button("")
	clear_button.pressed.connect(_on_clear_snapshots)
	loc.bind(clear_button, "text", "snapshot.clear")
	snap_row.add_child(clear_button)
	snapshot_buttons.append(clear_button)
	csv_button = SkUi.button("")
	csv_button.pressed.connect(_on_save_csv)
	loc.bind(csv_button, "text", "data.save_csv")
	graph_section.body.add_child(csv_button)
	_save_note = SkUi.label("", 0, true)
	graph_section.body.add_child(_save_note)

	var advanced: PmSection = _section(side, "advanced", false)
	_readout = SkUi.label("", 0, true)
	advanced.body.add_child(_readout)
	var tag: Label = SkUi.label("", 0, true)
	loc.bind(tag, "text", "advanced.intervention_tag")
	advanced.body.add_child(tag)
	advanced_panel.show_reset = false
	advanced.body.add_child(advanced_panel)

	if _prompts_on:
		var prompts: PmSection = _section(side, "prompts", true)
		lesson_panel = SkLessonPanel.new()
		prompts.body.add_child(lesson_panel)

	var display: PmSection = _section(side, "display", false)
	a11y_panel.show_reset = false
	display.body.add_child(a11y_panel)
	var storage_note: Label = SkUi.label("", 0, true)
	loc.bind(storage_note, "text", "display.note")
	display.body.add_child(storage_note)

	_split = SkSplitView.new()
	_split.side_width = 400.0
	_split.main_min_height = 420.0
	_split.set_panes(main_pane, side)
	content.add_child(_split)


func _section(parent: Control, id: String, open: bool) -> PmSection:
	var s: PmSection = PmSection.create("section." + id, open)
	parent.add_child(s)
	sections[id] = s
	return s


## Every word on screen, from the catalogs, for the current language. Values and clocks are not touched.
func _localize() -> void:
	ParamText.apply(controller.params)
	ParamText.apply(ui_params)
	ParamText.apply(a11y.params, {SkA11y.ID_TEXT: PackedStringArray(["normal", "large", "xlarge"])})
	food_panel.bind(controller.params, PackedStringArray(["food"]))
	niacin_panel.bind(controller.params, PackedStringArray(["niacin"]))
	rest_panel.bind(controller.params, PackedStringArray(["calories", "workload", "lapse"]))
	cohort_panel.bind(controller.params, PackedStringArray(["cohort"]))
	advanced_panel.bind(controller.params, PackedStringArray(["oxygen", "etc_block"]))
	metric_panel.bind(ui_params)
	a11y_panel.bind(a11y.params)
	_rebuild_proc()
	for id: String in sections:
		(sections[id] as PmSection).refresh_text()
	lang_button.text = str(loc.next_language()["name"])
	lang_button.tooltip_text = Loc.t("ui.language_tip")
	gauge_atp.heading = Loc.t("gauge.atp")
	gauge_nad.heading = Loc.t("gauge.nad")
	gauge_atp.queue_redraw()
	gauge_nad.queue_redraw()
	_cohort_note.text = Loc.t("cohort.note")
	if lesson_panel != null:
		_show_prompts()
	if booted:
		inspector.refresh_text()
		evidence.refresh_text()
		help.refresh_text()
	pop_view.refresh_text()
	mini_kernel.queue_redraw()
	cell_view.queue_redraw()
	_rebuild_graph()
	_fit_transport.call_deferred()
	_dirty = true


func _show_prompts() -> void:
	var was_open: bool = lesson_panel.toggle_button == null or lesson_panel.toggle_button.button_pressed
	var title: String = Loc.t("prompt.title")
	var observations: Array = []
	for key: String in PROMPT_KEYS:
		observations.append(Loc.t(key))
		# SimKit builds "Observe: " + prompt itself, in English; register that whole line's translation.
		loc.add_literal("Observe: " + Loc.t(key), Loc.t("sk.observe", {"prompt": Loc.t(key)}))
	loc.add_literal("Lesson: %s (hide)" % title, Loc.t("sk.lesson_hide", {"title": title}))
	loc.add_literal("Lesson: %s (show)" % title, Loc.t("sk.lesson_show", {"title": title}))
	lesson_panel.show_lesson(SkLesson.from_dict({"title": title, "instructions": Loc.t("prompt.instructions"),
			"observations": observations}))
	if not was_open:
		lesson_panel.toggle_button.button_pressed = false


## The processing controls for the food now chosen, with the step that has already happened said in words.
func _rebuild_proc() -> void:
	var food: String = controller.food_id()
	_proc_caption.text = Loc.t("proc.caption." + food)
	var options: Array = data.foods["processing"][food]
	proc_panel.visible = not options.is_empty()
	if options.is_empty():
		proc_panel.bind(controller.params, PackedStringArray(["none"]))
	else:
		proc_panel.bind(controller.params, PackedStringArray(["proc_" + food]))
	_diet_now.text = Loc.t("diet.now", {"profile": Loc.t("profile." + controller.profile_id())})


func _fit_transport() -> void:
	# An HFlowContainer inside another one is only given its narrowest width, so say how wide one row is.
	var want: float = 0.0
	for b: Control in transport.focus_controls():
		want += b.get_combined_minimum_size().x + 6.0
	# Room for the longest word the play button will show (Start becomes Pause or Resume).
	want += 36.0
	transport.custom_minimum_size.x = minf(want, maxf(scaler.view_size.x - _corner.custom_minimum_size.x - 32.0, 120.0))


func _snapshot_label(slot: String) -> String:
	if not controller.snapshots.has(slot):
		return ""
	var s: Dictionary = controller.snapshots[slot]
	var diet: String = Loc.t("profile." + str(s["profile"]))
	if bool(s["custom"]):
		diet = Loc.t("snapshot.custom", {"pct": roundi(float(s["niacin"]))})
	return Loc.t("snapshot.label", {"slot": Loc.t("snapshot.short." + slot), "diet": diet,
			"workload": Loc.t("param.workload." + ("active" if int(s["workload"]) == 1 else "resting")),
			"calories": Loc.t("param.calories." + ["low", "adequate", "high"][int(s["calories"])])})


func _metric() -> String:
	return "nad" if ui_params.get_int("metric") == 1 else "atp"


func _rebuild_graph() -> void:
	graph.clear()
	var metric: String = _metric()
	graph.title = Loc.t("graph.title_" + metric)
	graph.x_label = Loc.t("graph.x")
	_plotted = 0
	graph.set_series("now", Loc.t("graph.now"), PackedVector2Array())
	var lines: PackedStringArray = PackedStringArray()
	for slot: String in SimController.SNAPSHOT_SLOTS:
		if controller.snapshots.has(slot):
			var snap: Dictionary = controller.snapshots[slot]
			var d: PackedFloat64Array = snap["days"]
			var y: PackedFloat64Array = snap[metric]
			var pts: PackedVector2Array = PackedVector2Array()
			for i: int in range(d.size()):
				pts.append(Vector2(d[i], y[i]))
			graph.set_series("kept_" + slot, Loc.t("snapshot.short." + slot), pts, true)
			lines.append(_snapshot_label(slot))
	_kept_label.text = Loc.t("snapshot.none") if lines.is_empty() else Loc.t("snapshot.list", {"list": "\n".join(lines)})
	_append_points()
	pop_view.rebuild_graph()


func _append_points() -> void:
	var d: PackedFloat64Array = controller.hist_days
	var y: PackedFloat64Array = controller.hist_nad if _metric() == "nad" else controller.hist_atp
	while _plotted < d.size():
		graph.append_point("now", Loc.t("graph.now"), d[_plotted], y[_plotted])
		_plotted += 1
	var span: float = maxf(60.0, ceilf(controller.days / 30.0) * 30.0)
	for slot: String in controller.snapshots:
		var kd: PackedFloat64Array = controller.snapshots[slot]["days"]
		if not kd.is_empty():
			span = maxf(span, ceilf(kd[kd.size() - 1] / 30.0) * 30.0)
	graph.x_range = Vector2(0.0, span)


## Copies the model's numbers into the gauges, labels and graphs. Reads only.
func _refresh() -> void:
	var m: MetabolismModel = controller.metabolism
	gauge_atp.value = m.atp * 100.0
	gauge_nad.value = m.nad_total * 100.0
	var s: SkSession = controller.session
	var state_key: String = "status.ready"
	if s.state == SkSession.State.RUNNING:
		state_key = "status.running"
	elif s.state == SkSession.State.PAUSED:
		state_key = "status.paused"
	status.text = Loc.t("status.line", {"state": Loc.t(state_key), "day": "%.1f" % controller.days,
			"lapse": Loc.t("status.lapse_" + ParamText.machine_value(controller.params, "lapse")),
			"atp": roundi(m.atp * 100.0), "nad": roundi(m.nad_total * 100.0)})
	var food_pct: int = roundi(controller.food_usable() * 100.0)
	if controller.niacin_custom:
		_niacin_note.text = Loc.t("niacin.custom", {"pct": roundi(controller.params.get_float("niacin")), "food": food_pct})
	else:
		_niacin_note.text = Loc.t("niacin.from_food", {"pct": food_pct})
	niacin_button.visible = controller.niacin_custom
	if (sections["advanced"] as PmSection).is_open():
		_readout.text = Loc.t("advanced.readout", {
			"nadp": roundi((1.0 - m.nadh_fraction()) * 100.0), "nadh": roundi(m.nadh_fraction() * 100.0),
			"pool": roundi(m.nad_total * 100.0), "s": roundi(controller.nutrition.sufficiency * 100.0),
			"usable": roundi(controller.usable_now() * 100.0),
			"gly": "%.3f" % m.glycolysis_flux, "mat": "%.3f" % m.matrix_flux, "fer": "%.3f" % m.ferment_flux,
			"etc": "%.3f" % m.etc_flux, "grad": roundi(m.gradient * 100.0), "oxy": roundi(m.oxygen * 100.0),
			"made": "%.2f" % m.atp_production, "sub": "%.2f" % m.substrate_atp, "ox": "%.2f" % m.oxidative_atp,
			"demand": "%.2f" % m.demand, "work": roundi(m.work_fraction() * 100.0)})
	_append_points()
	if pop_view.visible:
		pop_view.refresh()


func _on_diet_changed(_food_changed: bool) -> void:
	_rebuild_proc()
	SkHost.announce(Loc.t("a11y.diet", {"profile": Loc.t("profile." + controller.profile_id()),
			"pct": roundi(controller.food_usable() * 100.0)}))
	_dirty = true


func _on_use_food_niacin() -> void:
	controller.use_food_niacin()
	SkHost.announce(Loc.t("niacin.from_food", {"pct": roundi(controller.food_usable() * 100.0)}))
	var slider: Control = niacin_panel.control_for("niacin")
	if slider != null:
		slider.grab_focus()


func _on_clear_snapshots() -> void:
	controller.clear_snapshots()
	SkHost.announce(Loc.t("snapshot.none"))


func _on_save_csv() -> void:
	var result: String = SkExport.save_table_csv(controller.log, "history", "pellagra-mystery-data.csv")
	if result == "ERROR":
		_save_note.text = Loc.t("data.save_failed")
	elif result == "":
		_save_note.text = Loc.t("data.save_browser")
	else:
		_save_note.text = Loc.t("data.saved", {"path": result})
	SkHost.announce(_save_note.text, result == "ERROR")


## A pause is the moment to say where things stand (screen readers cannot see the picture).
func _on_state_changed(new_state: int) -> void:
	_dirty = true
	_fit_transport.call_deferred()
	if new_state == SkSession.State.PAUSED:
		# SimKit says "Paused" right after this signal; a summary sent now would be replaced by it.
		get_tree().create_timer(0.5).timeout.connect(_announce_summary)


func _announce_summary() -> void:
	if controller.session.state == SkSession.State.PAUSED:
		SkHost.announce(pop_view.describe() if view_id == "population" else cell_view.describe())


func _on_a11y_changed() -> void:
	var pal: Dictionary = SkTheme.palette(a11y.palette_name())
	_background.color = pal["bg"]
	RenderingServer.set_default_clear_color(pal["bg"])
	for overlay: Variant in [inspector, evidence, help]:
		overlay.set_focus_color(pal["focus"])
	_fit_transport.call_deferred()
	_dirty = true


func _on_scale_changed(css: float, view: Vector2) -> void:
	# The top-right 200 x 64 CSS px belongs to the site's Full screen button: nothing of ours goes there.
	var reserved: Vector2 = SkHost.RESERVED_CSS / maxf(css, 0.01)
	_corner.custom_minimum_size.x = reserved.x
	_top_bar.custom_minimum_size.y = reserved.y
	_title.visible = view.x >= 1180.0
	_split.side_width = clampf(view.x * 0.31, 330.0, 420.0)
	_show_stage()
	_fit_transport.call_deferred()
