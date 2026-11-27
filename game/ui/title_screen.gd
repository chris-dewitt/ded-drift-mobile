extends Node2D
## Title screen. Tap anywhere to launch a run (or continue from the sector
## you died on). Tap the version label for the debug panel. Everything is
## drawn in code: no imported assets yet.

const BuildInfo := preload("res://game/core/build_info.gd")
const Screen := preload("res://game/ui/screen.gd")
const Fmt := preload("res://game/core/fmt.gd")
const FLIGHT_SCENE := "res://game/flight/flight.tscn"
const Backdrop := preload("res://game/flight/backdrop.gd")
const CrtOverlay := preload("res://game/ui/crt_overlay.gd")

const BG := Color(0.02, 0.025, 0.035)
const AMBER := Color(1.0, 0.70, 0.28)
const CYAN := Color(0.25, 0.88, 0.82)
const DIM := Color(0.55, 0.60, 0.65)
const RED_FRINGE := Color(1.0, 0.2, 0.25, 0.45)
const CYAN_FRINGE := Color(0.2, 0.9, 1.0, 0.45)

const STAR_COUNT := 160
const TAP_RING_LIFE := 0.6

var _font: Font
var _stars: Array[Vector3] = []  # x, y in 0..1; z = depth 0.2..1
var _time := 0.0
var _taps: Array = []  # each: [Vector2 pos, float age]
var _launching := false
var _backdrop := {}
var _show_debug := false
var _version_rect := Rect2()
var _ship_pos := Vector2.ZERO
var _ship_vel := Vector2(22.0, -7.0)
var _ship_rot := -0.3
var _crt_rect := Rect2()
var _sound_rect := Rect2()
var _crash_rect := Rect2()


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_backdrop = Backdrop.generate(1, Rect2(0, 0, 3600, 2100))
	add_child(CrtOverlay.new())
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.set_mood("title")
		audio.set_thrust(false)
		audio.set_hull(100.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404  # Local 404. Same sky every launch.
	for _i in STAR_COUNT:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.2, 1.0)))
	_ship_pos = _view().size * Vector2(0.22, 0.70)


func _view() -> Rect2:
	return get_viewport_rect()


func _safe_rect() -> Rect2:
	return Screen.safe_rect(get_viewport())


func _process(delta: float) -> void:
	_time += delta
	var size := _view().size
	_ship_pos += _ship_vel * delta
	_ship_pos.x = fposmod(_ship_pos.x, size.x)
	_ship_pos.y = fposmod(_ship_pos.y, size.y)
	_ship_rot += 0.12 * delta
	for tap in _taps:
		tap[1] += delta
	_taps = _taps.filter(func(t): return t[1] < TAP_RING_LIFE)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	var pos := touch.position
	_taps.append([pos, 0.0])
	var settings := get_node_or_null("/root/Settings")
	if settings != null and _crt_rect.has_point(pos):
		settings.set_crt(not settings.crt)
		get_tree().reload_current_scene()  # rebuild with / without the CRT pass
	elif settings != null and _sound_rect.has_point(pos):
		settings.set_sound(not settings.sound)
		var audio := get_node_or_null("/root/Audio")
		if audio != null and settings.sound:
			audio.start_render()
	elif settings != null and settings.last_session_crashed:
		settings.dismiss_crash()  # first tap just dismisses the crash report
	elif _version_rect.grow(24.0).has_point(pos):
		_show_debug = not _show_debug
	elif not _launching:
		_launching = true
		var audio := get_node_or_null("/root/Audio")
		if audio != null:
			audio.play("warp", -4.0)
		var run := get_node("/root/RunState")
		run.start_run()
		get_tree().change_scene_to_file(FLIGHT_SCENE)


func _draw() -> void:
	var view := _view()
	var safe := _safe_rect()
	draw_rect(view, BG)
	_draw_stars(view)
	# Slow drift through the corporate skyline behind the logo.
	var centre := Vector2(900.0 + _time * 18.0, 700.0 + sin(_time * 0.1) * 120.0)
	draw_set_transform(view.size * 0.5 - centre)
	Backdrop.draw(self, _backdrop, centre, view.size, _time, _font)
	draw_set_transform(Vector2.ZERO)
	_draw_ship(_ship_pos, _ship_rot)
	_draw_title(safe)
	_draw_prompt(safe)
	_draw_taps()
	_draw_status(safe)
	_draw_version(safe)
	_draw_toggles(safe)
	if _show_debug:
		_draw_debug(view, safe)
	_draw_crash_report(safe)
	_draw_scanlines(view)


func _draw_stars(view: Rect2) -> void:
	for s in _stars:
		var x := fposmod(s.x * view.size.x - _time * 14.0 * s.z, view.size.x)
		var y := s.y * view.size.y
		var c := Color(0.75, 0.82, 0.9, 0.25 + 0.6 * s.z)
		draw_rect(Rect2(x, y, 1.0 + s.z * 1.6, 1.0 + s.z * 1.6), c)


func _draw_ship(pos: Vector2, rot: float) -> void:
	var xf := Transform2D(rot, pos)
	var hull := PackedVector2Array([
		Vector2(26, 0), Vector2(-14, -15), Vector2(-6, 0), Vector2(-14, 15), Vector2(26, 0)])
	draw_polyline(xf * hull, AMBER, 2.0, true)
	var flame := 6.0 + 4.0 * sin(_time * 31.0)
	var exhaust := PackedVector2Array([
		Vector2(-10, -5), Vector2(-10 - flame, 0), Vector2(-10, 5)])
	draw_polyline(xf * exhaust, CYAN, 1.5, true)


func _draw_title(safe: Rect2) -> void:
	var size := 104
	var y := safe.position.y + safe.size.y * 0.40
	var x := safe.position.x
	var w := safe.size.x
	var jitter := 2.0 + 1.5 * sin(_time * 2.3)
	draw_string(_font, Vector2(x - jitter, y), "DED DRIFT", HORIZONTAL_ALIGNMENT_CENTER, w, size, RED_FRINGE)
	draw_string(_font, Vector2(x + jitter, y), "DED DRIFT", HORIZONTAL_ALIGNMENT_CENTER, w, size, CYAN_FRINGE)
	draw_string(_font, Vector2(x, y), "DED DRIFT", HORIZONTAL_ALIGNMENT_CENTER, w, size, AMBER)
	draw_string(_font, Vector2(x, y + 52), "5 sectors. crushing debt. one rusted ship.",
		HORIZONTAL_ALIGNMENT_CENTER, w, 26, DIM)


func _draw_prompt(safe: Rect2) -> void:
	var alpha := 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 3.0))
	var y := safe.position.y + safe.size.y * 0.74
	var run := get_node_or_null("/root/RunState")
	var sector: int = run.sector if run != null else 1
	var prompt := "TAP TO LAUNCH" if sector <= 1 else "TAP TO CONTINUE · SECTOR %d" % sector
	draw_string(_font, Vector2(safe.position.x, y), prompt,
		HORIZONTAL_ALIGNMENT_CENTER, safe.size.x, 34, Color(CYAN, alpha))


func _draw_taps() -> void:
	for tap in _taps:
		var t: float = tap[1] / TAP_RING_LIFE
		draw_arc(tap[0], 18.0 + 46.0 * t, 0.0, TAU, 40, Color(CYAN, 1.0 - t), 2.0, true)


func _draw_status(safe: Rect2) -> void:
	var run := get_node_or_null("/root/RunState")
	if run == null:
		return
	var meta: Dictionary = run.meta
	var line := "DEBT %s CR  ·  CLONES %d  ·  CHAPTERS %d/6" % [
		Fmt.cr(int(meta["debt"])), int(meta["clones"]), int(meta["chapters_completed"])]
	draw_string(_font, Vector2(safe.position.x, safe.position.y + safe.size.y * 0.84), line,
		HORIZONTAL_ALIGNMENT_CENTER, safe.size.x, 20, DIM)


func _draw_version(safe: Rect2) -> void:
	var text := BuildInfo.label()
	var fs := 18
	var size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(safe.position.x + 16.0, safe.end.y - 16.0)
	_version_rect = Rect2(pos.x, pos.y - size.y, size.x, size.y)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, DIM)


func _draw_debug(view: Rect2, safe: Rect2) -> void:
	draw_rect(safe, Color(CYAN, 0.8), false, 2.0)
	var lines := [
		"BUILD   %s" % BuildInfo.full_label(),
		"FPS     %d" % Engine.get_frames_per_second(),
		"REFRESH %.0f Hz" % DisplayServer.screen_get_refresh_rate(),
		"WINDOW  %s" % str(DisplayServer.window_get_size()),
		"VIEW    %d x %d" % [int(view.size.x), int(view.size.y)],
		"SAFE    %s" % str(DisplayServer.get_display_safe_area()),
		"DEVICE  %s · %s" % [OS.get_model_name(), OS.get_name()],
		"RENDER  %s" % RenderingServer.get_video_adapter_name(),
	]
	var box := Rect2(safe.end.x - 520.0, safe.position.y + 16.0, 504.0, 24.0 * lines.size() + 20.0)
	draw_rect(box, Color(0, 0, 0, 0.8))
	draw_rect(box, CYAN, false, 1.0)
	for i in lines.size():
		draw_string(_font, box.position + Vector2(12, 30 + 24 * i), lines[i],
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 24.0, 16, CYAN)


func _draw_scanlines(view: Rect2) -> void:
	var y := 0.0
	while y < view.size.y:
		draw_line(Vector2(0, y), Vector2(view.size.x, y), Color(0, 0, 0, 0.18), 1.0)
		y += 3.0


## Safe-mode toggles, top-right. Big enough for a thumb.
func _draw_toggles(safe: Rect2) -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return
	_sound_rect = Rect2(safe.end.x - 190.0, safe.position.y + 14.0, 176.0, 52.0)
	_crt_rect = Rect2(safe.end.x - 380.0, safe.position.y + 14.0, 176.0, 52.0)
	for pair in [[_crt_rect, "CRT", settings.crt], [_sound_rect, "SOUND", settings.sound]]:
		var r: Rect2 = pair[0]
		var on: bool = pair[2]
		var col := CYAN if on else DIM
		draw_rect(r, Color(0, 0, 0, 0.6))
		draw_rect(r, col, false, 2.0)
		draw_string(_font, Vector2(r.position.x, r.position.y + 34.0), "%s: %s" % [pair[1], "ON" if on else "OFF"],
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, col)


## Shown once after a session that didn't close cleanly.
func _draw_crash_report(safe: Rect2) -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null or not settings.last_session_crashed:
		return
	var lines: Array = ["Last session crashed. Screenshot this for Claude, then tap to dismiss.",
		"Try switching CRT or SOUND off (top right) to narrow it down.", ""]
	for l in settings.last_log_tail:
		lines.append(l)
	if settings.last_log_tail.is_empty():
		lines.append("(no log from the last session)")
	var box := Rect2(safe.position.x + 40.0, safe.position.y + 80.0, safe.size.x - 80.0, 30.0 + 21.0 * lines.size())
	_crash_rect = box
	draw_rect(box, Color(0.08, 0.0, 0.0, 0.92))
	draw_rect(box, Color(1.0, 0.3, 0.26), false, 2.0)
	for i in lines.size():
		draw_string(_font, Vector2(box.position.x + 14.0, box.position.y + 24.0 + 21.0 * i), String(lines[i]),
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 28.0, 14 if i > 2 else 17,
			Color(1.0, 0.75, 0.7) if i > 2 else Color(1.0, 0.4, 0.35))

