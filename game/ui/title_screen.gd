extends Node2D
## M.0 title screen. Proves the build installs, runs landscape, takes touch,
## respects the safe area (punch-hole / rounded corners), and reports which
## build it is. Everything is drawn in code: no imported assets yet.

const BuildInfo := preload("res://game/core/build_info.gd")

const BG := Color(0.02, 0.025, 0.035)
const AMBER := Color(1.0, 0.70, 0.28)
const CYAN := Color(0.25, 0.88, 0.82)
const DIM := Color(0.55, 0.60, 0.65)
const RED_FRINGE := Color(1.0, 0.2, 0.25, 0.45)
const CYAN_FRINGE := Color(0.2, 0.9, 1.0, 0.45)

const STAR_COUNT := 160
const TAP_RING_LIFE := 0.6
const TOAST_LIFE := 3.5

const BAX_LINES := [
	"Oi. Nothin' past this screen yet, guv. Chris is still boltin' the engine on.",
	"Tap all you like, the flight module's in a crate somewhere. M.1, they reckon.",
	"You're keen. I respect keen. Keen don't make engines appear, mind.",
]

var _font: Font
var _stars: Array[Vector3] = []  # x, y in 0..1; z = depth 0.2..1
var _time := 0.0
var _taps: Array = []  # each: [Vector2 pos, float age]
var _toast := ""
var _toast_age := TOAST_LIFE
var _bax_index := 0
var _show_debug := false
var _version_rect := Rect2()
var _ship_pos := Vector2.ZERO
var _ship_vel := Vector2(22.0, -7.0)
var _ship_rot := -0.3


func _ready() -> void:
	_font = ThemeDB.fallback_font
	var rng := RandomNumberGenerator.new()
	rng.seed = 404  # Local 404. Same sky every launch.
	for _i in STAR_COUNT:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.2, 1.0)))
	_ship_pos = _view().size * Vector2(0.22, 0.70)


func _view() -> Rect2:
	return get_viewport_rect()


## Safe area in viewport (canvas) coordinates.
func _safe_rect() -> Rect2:
	var view := _view()
	var screen_safe := Rect2(DisplayServer.get_display_safe_area())
	if screen_safe.size.x <= 0.0 or screen_safe.size.y <= 0.0:
		return view
	var to_canvas := get_viewport().get_final_transform().affine_inverse()
	var safe: Rect2 = to_canvas * screen_safe
	var clipped := safe.intersection(view)
	return clipped if clipped.has_area() else view


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
	_toast_age += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	var pos := touch.position
	_taps.append([pos, 0.0])
	if _version_rect.grow(24.0).has_point(pos):
		_show_debug = not _show_debug
	else:
		_toast = BAX_LINES[_bax_index % BAX_LINES.size()]
		_bax_index += 1
		_toast_age = 0.0


func _draw() -> void:
	var view := _view()
	var safe := _safe_rect()
	draw_rect(view, BG)
	_draw_stars(view)
	_draw_ship(_ship_pos, _ship_rot)
	_draw_title(safe)
	_draw_prompt(safe)
	_draw_taps()
	_draw_toast(safe)
	_draw_version(safe)
	if _show_debug:
		_draw_debug(view, safe)
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
	draw_string(_font, Vector2(x - jitter, y), "DEAD DRIFT", HORIZONTAL_ALIGNMENT_CENTER, w, size, RED_FRINGE)
	draw_string(_font, Vector2(x + jitter, y), "DEAD DRIFT", HORIZONTAL_ALIGNMENT_CENTER, w, size, CYAN_FRINGE)
	draw_string(_font, Vector2(x, y), "DEAD DRIFT", HORIZONTAL_ALIGNMENT_CENTER, w, size, AMBER)
	draw_string(_font, Vector2(x, y + 52), "5 sectors. crushing debt. one rusted ship.",
		HORIZONTAL_ALIGNMENT_CENTER, w, 26, DIM)


func _draw_prompt(safe: Rect2) -> void:
	var alpha := 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 3.0))
	var y := safe.position.y + safe.size.y * 0.74
	draw_string(_font, Vector2(safe.position.x, y), "TAP TO START",
		HORIZONTAL_ALIGNMENT_CENTER, safe.size.x, 34, Color(CYAN, alpha))


func _draw_taps() -> void:
	for tap in _taps:
		var t: float = tap[1] / TAP_RING_LIFE
		draw_arc(tap[0], 18.0 + 46.0 * t, 0.0, TAU, 40, Color(CYAN, 1.0 - t), 2.0, true)


func _draw_toast(safe: Rect2) -> void:
	if _toast_age >= TOAST_LIFE or _toast.is_empty():
		return
	var alpha := clampf((TOAST_LIFE - _toast_age) / 0.4, 0.0, 1.0)
	var w := minf(safe.size.x - 48.0, 980.0)
	var box := Rect2(safe.position.x + (safe.size.x - w) * 0.5, safe.position.y + 20.0, w, 64.0)
	draw_rect(box, Color(0.0, 0.0, 0.0, 0.75 * alpha))
	draw_rect(box, Color(AMBER, alpha), false, 2.0)
	draw_string(_font, box.position + Vector2(18, 26), "BAX", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(AMBER, alpha))
	draw_string(_font, box.position + Vector2(18, 50), _toast, HORIZONTAL_ALIGNMENT_LEFT, w - 36.0, 20, Color(1, 1, 1, alpha))


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
