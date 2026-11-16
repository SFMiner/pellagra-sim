extends SceneTree
## Saves a picture of the running game for a person to look at (overlap, clipping, text length).
## Needs a window, so it cannot run --headless:
##   godot --path . --script tests/shot.gd -- --out=C:/tmp/shot.png --size=1300x550 --do=es,degermed,start,wait4
## Steps for --do, in order: es (switch language), pop / cell (view), food / storage / evidence / help (open a panel),
## close, degermed / diverse / nixtamal / fortified (diet), active, month, start, pause, waitN (N seconds),
## large (text size), contrast, still (reduced motion), advanced (open the section), next (evidence page).
## Not part of the web build (tests/ is excluded from the export).


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out: String = "user://shot.png"
	var steps: PackedStringArray = PackedStringArray()
	var win: Vector2i = Vector2i(1300, 550)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--do="):
			steps = arg.substr(5).split(",", false)
		elif arg.begins_with("--size="):
			var wh: PackedStringArray = arg.substr(7).split("x")
			win = Vector2i(wh[0].to_int(), wh[1].to_int())
	root.size = win
	var main: Control = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i: int in range(6):
		await process_frame
	for step: String in steps:
		var p: SkParams = main.controller.params
		if step == "es":
			main.switch_language()
		elif step == "pop":
			main.set_view("population")
		elif step == "cell":
			main.set_view("cell")
		elif step == "food" or step == "evidence" or step == "help":
			main.open_overlay(step)
		elif step == "storage":
			main.open_overlay("food")
			main.inspector.show_tab(1)
		elif step == "close":
			main.close_overlay()
		elif step == "degermed":
			p.set_value("food", 1)
		elif step == "diverse":
			p.set_value("food", 2)
		elif step == "nixtamal":
			p.set_value("food", 0)
			p.set_value("proc_whole", 1)
		elif step == "fortified":
			p.set_value("food", 1)
			p.set_value("proc_degermed", 1)
		elif step == "active":
			p.set_value("workload", 1)
		elif step == "month":
			p.set_value("lapse", 3)
		elif step == "start":
			main.controller.session.start()
		elif step == "dstart":
			main.controller.decomp_session.start()
		elif step == "pause":
			main.controller.session.pause()
		elif step == "large":
			main.a11y.persist = false
			main.a11y.params.set_value("text_size", 1)
		elif step == "contrast":
			main.a11y.persist = false
			main.a11y.params.set_value("high_contrast", true)
		elif step == "still":
			main.a11y.persist = false
			main.a11y.params.set_value("reduced_motion", true)
		elif step == "advanced":
			main.sections["advanced"].set_open(true)
		elif step == "next":
			main.evidence._turn(1)
		elif step.begins_with("wait"):
			var until: int = Time.get_ticks_msec() + int(step.substr(4).to_float() * 1000.0)
			while Time.get_ticks_msec() < until:
				await process_frame
		for i: int in range(3):
			await process_frame
	for i: int in range(4):
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("shot saved: ", out)
	quit()
