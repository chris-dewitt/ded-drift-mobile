extends "res://tests/test_case.gd"

const Synth := preload("res://game/audio/synth.gd")
const RaiderBrain := preload("res://game/flight/raider_brain.gd")
const DroneBrain := preload("res://game/flight/drone_brain.gd")


func _bounded(buf: PackedFloat32Array) -> bool:
	for v in buf:
		if absf(v) > 1.5 or is_nan(v):
			return false
	return true


func test_sfx_bank_complete_and_bounded() -> void:
	var sfx: Dictionary = Synth.render_sfx()
	for key in ["gun", "enemy_shot", "hit", "explode", "pickup", "patch", "clamp", "snap", "slingshot",
			"warp", "jump_ready", "ui_tap", "key", "deny", "exploit", "release", "alarm", "bax0", "thrust_loop"]:
		assert_true(sfx.has(key), "sfx %s exists" % key)
		if sfx.has(key):
			var buf: PackedFloat32Array = sfx[key]
			assert_true(buf.size() > 100, "sfx %s has samples" % key)
			assert_true(_bounded(buf), "sfx %s stays in range" % key)


func test_music_layers_loop_and_align() -> void:
	var n := Synth.loop_samples()
	for buf in [Synth.render_pad(), Synth.render_pulse(), Synth.render_tension(), Synth.render_terminal()]:
		assert_eq(buf.size(), n, "every layer is exactly one loop long (they stay in sync)")
		assert_true(_bounded(buf), "layer stays in range")
	var wav := Synth.make_stream(Synth.to_pcm(Synth.render_hum()), true)
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "hum loops")
	assert_eq(wav.loop_end, Synth.RATE * 2, "loop end in samples")


func test_raider_orbits_and_fires() -> void:
	var r := RaiderBrain.new()
	r.pos = Vector2(2000, 0)
	r.spawn_time = 1.0
	assert_eq(r.update(0.1, 0.5, Vector2.ZERO, Vector2.ZERO, true), "", "waits for spawn time")
	assert_eq(r.update(0.1, 1.5, Vector2.ZERO, Vector2.ZERO, true), "arrived")
	var fired := false
	var aimed := true
	for i in 1200:
		if r.update(1.0 / 60.0, 2.0 + i / 60.0, Vector2.ZERO, Vector2.ZERO, true) == "fire":
			fired = true
			aimed = aimed and r.aim.dot(-r.pos.normalized()) > 0.9
	assert_true(fired, "raider fires once in range")
	assert_true(aimed, "shots aim at the ship")
	var d := r.pos.length()
	assert_true(d > 120.0 and d < 520.0, "raider holds a stand-off orbit, got %s" % d)
	for i in RaiderBrain.MAX_HP - 1:
		assert_false(r.hit())
	assert_true(r.hit(), "dies on the last hit")
	assert_eq(r.update(0.1, 99.0, Vector2.ZERO, Vector2.ZERO, true), "", "dead raiders do nothing")


func test_drone_chases_and_detonates() -> void:
	var d := DroneBrain.new()
	d.pos = Vector2(600, 0)
	d.update(0.1, 1.0, Vector2.ZERO, true)
	var boom := false
	for i in 2400:
		if d.update(1.0 / 60.0, 2.0, Vector2.ZERO, true) == "detonate":
			boom = true
			break
	assert_true(boom, "drone reaches the ship and detonates")
	assert_true(d.dead, "and is gone")
	var e := DroneBrain.new()
	e.update(0.1, 1.0, Vector2(500, 0), true)
	assert_false(e.hit(), "first hit")
	assert_true(e.hit(), "second hit kills")
