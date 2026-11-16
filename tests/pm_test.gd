extends SceneTree
## Base for this project's headless tests (the same pattern as SimKit's own tests/sk_test.gd).
## A test extends this, overrides run(), calls check() and ends with finish(<exact number of checks>):
## a test that stops early cannot pass, because the count is compared.
## Run:  godot --headless --path . --script tests/test_xxx.gd

var passed: int = 0
var failures: int = 0
var test_name: String = "test"


func _initialize() -> void:
	call_deferred("_run_wrapper")


func _run_wrapper() -> void:
	await run()


func run() -> void:
	finish(0)


func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		print("  FAIL: " + label)


func approx(a: float, b: float, tolerance: float = 1e-6) -> bool:
	return absf(a - b) <= tolerance


func finish(expected_total: int) -> void:
	var total: int = passed + failures
	var ok: bool = failures == 0 and total == expected_total
	print("%s: %d/%d passed (expected %d checks) -> %s" % [test_name, passed, total, expected_total,
			"PASS" if ok else "FAIL"])
	quit(0 if ok else 1)


func frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


## A controller with its own data, driven by hand (no frames needed).
func make_controller() -> SimController:
	var data: SimData = SimData.new()
	data.load_all()
	var c: SimController = SimController.new()
	root.add_child(c)
	c.setup(data)
	c.session.auto_process = false
	c.decomp_session.auto_process = false
	return c


## Runs the main clock for `seconds` of cell time (it must be started).
func run_main(c: SimController, seconds: float) -> void:
	for i: int in range(int(round(seconds * 10.0))):
		c.session.advance(0.1)
