extends SceneTree
## End-to-end smoke test: drives the real scenes with the same calls touch
## input makes, and fails if a promised action does nothing.
##   title tap -> flight · aim + thrust move the ship · 60 s random-input soak
##   with barges live · gate opens · JUMP -> warp -> cleared -> next sector ·
##   pause freezes the game · zero hull -> invoice -> title.
## Run with a real renderer so draw code executes too:
##   xvfb-run godot --path . --rendering-driver opengl3 --script res://tests/smoke_runner.gd

const RunStateScript := preload("res://game/core/run_state.gd")
const AudioScript := preload("res://game/audio/audio_director.gd")
const SaveSchema := preload("res://game/core/save_schema.gd")

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	var rs = root.get_node_or_null("RunState")
	if rs == null:
		rs = RunStateScript.new()
		rs.name = "RunState"
		root.add_child(rs)
	if root.get_node_or_null("Audio") == null:
		var audio = AudioScript.new()
		audio.name = "Audio"
		root.add_child(audio)
	var settings = root.get_node_or_null("Settings")
	if settings != null:
		settings.dismiss_crash()  # this run tests gameplay, not the crash banner
		settings.crt = true
		settings.sound = true
	rs.save_path = "user://smoke_meta.json"
	rs.meta = SaveSchema.default_meta()
	rs.sector = 1
	create_timer(180.0).timeout.connect(func():
		printerr("FAIL  smoke test timed out")
		quit(1))
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  ok    %s" % what)
	else:
		_failures.append(what)
		printerr("  FAIL  %s" % what)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _scene_name() -> String:
	return str(current_scene.name) if current_scene != null else "<none>"


func _run() -> void:
	print("smoke: title -> flight")
	change_scene_to_file("res://game/ui/title_screen.tscn")
	await _frames(3)
	_check(_scene_name() == "TitleScreen", "title screen loads")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(640, 420)
	current_scene._unhandled_input(tap)
	await _frames(3)
	var loaded: bool = _scene_name() == "Flight" and current_scene.has_method("_step")
	_check(loaded, "tapping the title starts a flight sector (and its script loads)")
	if not loaded:
		_finish()
		return
	var flight = current_scene
	await _frames(2)

	print("smoke: controls")
	var start_pos: Vector2 = flight.ship.pos
	flight.controls.debug_aim = Vector2.UP
	flight.controls.debug_thrust = true
	for _i in 240:
		flight._step(flight.STEP)
	_check(flight.ship.pos.distance_to(start_pos) > 50.0, "thrust moves the ship")
	_check(absf(wrapf(flight.ship.rot + PI / 2.0, -PI, PI)) < 0.2, "aim stick turns the ship")
	flight.controls.debug_thrust = false

	print("smoke: 60 s soak with random input")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var barge_seen := false
	var fired := false
	for i in 7200:
		if i % 60 == 0:
			flight.controls.debug_aim = Vector2.from_angle(rng.randf() * TAU)
			flight.controls.debug_thrust = rng.randf() < 0.6
			flight.controls.debug_fire = rng.randf() < 0.5
		flight.run.hull = 100.0
		flight._step(flight.STEP)
		if flight.bullets.size() > 0:
			fired = true
		for b in flight.barges:
			if b.is_active():
				barge_seen = true
	flight.controls.debug_fire = false
	flight.controls.debug_thrust = false
	_check(flight.phase == flight.Phase.PLAYING, "still flying after the soak")
	_check(flight.jump_ready, "gate opens when the timer runs out")
	_check(barge_seen, "a repo barge spawns")
	_check(fired, "guns fire")
	await _frames(3)  # draw code runs with everything on screen

	print("smoke: jump -> cleared -> next sector")
	for b in flight.barges:
		b.state = b.State.STUNNED
		b.timer = 999.0
	flight.controls.press_jump_for_test()
	flight._step(flight.STEP)
	_check(flight.phase == flight.Phase.WARPING, "JUMP starts the warp")
	for _i in 200:
		flight._step(flight.STEP)
	_check(flight.phase == flight.Phase.CLEARED, "warp clears the sector")
	_check(flight.run.sector == 2, "sector counter advances")
	await _frames(3)
	flight.phase_timer = 10.0
	flight.controls.inject_tap(Vector2(640, 400))
	await _frames(4)
	var next_ok: bool = not is_instance_valid(flight) and _scene_name() == "Flight" and current_scene.has_method("_step")
	_check(next_ok, "tap continues to the next sector")
	if not next_ok:
		_finish()
		return
	flight = current_scene
	await _frames(2)
	_check(flight.cfg["name"] == "SLAG BELT", "sector 2 config loaded")
	var raider_seen := false
	var bolts_seen := false
	for i in 3600:
		if i % 60 == 0:
			flight.controls.debug_aim = Vector2.from_angle(rng.randf() * TAU)
			flight.controls.debug_thrust = rng.randf() < 0.5
		flight.run.hull = 100.0
		flight._step(flight.STEP)
		for r in flight.raiders:
			if r.active:
				raider_seen = true
		if flight.enemy_bolts.size() > 0:
			bolts_seen = true
	flight.controls.debug_thrust = false
	_check(raider_seen, "Krellborn raiders show up in sector 2")
	_check(bolts_seen, "raiders shoot")
	await _frames(3)  # draw raiders, bolts, backdrop
	var audio = root.get_node_or_null("Audio")
	if audio != null:
		for _i in 900:
			if audio.is_ready:
				break
			await process_frame
		_check(audio.is_ready, "procedural soundtrack finished rendering")
		# Regression: on-device SIGSEGV came from swapping a playing player's stream.
		var gun_player = audio._players.get("gun")
		_check(gun_player != null, "every sound owns its own player")
		if gun_player != null:
			var stream_before = gun_player.stream
			for _i in 30:
				audio.play("gun")
				audio.play("hit")
				audio.bax_blip()
			_check(gun_player.stream == stream_before, "playing sounds never swaps a player's stream")
		_check(audio.mood() == "chase" or audio.mood() == "calm", "flight sets a music mood")

	print("smoke: pause")
	flight.controls.press_pause_for_test()
	await _frames(2)
	_check(flight.paused, "pause button pauses")
	var frozen: float = flight.elapsed
	await _frames(6)
	_check(flight.elapsed == frozen, "paused game doesn't advance")
	flight.set_paused(false)
	for _i in 120:  # frames can be shorter than one sim step; wait for real time
		await process_frame
		if flight.elapsed > frozen:
			break
	_check(flight.elapsed > frozen, "resume continues the game")

	print("smoke: death -> invoice -> title")
	var clones_before := int(flight.run.meta["clones"])
	flight._damage(999.0)
	for _i in 400:
		flight._step(flight.STEP)
	_check(flight.phase == flight.Phase.DEAD, "zero hull leads to the decanting invoice")
	_check(int(flight.run.meta["clones"]) == clones_before + 1, "death adds a clone")
	_check(flight.run.sector == 2, "retry sector is the one you died on")
	await _frames(3)
	flight.phase_timer = 10.0
	flight.controls.inject_tap(Vector2(640, 400))
	await _frames(4)
	_check(_scene_name() == "TitleScreen", "tap after death returns to the title")

	print("smoke: every 3rd jump -> terminal -> next sector")
	var rs = root.get_node("RunState")
	rs.sector = 3
	rs.meta["jumps"] = 2
	rs.meta["terminals"] = 0  # Gary answers
	current_scene._unhandled_input(tap)
	await _frames(4)
	flight = current_scene
	_check(_scene_name() == "Flight" and flight.has_method("_step"), "sector 3 starts")
	flight.time_left = 0.0
	flight._step(flight.STEP)
	for b in flight.barges:
		b.state = b.State.STUNNED
		b.timer = 999.0
	flight.controls.press_jump_for_test()
	for _i in 200:
		flight._step(flight.STEP)
	_check(flight.phase == flight.Phase.CLEARED and flight.result.get("terminal", false), "jump 3 flags an incoming transmission")
	await _frames(2)
	flight.phase_timer = 10.0
	flight.controls.inject_tap(Vector2(640, 400))
	await _frames(4)
	var term_ok: bool = _scene_name() == "TerminalScreen" and current_scene.has_method("submit_buffer")
	_check(term_ok, "tapping answers the terminal")
	if not term_ok:
		_finish()
		return
	var term = current_scene
	await _frames(3)
	_check(term.npc["id"] == "gary", "Gary is on the line")
	for ch in "union brother":
		term.keyboard.press(" " if ch == " " else ch)  # SPACE key emits " " via typed
	term.keyboard.press("ENTER")
	_check(int(term.engine.progress["solidarity"]) == 1, "typing on the CRT keyboard reaches the rule engine")
	term.insert_chip("dues")
	term.submit_buffer()
	term.buffer = "solidarity on the picket line"
	term.submit_buffer()
	_check(term.finished and term.outcome == "RELEASE", "solidarity path releases you")
	_check(term.total_credits == 2500, "release pays 2,500")
	await _frames(30)  # draw the outcome banner + let lines type out
	var credits_before: int = rs.credits
	term._outcome_age = 10.0
	term._tap(Vector2(640, 600))
	await _frames(4)
	_check(_scene_name() == "Flight", "after the terminal you fly the next sector")
	_check(rs.sector == 4, "into sector 4")
	_check(rs.credits == credits_before + 2500, "terminal winnings are in your run credits")
	_finish()


func _finish() -> void:
	print("\nsmoke: %d checks, %d failed" % [_checks, _failures.size()])
	quit(1 if not _failures.is_empty() else 0)
