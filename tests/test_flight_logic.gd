extends "res://tests/test_case.gd"

const ShipBody := preload("res://game/flight/ship_body.gd")
const Gravity := preload("res://game/flight/gravity.gd")
const SlingshotTracker := preload("res://game/flight/slingshot_tracker.gd")
const BargeBrain := preload("res://game/flight/barge_brain.gd")
const SectorConfig := preload("res://game/flight/sector_config.gd")
const Fmt := preload("res://game/core/fmt.gd")


func test_integrate_applies_dt_once() -> void:
	var s := ShipBody.new()
	s.add_force(Vector2(100, 0))
	s.integrate(0.5)
	assert_true(is_equal_approx(s.vel.x, 50.0), "v = F*dt (dt applied only in integrate), got %s" % s.vel.x)
	s.integrate(0.5)
	assert_true(is_equal_approx(s.vel.x, 50.0), "no drag: velocity persists with no force")


func test_thrust_never_exceeds_cap() -> void:
	var s := ShipBody.new()
	for i in 1200:
		s.apply_thrust(1.0)
		s.integrate(1.0 / 120.0)
	assert_true(s.vel.length() <= ShipBody.MAX_SPEED + 0.01, "speed capped at 280, got %s" % s.vel.length())
	assert_true(s.vel.length() > ShipBody.MAX_SPEED - 1.0, "thrust reaches the cap")


func test_overdrive_raises_cap_then_bleeds() -> void:
	var s := ShipBody.new()
	s.overdrive = 3.0
	for i in 300:
		s.apply_thrust(1.0)
		s.integrate(1.0 / 120.0)
	assert_true(s.vel.length() > 400.0, "overdrive allows ~420, got %s" % s.vel.length())
	assert_true(s.vel.length() <= ShipBody.OVERDRIVE_SPEED + 0.01, "but no more than 420")
	for i in 72:
		s.integrate(1.0 / 120.0)
	assert_true(s.overdrive == 0.0, "overdrive timer ran out")
	assert_true(s.vel.length() < 410.0 and s.vel.length() > ShipBody.MAX_SPEED,
		"over-cap speed bleeds gradually, got %s" % s.vel.length())


func test_steering_reaches_heading_without_snapping() -> void:
	var s := ShipBody.new()
	s.rot = 0.0
	s.steer_toward(PI / 2.0, 1.0 / 120.0)
	s.integrate(1.0 / 120.0)
	assert_true(s.rot < 0.05, "no instant snap")
	for i in 240:
		s.steer_toward(PI / 2.0, 1.0 / 120.0)
		s.integrate(1.0 / 120.0)
	assert_true(absf(wrapf(s.rot - PI / 2.0, -PI, PI)) < 0.05, "reaches heading, got %s" % s.rot)


func test_gravity_pulls_toward_well_and_falls_off() -> void:
	var near := Gravity.well_accel(Vector2(100, 0), Vector2.ZERO, 1.0)
	var far := Gravity.well_accel(Vector2(600, 0), Vector2.ZERO, 1.0)
	assert_true(near.x < 0.0, "pull points at the well")
	assert_true(near.length() > far.length() * 4.0, "inverse-square falloff")
	assert_eq(Gravity.well_accel(Vector2.ZERO, Vector2.ZERO, 1.0), Vector2.ZERO, "no NaN at the centre")


func _pass(tracker, closest: float, exit_speed: float) -> bool:
	var got := false
	# Enter the band (200), dive to `closest`, exit. Never dips below `closest`.
	for r in [300.0, 190.0, closest, 190.0, 250.0]:
		if tracker.update(r, exit_speed):
			got = true
	return got


func test_slingshot_detection() -> void:
	assert_true(_pass(SlingshotTracker.new(200.0, 50.0), 90.0, 220.0), "close fast pass counts")
	assert_false(_pass(SlingshotTracker.new(200.0, 50.0), 160.0, 220.0), "wide pass doesn't count")
	assert_false(_pass(SlingshotTracker.new(200.0, 50.0), 90.0, 80.0), "slow pass doesn't count")
	var crashed := SlingshotTracker.new(200.0, 50.0)
	crashed.update(150.0, 200.0)
	crashed.update(60.0, 200.0)
	crashed.cancel()
	assert_false(crashed.update(250.0, 220.0), "core hit spoils the pass")


func test_barge_lifecycle() -> void:
	var b := BargeBrain.new()
	b.pos = Vector2(1000, 0)
	b.home = b.pos
	b.spawn_time = 5.0
	assert_eq(b.update(0.1, 1.0, Vector2.ZERO, Vector2.ZERO, true), "", "dormant before spawn")
	assert_false(b.is_active(), "still dormant")
	b.update(0.1, 6.0, Vector2(5000, 0), Vector2.ZERO, true)
	assert_eq(b.state, BargeBrain.State.PATROL, "patrols after spawn")
	assert_eq(b.update(0.1, 6.1, Vector2(400, 0), Vector2.ZERO, true), "spotted", "spots a nearby ship")
	var clamped := false
	for i in 2000:
		if b.update(1.0 / 60.0, 7.0, Vector2(400, 0), Vector2.ZERO, true) == "clamped":
			clamped = true
			break
	assert_true(clamped, "chases and clamps")
	assert_true(b.tether_accel(b.pos + Vector2(50, 0)) == Vector2.ZERO, "no pull inside rest length")
	var pull := b.tether_accel(b.pos + Vector2(250, 0))
	assert_true(pull.x < 0.0, "tether pulls ship toward barge")
	assert_true(pull.length() < 240.0, "full thrust can out-pull the tether at snap range")
	assert_eq(b.update(1.0 / 60.0, 8.0, b.pos + Vector2(400, 0), Vector2.ZERO, true), "snapped", "tether snaps when stretched")
	assert_eq(b.state, BargeBrain.State.STUNNED)


func test_barge_hits_break_clamp() -> void:
	var b := BargeBrain.new()
	b.state = BargeBrain.State.CLAMPED
	var last := ""
	for i in BargeBrain.CLAMP_HITS_TO_BREAK:
		last = b.register_hit()
	assert_eq(last, "broken", "shooting the barge breaks the clamp")
	assert_eq(b.state, BargeBrain.State.STUNNED)


func test_sector_config_scales() -> void:
	var s1 := SectorConfig.for_sector(1)
	var s5 := SectorConfig.for_sector(5)
	assert_true(s5["duration"] > s1["duration"], "later sectors are longer")
	assert_true(s5["debris"] > s1["debris"], "and busier")
	assert_eq(SectorConfig.for_sector(99)["name"], s5["name"], "clamped")


func test_fmt() -> void:
	assert_eq(Fmt.cr(1234567), "1,234,567")
	assert_eq(Fmt.cr(0), "0")
	assert_eq(Fmt.cr(-1500), "-1,500")
	assert_eq(Fmt.cr(999), "999")
	assert_eq(Fmt.clock(65.2), "1:06")
	assert_eq(Fmt.clock(-3.0), "0:00")
