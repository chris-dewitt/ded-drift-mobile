extends Control
## Two-thumb touch controls for flight (multi-touch).
##   Left half: floating AIM stick (touch down anywhere, drag to point the ship).
##   Right side: THRUST (big), RETRO, FIRE, JUMP (only when the gate is open).
##   Top-right: PAUSE.
## A touch keeps the role it started with until it lifts, so sliding a thumb
## off THRUST never fires something else. Keyboard fallback for desktop:
## WASD/arrows aim, Space thrust, Shift retro, F fire, Enter jump, Esc pause.

const Screen := preload("res://game/ui/screen.gd")

const STICK_RADIUS := 90.0
const HIT_SLOP := 1.3  # buttons accept touches a bit outside their circle

const CYAN := Color(0.25, 0.88, 0.82)
const AMBER := Color(1.0, 0.70, 0.28)
const WHITE := Color(1, 1, 1)

var flight  # the flight scene (untyped to avoid a preload cycle)

## Test hooks: the smoke test drives these instead of synthetic touches.
var debug_aim := Vector2.ZERO
var debug_thrust := false
var debug_fire := false

var _touches := {}  # index -> {"role": String, "start": Vector2, "pos": Vector2}
var _jump := false
var _pause := false
var _tap := false
var _tap_pos := Vector2.ZERO
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func layout() -> Dictionary:
	var s := Screen.safe_rect(get_viewport())
	return {
		"thrust": [Vector2(s.end.x - 120.0, s.end.y - 115.0), 74.0],
		"retro": [Vector2(s.end.x - 278.0, s.end.y - 72.0), 50.0],
		"fire": [Vector2(s.end.x - 110.0, s.end.y - 292.0), 56.0],
		"jump": [Vector2(s.end.x - 292.0, s.end.y - 248.0), 62.0],
		"pause": Rect2(s.end.x - 96.0, s.position.y + 8.0, 84.0, 52.0),
		"stick_zone": Rect2(s.position.x, s.position.y + 150.0, s.size.x * 0.5, s.size.y - 150.0),
		"stick_hint": Vector2(s.position.x + 170.0, s.end.y - 150.0),
	}


# --- input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_press(t.index, t.position)
		else:
			_touches.erase(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touches.has(d.index):
			var info: Dictionary = _touches[d.index]
			info["pos"] = d.position
			if info["role"] == "stick":
				# Floating stick: the base follows a thumb that drags past the rim.
				var start: Vector2 = info["start"]
				var off := d.position - start
				if off.length() > STICK_RADIUS:
					info["start"] = d.position - off.normalized() * STICK_RADIUS
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_jump = true
				inject_tap(Vector2.ZERO)
			KEY_ESCAPE, KEY_P:
				_pause = true


func _press(index: int, pos: Vector2) -> void:
	_tap = true
	_tap_pos = pos
	var role := "none"
	var lay := layout()
	var pause_rect: Rect2 = lay["pause"]
	var stick_zone: Rect2 = lay["stick_zone"]
	if flight != null and flight.can_pause() and pause_rect.grow(12.0).has_point(pos):
		role = "pause"
		_pause = true
	elif flight != null and flight.is_playing():
		if flight.jump_ready and _hit(lay["jump"], pos):
			role = "jump"
			_jump = true
		elif _hit(lay["thrust"], pos):
			role = "thrust"
		elif _hit(lay["retro"], pos):
			role = "retro"
		elif _hit(lay["fire"], pos):
			role = "fire"
		elif stick_zone.has_point(pos):
			role = "stick"
	_touches[index] = {"role": role, "start": pos, "pos": pos}


func _hit(spec: Array, pos: Vector2) -> bool:
	var centre: Vector2 = spec[0]
	var radius: float = spec[1]
	return pos.distance_to(centre) < radius * HIT_SLOP


func _role_held(role: String) -> bool:
	for info in _touches.values():
		if info["role"] == role:
			return true
	return false


# --- state the flight scene reads ------------------------------------------

func aim_vector() -> Vector2:
	if debug_aim != Vector2.ZERO:
		return debug_aim
	for info in _touches.values():
		if info["role"] == "stick":
			var off: Vector2 = info["pos"] - info["start"]
			return (off / STICK_RADIUS).limit_length(1.0)
	return _keyboard_aim()


func thrust_held() -> bool:
	return debug_thrust or _role_held("thrust") or Input.is_physical_key_pressed(KEY_SPACE)


func retro_held() -> bool:
	return _role_held("retro") or Input.is_physical_key_pressed(KEY_SHIFT)


func fire_held() -> bool:
	return debug_fire or _role_held("fire") or Input.is_physical_key_pressed(KEY_F)


func consume_jump() -> bool:
	var j := _jump
	_jump = false
	return j


func consume_pause() -> bool:
	var p := _pause
	_pause = false
	return p


func consume_tap() -> bool:
	var t := _tap
	_tap = false
	return t


func tap_position() -> Vector2:
	return _tap_pos


func clear_taps() -> void:
	_tap = false
	_jump = false
	_pause = false


## Test / keyboard hooks.
func inject_tap(pos: Vector2) -> void:
	_tap = true
	_tap_pos = pos


func press_jump_for_test() -> void:
	_jump = true


func press_pause_for_test() -> void:
	_pause = true


func _keyboard_aim() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v.normalized()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if flight == null:
		return
	var lay := layout()
	if flight.can_pause():
		var pr: Rect2 = lay["pause"]
		draw_rect(pr, Color(0, 0, 0, 0.45))
		draw_rect(pr, Color(CYAN, 0.8), false, 2.0)
		draw_rect(Rect2(pr.get_center() + Vector2(-11, -12), Vector2(7, 24)), CYAN)
		draw_rect(Rect2(pr.get_center() + Vector2(4, -12), Vector2(7, 24)), CYAN)
	if not flight.is_playing():
		return
	_draw_stick(lay)
	_draw_button(lay["thrust"], "THRUST", _role_held("thrust"), CYAN, "")
	_draw_button(lay["retro"], "RETRO", _role_held("retro"), CYAN, "")
	_draw_button(lay["fire"], "FIRE", _role_held("fire"), AMBER, "auto")
	if flight.jump_ready:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 130.0)
		_draw_button(lay["jump"], "JUMP", _role_held("jump"), Color(CYAN, 0.6 + 0.4 * pulse), "")


func _draw_stick(lay: Dictionary) -> void:
	for info in _touches.values():
		if info["role"] == "stick":
			var start: Vector2 = info["start"]
			var pos: Vector2 = info["pos"]
			var knob := start + (pos - start).limit_length(STICK_RADIUS)
			draw_arc(start, STICK_RADIUS, 0.0, TAU, 48, Color(CYAN, 0.55), 2.0, true)
			draw_circle(knob, 36.0, Color(CYAN, 0.25))
			draw_arc(knob, 36.0, 0.0, TAU, 32, CYAN, 2.0, true)
			return
	var hint: Vector2 = lay["stick_hint"]
	draw_arc(hint, STICK_RADIUS, 0.0, TAU, 48, Color(CYAN, 0.18), 2.0, true)
	draw_string(_font, hint + Vector2(-STICK_RADIUS, 7), "AIM", HORIZONTAL_ALIGNMENT_CENTER,
		STICK_RADIUS * 2.0, 20, Color(CYAN, 0.35))


func _draw_button(spec: Array, label: String, held: bool, color: Color, sub: String) -> void:
	var centre: Vector2 = spec[0]
	var radius: float = spec[1]
	draw_circle(centre, radius, Color(color, 0.32 if held else 0.10))
	draw_arc(centre, radius, 0.0, TAU, 48, color, 3.0 if held else 2.0, true)
	draw_string(_font, centre + Vector2(-radius, 7), label, HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2.0, 20, WHITE if held else color)
	if sub != "":
		draw_string(_font, centre + Vector2(-radius, 27), sub, HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0, 13, Color(color, 0.7))
