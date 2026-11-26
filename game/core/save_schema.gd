extends RefCounted
## Validates save files. Saves are untrusted input (they can be edited or
## corrupted), so we parse JSON only, check every field, clamp numbers, and
## drop unknown keys. A bad save never crashes the game; the caller gets
## ok=false and loads a fresh state.

const SCHEMA_VERSION := 1
const MAX_SAVE_BYTES := 256 * 1024

## field -> [min, max, default]. All meta fields are integers.
const META_FIELDS := {
	"debt": [0, 1_000_000_000, 250_000],
	"clones": [0, 100_000, 0],
	"chapters_completed": [0, 6, 0],
}


static func default_meta() -> Dictionary:
	var meta := {}
	for key in META_FIELDS:
		meta[key] = META_FIELDS[key][2]
	return meta


static func to_json(meta: Dictionary) -> String:
	var out := {"schema_version": SCHEMA_VERSION, "meta": sanitize_meta(meta)}
	return JSON.stringify(out)


## Returns {"ok": bool, "meta": Dictionary, "error": String}.
## On failure, meta is default_meta().
static func parse(text: String) -> Dictionary:
	if text.length() > MAX_SAVE_BYTES:
		return _fail("save too large")
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail("malformed json")
	var root = json.data
	if typeof(root) != TYPE_DICTIONARY:
		return _fail("root is not an object")
	var version = root.get("schema_version")
	if not _is_number(version) or int(version) != SCHEMA_VERSION:
		return _fail("unsupported schema_version")
	var meta = root.get("meta")
	if typeof(meta) != TYPE_DICTIONARY:
		return _fail("meta is not an object")
	return {"ok": true, "meta": sanitize_meta(meta), "error": ""}


## Keeps only known fields, coerces to int, clamps to range. Non-numeric or
## non-finite values fall back to the field default.
static func sanitize_meta(meta: Dictionary) -> Dictionary:
	var clean := {}
	for key in META_FIELDS:
		var spec: Array = META_FIELDS[key]
		var value = meta.get(key, spec[2])
		if not _is_number(value) or not is_finite(float(value)):
			value = spec[2]
		# Clamp as float first: int() of a huge float overflows.
		clean[key] = int(clampf(float(value), spec[0], spec[1]))
	return clean


static func _is_number(value) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "meta": default_meta(), "error": reason}
