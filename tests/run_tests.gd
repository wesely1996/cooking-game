extends SceneTree
## Headless test runner. Runs every test_* method of every script in
## res://tests/unit, each on a fresh instance.
##
##   godot --headless --path . --script res://tests/run_tests.gd [-- <filter>]
##
## The optional filter only runs tests whose "file::method" name contains it.
## Use tools/run_tests.sh, which also fails on logged script errors.

const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		filter = args[0]
	var passed := 0
	var failed: Array[String] = []
	for path in DataFiles.list_files(TEST_DIR, ".gd"):
		var script: GDScript = load(path)
		if script == null:
			failed.append("%s: could not load" % path)
			continue
		for method in script.get_script_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			var full_name := "%s::%s" % [path.get_file().get_basename(), test_name]
			if filter and not full_name.contains(filter):
				continue
			var test: TestCase = script.new()
			test.call(test_name)
			if test.assertions == 0:
				test.failures.append("no assertions ran (did the test crash?)")
			if test.failures.is_empty():
				passed += 1
				print("  ok    ", full_name)
			else:
				failed.append(full_name)
				print("  FAIL  ", full_name)
				for failure in test.failures:
					print("          ", failure)
	print("")
	print("%d passed, %d failed" % [passed, failed.size()])
	quit(1 if not failed.is_empty() or passed == 0 else 0)
