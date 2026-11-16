extends "res://tests/pm_test.gd"
## The whole game, headless: boot, no auto-play, language switching (text only, state untouched),
## no English left in Spanish mode, keyboard ring and exit, the reserved corner, class settings from the
## address, kept runs, small frames, and the still frame used for reduced motion.

const MainScene: PackedScene = preload("res://Main.tscn")


func _boot(query: String = "") -> Control:
	SkHost.query_override = query
	var main: Control = MainScene.instantiate()
	root.add_child(main)
	main.a11y.persist = false
	await frames(4)
	return main


## Lets real time pass until the main clock reaches `sim_time` (at most about 10 s).
func _until(c: SimController, sim_time: float) -> void:
	var stop: int = Time.get_ticks_msec() + 10000
	while c.session.sim_time < sim_time and Time.get_ticks_msec() < stop:
		await process_frame


func _key(code: Key, shift: bool = false) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.shift_pressed = shift
	ev.pressed = true
	root.push_input(ev)


## Text as the player sees it (SimKit's own English goes through the engine's translation).
func _shown(node: Node) -> String:
	return node.atr(str(node.get("text")))


## Every visible Label and Button whose text is English that should have been translated.
func _english_left(main: Control, english_only: Dictionary, long_english: Array) -> Array:
	var found: Array = []
	var stack: Array = [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for child: Node in n.get_children():
			stack.append(child)
		if not (n is Label or n is Button) or not (n as Control).is_visible_in_tree():
			continue
		var s: String = _shown(n)
		if s == "" or n == main.lang_button:
			continue
		if english_only.has(s):
			found.append(s)
			continue
		for phrase: String in long_english:
			if s.contains(phrase):
				found.append(s)
				break
	return found


func run() -> void:
	test_name = "interface"
	root.size = Vector2i(1300, 550)
	var main: Control = await _boot()
	var c: SimController = main.controller
	var loc: Loc = main.loc

	# --- Boot, and nothing runs by itself
	check(main.booted, "the game boots")
	await frames(40)
	check(c.session.state == SkSession.State.READY and approx(c.session.sim_time, 0.0) and approx(c.days, 0.0), "nothing runs before the player presses Start")
	check(c.decomp_session.state == SkSession.State.READY, "the storage clock waits too")
	check(not main.mini_kernel.is_playing() and main.cell_view.mover_count() == 0, "no animation plays before input")
	check(loc.code == "en" and main.lang_button.text == "Español", "it starts in English and the button reads Español")
	check(main.view_id == "cell" and main.cell_view.visible and not main.pop_view.visible, "the cell view opens first")
	check(main.cell_view.token_count() == CellView.MAX_TOKENS, "a full NAD pool shows every carrier")

	# --- Language switching changes words only
	var digest: String = c.state_digest()
	main.switch_language()
	check(loc.code == "es" and main.lang_button.text == "English", "after switching, the button reads English")
	check(c.state_digest() == digest, "switching language in the ready state changes no scientific state")
	check(str(SkHost.announcements.back()["text"]) == "Idioma: español", "the switch is announced in the new language")
	check(_shown(main.transport.play_button) == "Iniciar" and _shown(main.transport.reset_button) == "Reiniciar", "SimKit's own buttons show Spanish")
	await frames(2)
	check(main.status.text.contains("Tiempo del cuerpo"), "the status line is Spanish")
	check(c.params.spec("food").label == "Fuente de alimento" and c.params.spec("food").choices[1] == "Harina de maíz desgerminada", "parameter names are Spanish")
	check(c.params.get_int("food") == 0, "and their values did not move")
	c.params.set_value("food", 1)
	c.session.start()
	await frames(30)
	check(c.session.is_running() and c.session.sim_time > 0.2, "the clock runs after Start")
	digest = c.state_digest()
	main.switch_language()
	check(c.state_digest() == digest and c.session.is_running(), "switching language mid-run changes nothing and does not pause")
	main.set_view("population")
	check(c.state_digest() == digest, "switching view mid-run changes nothing")
	main.switch_language()
	main.open_overlay("food")
	main.inspector.show_tab(1)
	main.open_overlay("evidence")
	main.open_overlay("help")
	main.close_overlay()
	check(c.state_digest() == digest and main.view_id == "population" and main.pop_view.visible, "opening and closing panels changes nothing and returns to the last view")
	c.session.pause()
	main.keep_snapshot("baseline")
	digest = c.state_digest()
	var label_es: String = main._snapshot_label("baseline")
	main.switch_language()
	check(c.state_digest() == digest and c.snapshots.has("baseline"), "a kept run survives a language switch unchanged")
	check(label_es.begins_with("Línea de base") and main._snapshot_label("baseline").begins_with("Baseline"), "its generated name follows the language")
	main.a11y.params.set_value("text_size", 2)
	main.a11y.params.set_value("high_contrast", true)
	await frames(3)
	check(c.state_digest() == digest, "text size and contrast change nothing in the model")
	main.a11y.params.set_value("text_size", 0)
	main.a11y.params.set_value("high_contrast", false)

	# --- No English left behind in Spanish, in every view and panel
	var english_only: Dictionary = {}
	var long_english: Array = []
	for key: String in loc.keys("en"):
		var en: String = loc.text_in("en", key)
		if en != loc.text_in("es", key):
			english_only[en] = key
			if en.length() >= 14 and not en.contains("{"):
				long_english.append(en)
	for literal: String in ["Start", "Pause", "Resume", "Step", "Reset", "Run again", "How to use it"]:
		english_only[literal] = "simkit"
	main.switch_language()
	for id: String in main.sections:
		main.sections[id].set_open(true)
	var left: Array = []
	for view: String in ["cell", "population"]:
		main.set_view(view)
		await frames(2)
		left.append_array(_english_left(main, english_only, long_english))
	main.open_overlay("food")
	await frames(2)
	left.append_array(_english_left(main, english_only, long_english))
	main.inspector.show_tab(1)
	await frames(2)
	left.append_array(_english_left(main, english_only, long_english))
	main.open_overlay("evidence")
	for page: int in range(main.evidence.page_count()):
		await frames(1)
		left.append_array(_english_left(main, english_only, long_english))
		main.evidence._turn(1)
	main.open_overlay("help")
	await frames(2)
	left.append_array(_english_left(main, english_only, long_english))
	main.close_overlay()
	check(left.is_empty(), "Spanish mode shows no leftover English (%s)" % str(left))
	check(loc.missing.is_empty(), "no translation key was missing while walking every screen (%s)" % str(loc.missing.keys()))
	check(main.cell_view.describe().contains("Célula") and main.pop_view.describe().contains("personas del modelo")
			and main.inspector.decomp.describe().contains("día") and main.evidence.describe().contains("histór"), "spoken summaries are Spanish")
	main.switch_language()
	check(loc.code == "en" and main.cell_view.describe().begins_with("Cell"), "and English again after switching back")

	# --- Keyboard: every control reachable, visible ones only, big enough, and out of the site's corner
	main.set_view("cell")
	await frames(3)
	var ring: Array[Control] = main.ring.current_ring()
	check(ring.size() > 25 and ring.has(main.lang_button), "the Tab ring holds the controls, including the language button (%d)" % ring.size())
	var reserved: Rect2 = Rect2(main.scaler.view_size.x - 200.0 / main.scaler.css_scale, 0.0, 200.0 / main.scaler.css_scale, 64.0 / main.scaler.css_scale)
	var in_corner: Array = []
	var too_small: Array = []
	var need: float = 44.0 / main.scaler.css_scale - 0.5
	for ctl: Control in ring:
		if ctl.get_global_rect().intersects(reserved):
			in_corner.append(ctl)
		if ctl.focus_mode == Control.FOCUS_NONE or ctl.size.y < need or ctl.size.x < need:
			too_small.append("%s %s" % [ctl.get_class(), ctl.size])
	check(in_corner.is_empty(), "no control sits in the site's top-right 200 x 64 CSS px")
	check(too_small.is_empty(), "every control is focusable and at least 44 CSS px each way (%s)" % str(too_small))
	root.gui_release_focus()
	_key(KEY_TAB)
	check(root.gui_get_focus_owner() == ring[0], "the first Tab focuses the first control")
	root.gui_release_focus()
	_key(KEY_TAB, true)
	check(root.gui_get_focus_owner() == ring[ring.size() - 1], "the first Shift+Tab focuses the last control")
	var leaves: int = SkHost.leave_count
	_key(KEY_TAB)
	check(SkHost.leave_count == leaves + 1 and root.gui_get_focus_owner() == null, "Tab past the last control leaves the game and releases focus")
	ring[0].grab_focus()
	_key(KEY_TAB, true)
	check(SkHost.leave_count == leaves + 2, "Shift+Tab before the first control leaves the game")
	main.open_buttons["help"].grab_focus()
	main.open_overlay("help")
	check(root.gui_get_focus_owner() == main.help.close_button, "opening a panel moves focus into it")
	_key(KEY_ESCAPE)
	check(main.overlay_id == "" and SkHost.leave_count == leaves + 2, "Escape closes the open panel and does not leave")
	check(root.gui_get_focus_owner() == main.open_buttons["help"], "focus returns to the button that opened it")
	_key(KEY_ESCAPE)
	check(SkHost.leave_count == leaves + 3, "Escape with nothing open leaves the game")
	main.lang_button.grab_focus()
	main.switch_language()
	check(root.gui_get_focus_owner() == main.lang_button, "the language button keeps focus through a switch")
	var food_buttons: Array[Control] = main.food_panel.focus_controls()
	food_buttons[2].grab_focus()
	main.switch_language()
	check(root.gui_get_focus_owner() == main.food_panel.focus_controls()[2], "focus stays on the same control when panels are rebuilt for the new language")

	# --- Diet controls: the processing step is shown whenever the food changes
	c.session.reset()
	c.params.set_value("food", 0)
	c.params.set_value("food", 1)
	await frames(2)
	check(main.proc_panel.visible and main.proc_panel.focus_controls().size() == 2
			and (main.proc_panel.focus_controls()[0] as Button).button_pressed, "degermed cornmeal shows its processing row with Unfortified selected")
	check(main._proc_caption.text.contains("degermed") and main._diet_now.text.contains("unfortified"), "the caption says the cornmeal is already degermed, and names the selection")
	check(main.mini_kernel.is_playing() and main.mini_kernel.shown_profile() == "degermed_unfortified", "the kernel animation plays the degerming step")
	check(str(SkHost.announcements.back()["text"]).contains("Degermed cornmeal, unfortified"), "the change is announced with the processing named")
	c.params.set_value("food", 2)
	await frames(2)
	check(not main.proc_panel.visible and main._proc_caption.text.contains("no single step"), "diverse foods offer no processing choice and say why")
	c.params.set_value("niacin", 40.0)
	await frames(2)
	check(main.niacin_button.visible and main._niacin_note.text.begins_with("Custom niacin"), "a custom niacin value is labelled and can be undone")
	main.niacin_button.pressed.emit()
	await frames(2)
	check(not main.niacin_button.visible and not c.niacin_custom, "the undo button returns to the food's niacin")

	# --- Motion: flux-driven when running, frozen when paused, a still frame with reduced motion
	c.params.set_value("food", 0)
	c.session.reset()
	c.session.start()
	await _until(c, 3.0)
	check(main.cell_view.mover_count() > 3, "while running, particles are in flight (%d)" % main.cell_view.mover_count())
	c.session.pause()
	var movers: int = main.cell_view.mover_count()
	var frozen: String = c.state_digest()
	await frames(20)
	check(main.cell_view.mover_count() == movers and c.state_digest() == frozen, "paused: the picture and the model both hold still")
	main.a11y.params.set_value("reduced_motion", true)
	var resumed_at: float = c.session.sim_time
	c.session.start()
	await _until(c, resumed_at + 1.5)
	check(main.cell_view.mover_count() == 0 and not main.cell_view.animating() and c.session.sim_time > resumed_at + 1.0, "reduced motion: the model runs, nothing flies")
	main.a11y.params.set_value("reduced_motion", false)
	c.session.pause()

	# --- A small frame still works
	root.size = Vector2i(1180, 360)
	await frames(4)
	var squashed: Array = []
	for ctl: Control in main.ring.current_ring():
		if ctl.size.x < 20.0 or ctl.size.y < 20.0:
			squashed.append(ctl)
	check(squashed.is_empty() and main._stage.size.y > 120.0 and not main._gauge_row.visible, "at 1180 x 360 the view keeps room and the gauges give way to the status line")
	check(main.status.text.contains("ATP"), "the status line still states the energy level in words")
	root.size = Vector2i(420, 700)
	await frames(4)
	check(main._split.is_narrow() and main._stage.size.y >= 200.0, "a phone-shaped frame stacks the view above the controls")
	root.size = Vector2i(1300, 550)
	await frames(2)
	main.queue_free()
	await frames(2)

	# --- Class settings from the page address
	var second: Control = await _boot("?view=population&food=degermed&processing=fortified&detail=advanced&particles=off&motion=reduced&prompts=on")
	check(second.view_id == "population" and second.pop_view.visible, "view=population opens the population view")
	check(second.controller.profile_id() == "degermed_fortified", "food and processing are applied together")
	check(second.sections["advanced"].is_open() and second.cell_view.detailed, "detail=advanced opens the advanced section")
	check(not second.cell_view.particles_enabled and second.a11y.reduced_motion(), "particles=off and motion=reduced are applied")
	check(second.lesson_panel != null and second.lesson_panel.focus_controls().size() >= 1, "prompts=on adds the optional prompts")
	check(second.controller.session.state == SkSession.State.READY and not second.mini_kernel.is_playing(), "class settings start nothing")
	check(second.loc.code == "en", "a new visit starts in English again: the language is not stored")
	second.switch_language()
	await frames(2)
	check(_shown(second.lesson_panel.toggle_button).contains("(ocultar)") and not _shown(second.lesson_panel.toggle_button).contains("Lesson"), "the prompts header is Spanish")
	var prompt_ok: bool = false
	for child: Node in second.lesson_panel.get_child(1).get_children():
		if child is Label and _shown(child).begins_with("Para conversar: ¿"):
			prompt_ok = true
	check(prompt_ok, "the prompts themselves are Spanish, including the part SimKit adds")
	second.queue_free()
	await frames(2)
	var third: Control = await _boot("?food=banana&processing=fortified&view=nowhere&junk=1&detail=")
	check(third.booted and third.controller.profile_id() == "whole_untreated" and third.view_id == "cell", "bad or mismatched class settings fall back to the defaults")
	check(third.lesson_panel == null, "prompts are off unless asked for")
	third.queue_free()
	SkHost.query_override = ""
	finish(62)
