extends SceneTree
## Headless test runner:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits 1 if any test fails. CI also fails on any "SCRIPT ERROR" in the log,
## because a runtime error inside a test doesn't raise here.

const TEST_FILES := [
	"res://tests/test_save_schema.gd",
	"res://tests/test_build_info.gd",
]


func _init() -> void:
	var passed := 0
	var failed := 0
	for path in TEST_FILES:
		var script: Script = load(path)
		if script == null:
			printerr("FAIL  could not load %s" % path)
			failed += 1
			continue
		var suite = script.new()
		print("%s" % path)
		for method in suite.get_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			suite.reset()
			suite.call(name)
			if suite.failures.is_empty():
				passed += 1
				print("  ok    %s" % name)
			else:
				failed += 1
				for f in suite.failures:
					printerr("  FAIL  %s: %s" % [name, f])
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 or passed == 0 else 0)
