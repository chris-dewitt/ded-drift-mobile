extends "res://tests/test_case.gd"

const SaveSchema := preload("res://game/core/save_schema.gd")


func test_round_trip() -> void:
	var meta := {"debt": 1234, "clones": 3, "chapters_completed": 2}
	var result := SaveSchema.parse(SaveSchema.to_json(meta))
	assert_true(result.ok, "valid save parses")
	assert_eq(result.meta, meta, "round trip")


func test_malformed_json_falls_back() -> void:
	var result := SaveSchema.parse("{not json")
	assert_false(result.ok, "malformed rejected")
	assert_eq(result.meta, SaveSchema.default_meta(), "defaults on failure")


func test_non_object_root_rejected() -> void:
	assert_false(SaveSchema.parse("[1,2,3]").ok, "array root")
	assert_false(SaveSchema.parse("\"hi\"").ok, "string root")


func test_wrong_schema_version_rejected() -> void:
	assert_false(SaveSchema.parse('{"schema_version": 99, "meta": {}}').ok, "future version")
	assert_false(SaveSchema.parse('{"schema_version": "1", "meta": {}}').ok, "string version")


func test_oversized_rejected() -> void:
	var huge := '{"schema_version":1,"meta":{"pad":"%s"}}' % "x".repeat(SaveSchema.MAX_SAVE_BYTES)
	var result := SaveSchema.parse(huge)
	assert_false(result.ok, "oversized")
	assert_eq(result.error, "save too large")


func test_values_clamped_and_coerced() -> void:
	var text := '{"schema_version":1,"meta":{"debt":-50,"clones":1e300,"chapters_completed":99.7}}'
	var result := SaveSchema.parse(text)
	assert_true(result.ok)
	assert_eq(result.meta.debt, 0, "negative debt clamps to 0")
	assert_eq(result.meta.clones, 100_000, "huge clones clamps to max")
	assert_eq(result.meta.chapters_completed, 6, "chapters clamps to 6")


func test_wrong_types_use_defaults() -> void:
	var text := '{"schema_version":1,"meta":{"debt":"lots","clones":null,"chapters_completed":[1]}}'
	var result := SaveSchema.parse(text)
	assert_true(result.ok)
	assert_eq(result.meta, SaveSchema.default_meta(), "bad types -> defaults")


func test_unknown_keys_dropped() -> void:
	var text := '{"schema_version":1,"meta":{"debt":5,"god_mode":true,"__proto__":{}}}'
	var result := SaveSchema.parse(text)
	assert_true(result.ok)
	assert_false(result.meta.has("god_mode"), "unknown key dropped")
	assert_false(result.meta.has("__proto__"), "unknown key dropped")
	assert_eq(result.meta.debt, 5)
