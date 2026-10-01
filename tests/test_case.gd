class_name TestCase
extends RefCounted
## Base class for tests. Every method whose name starts with "test_" runs on a
## fresh instance. See tests/run_tests.gd.

var failures: Array[String] = []
var assertions := 0


func assert_true(condition: bool, message: String = "") -> void:
	assertions += 1
	if not condition:
		failures.append(message if message else "expected true")


func assert_false(condition: bool, message: String = "") -> void:
	assert_true(not condition, message if message else "expected false")


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertions += 1
	if not _same(actual, expected):
		failures.append("%sexpected %s, got %s" % [_prefix(message), var_to_str(expected), var_to_str(actual)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	assertions += 1
	if _same(actual, unexpected):
		failures.append("%sdid not expect %s" % [_prefix(message), var_to_str(actual)])


func assert_almost(actual: float, expected: float, epsilon: float = 0.001, message: String = "") -> void:
	assertions += 1
	if absf(actual - expected) > epsilon:
		failures.append("%sexpected %s ± %s, got %s" % [_prefix(message), expected, epsilon, actual])


func assert_ok(result: Dictionary, message: String = "") -> void:
	assertions += 1
	if not result.get("ok", false):
		failures.append("%sexpected ok, got error '%s'" % [_prefix(message), result.get("error", "?")])


func assert_error(result: Dictionary, error: String, message: String = "") -> void:
	assertions += 1
	if result.get("ok", false) or result.get("error", "") != error:
		failures.append("%sexpected error '%s', got %s" % [_prefix(message), error, result])


func assert_empty(list: Variant, message: String = "") -> void:
	assertions += 1
	if not list.is_empty():
		failures.append("%sexpected empty, got %s" % [_prefix(message), list])


func fail(message: String) -> void:
	assertions += 1
	failures.append(message)


func _same(a: Variant, b: Variant) -> bool:
	# Numbers from JSON are floats; compare ints and floats by value.
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


func _prefix(message: String) -> String:
	return message + ": " if message else ""
