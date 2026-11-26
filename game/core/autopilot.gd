extends Node
## Autoload "Autopilot" (DEBUG BUILDS ONLY). When user://autopilot.txt exists
## the game plays itself: title -> flight (random flying, forced jumps, a
## death every few sectors) -> terminals (scripted winning lines) -> repeat.
## CI uses this on an Android emulator to catch on-device crashes. Release
## builds ignore it completely, and the flag file can only be planted through
## `adb run-as`, which requires a debuggable build.

const FLAG := "user://autopilot.txt"

const TERMINAL_SCRIPTS := {
	"gary": ["union brother", "solidarity and dues", "strike picket overtime"],
	"tk9": ["' OR 1=1 --"],
	"kress": ["python", "import os"],
}

var active := false
var _rng := RandomNumberGenerator.new()
var _scene_time := 0.0
var _last_scene: Node
var _sectors := 0
var _script_i := 0
var _action_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	active = OS.is_debug_build() and FileAccess.file_exists(FLAG)
	if active:
		_rng.seed = 404
		print("AUTOPILOT: engaged")


func _process(delta: float) -> void:
	if not active:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene != _last_scene:
		_last_scene = scene
		_scene_time = 0.0
		_script_i = 0
		print("AUTOPILOT: scene %s" % scene.name)
	_scene_time += delta
	_action_timer -= delta
	match str(scene.name):
		"TitleScreen":
			_title(scene)
		"Flight":
			_flight(scene)
		"TerminalScreen":
			_terminal(scene)


func _tap_event(pos: Vector2) -> InputEventScreenTouch:
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.position = pos
	return t


func _title(scene: Node) -> void:
	if _scene_time > 2.0 and _action_timer <= 0.0:
		_action_timer = 5.0
		var run := get_node("/root/RunState")
		if _sectors % 4 == 2:
			run.meta["jumps"] = 2  # next jump brings a terminal
		print("AUTOPILOT: launch")
		scene._unhandled_input(_tap_event(Vector2(640, 420)))


func _flight(scene: Node) -> void:
	var controls = scene.controls
	if controls == null:
		return
	if scene.is_playing():
		if _action_timer <= 0.0:
			_action_timer = 0.8
			controls.debug_aim = Vector2.from_angle(_rng.randf() * TAU)
			controls.debug_thrust = _rng.randf() < 0.65
			controls.debug_fire = _rng.randf() < 0.4
		if scene.run.hull < 25.0 and _sectors % 3 != 2:
			scene.run.hull = 80.0  # keep most runs alive so we reach terminals
		if _scene_time > 14.0 and not scene.jump_ready:
			scene.time_left = 0.0
		if scene.jump_ready and _scene_time > 16.0:
			for b in scene.barges:
				if b.state == b.State.CLAMPED:
					b.state = b.State.STUNNED
					b.timer = 3.0
			controls.press_jump_for_test()
		if _sectors % 3 == 2 and _scene_time > 10.0 and scene.run.hull > 0.0:
			print("AUTOPILOT: forcing a death")
			scene._damage(999.0)
	elif scene.is_cleared() or scene.is_dead():
		controls.debug_thrust = false
		controls.debug_fire = false
		if scene.phase_timer > 1.5 and _action_timer <= 0.0:
			_action_timer = 3.0
			_sectors += 1
			print("AUTOPILOT: overlay -> continue (%s)" % ("cleared" if scene.is_cleared() else "dead"))
			controls.inject_tap(Vector2(640, 400))


func _terminal(scene: Node) -> void:
	if scene.finished:
		if scene._outcome_age > 1.5 and _action_timer <= 0.0:
			_action_timer = 3.0
			print("AUTOPILOT: terminal outcome %s" % scene.outcome)
			scene._tap(Vector2(640, 600))
		return
	if _scene_time < 3.0 or _action_timer > 0.0:
		return
	_action_timer = 2.0
	var lines: Array = TERMINAL_SCRIPTS.get(str(scene.npc["id"]), ["hello"])
	var line: String = lines[_script_i % lines.size()]
	_script_i += 1
	# Type the first characters on the CRT keyboard to exercise it, then the rest.
	for ch in line.left(3):
		scene.keyboard.press(ch)
	scene.buffer += line.substr(3)
	print("AUTOPILOT: terminal says '%s'" % line)
	scene.keyboard.press("ENTER")
