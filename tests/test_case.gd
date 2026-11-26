extends RefCounted
## Minimal assertion base for the headless runner. No third-party addon.

var failures: Array[String] = []


func reset() -> void:
	failures.clear()


func assert_true(cond: bool, msg := "expected true") -> void:
	if not cond:
		failures.append(msg)


func assert_false(cond: bool, msg := "expected false") -> void:
	assert_true(not cond, msg)


func assert_eq(actual, expected, msg := "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s expected <%s> got <%s>" % [msg, str(expected), str(actual)])
