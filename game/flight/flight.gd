extends Node2D
## One flight sector: Newtonian ship, gravity wells (slingshot for overdrive
## and credits), debris to shoot, salvage pickups, Local 404 repo barges with
## harpoon tethers, a gate timer, and JUMP to the next sector.
##
## The simulation runs in fixed 120 Hz sub-steps inside _process, so motion is
## smooth on both 60 Hz and 120 Hz phone screens.

const ShipBody := preload("res://game/flight/ship_body.gd")
const Gravity := preload("res://game/flight/gravity.gd")
const SlingshotTracker := preload("res://game/flight/slingshot_tracker.gd")
const BargeBrain := preload("res://game/flight/barge_brain.gd")
const SectorConfig := preload("res://game/flight/sector_config.gd")
const BaxLines := preload("res://game/bax/bax_lines.gd")
const TouchControls := preload("res://game/ui/touch_controls.gd")
const Hud := preload("res://game/ui/hud.gd")

enum Phase { PLAYING, WARPING, EXPLODING, CLEARED, DEAD }

const TITLE_SCENE := "res://game/ui/title_screen.tscn"
const STEP := 1.0 / 120.0
const MAX_STEPS := 12
const WORLD := Rect2(0, 0, 3600, 2100)
const WALL_FORCE := 420.0
const BULLET_SPEED := 600.0
const BULLET_LIFE := 1.0
const FIRE_INTERVAL := 0.13
const AUTOFIRE_RANGE := 640.0
const AUTOFIRE_CONE := 0.26  # radians either side of the nose
const PICKUP_RADIUS := 34.0
const CLAMP_HULL_DRAIN := 3.5  # hull per second while harpooned
const WARP_TIME := 1.1
const EXPLODE_TIME := 1.6
const OVERLAY_GUARD := 0.7  # ignore taps this long after an overlay appears
const SCRAP_CREDITS := 120
const DEBRIS_CREDITS := 30
const SLINGSHOT_CREDITS := 150
const BARGE_STUN_CREDITS := 250
const PATCH_HULL := 15.0
const CORE_DAMAGE := 14.0

const AMBER := Color(1.0, 0.70, 0.28)
const CYAN := Color(0.25, 0.88, 0.82)
const RED := Color(1.0, 0.32, 0.28)
const DIM := Color(0.55, 0.60, 0.65)
const WHITE := Color(1, 1, 1)


class Well:
	var pos := Vector2.ZERO
	var mass := 1.0
	var core := 50.0
	var tracker  # SlingshotTracker
	var ship_inside := false


class Debris:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var radius := 20.0
	var rot := 0.0
	var spin := 0.0
	var hp := 2
	var shape := PackedVector2Array()


class Pickup:
	var pos := Vector2.ZERO
	var kind := "scrap"
	var t := 0.0


class Bullet:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0


class Spark:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0
	var max_life := 0.5
	var color := Color.WHITE


var run: Node
var cfg: Dictionary
var ship := ShipBody.new()
var wells: Array[Well] = []
var debris: Array[Debris] = []
var pickups: Array[Pickup] = []
var bullets: Array[Bullet] = []
var sparks: Array[Spark] = []
var barges: Array = []
var stars: Array[Vector3] = []

var phase: Phase = Phase.PLAYING
var paused := false
var elapsed := 0.0
var time_left := 0.0
var jump_ready := false
var phase_timer := 0.0
var sector_credits := 0
var damage_flash := 0.0
var thrusting := false
var result := {}  # filled when the sector ends, read by the HUD overlay

var camera: Camera2D
var controls: TouchControls
var hud: Hud

var _accum := 0.0
var _fire_cooldown := 0.0
var _haptic_cooldown := 0.0
var _core_line_cooldown := 0.0
var _hull_warned := false
var _rng := RandomNumberGenerator.new()
var _font: Font


func _ready() -> void:
	run = get_node("/root/RunState")
	_font = ThemeDB.fallback_font
	_rng.randomize()
	cfg = SectorConfig.for_sector(run.sector)
	time_left = cfg["duration"]
	_build_world()
	camera = Camera2D.new()
	camera.position = ship.pos
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.flight = self
	layer.add_child(hud)
	controls = TouchControls.new()
	controls.flight = self
	layer.add_child(controls)
	bax(BaxLines.sector_start(run.sector))


# --- queries used by HUD / controls ---------------------------------------------

func is_playing() -> bool:
	return phase == Phase.PLAYING and not paused


func can_pause() -> bool:
	return phase == Phase.PLAYING


func is_cleared() -> bool:
	return phase == Phase.CLEARED


func is_dead() -> bool:
	return phase == Phase.DEAD


func bax(line: String) -> void:
	if hud != null:
		hud.show_bax(line)


# --- world setup ---------------------------------------------------------------

func _build_world() -> void:
	ship.pos = Vector2(WORLD.size.x * 0.12, WORLD.size.y * 0.5)
	ship.rot = 0.0
	var placed: Array[Vector2] = [ship.pos]
	for _i in int(cfg["wells"]):
		var w := Well.new()
		w.pos = _free_spot(placed, 560.0, 300.0)
		w.mass = _rng.randf_range(0.8, 1.4)
		w.core = 34.0 + 22.0 * w.mass
		w.tracker = SlingshotTracker.new(w.core * 4.2, w.core)
		wells.append(w)
		placed.append(w.pos)
	for _i in int(cfg["debris"]):
		var spot := _free_spot(placed, 170.0, 120.0)
		debris.append(_make_debris(spot, _rng.randf_range(16.0, 34.0)))
		placed.append(spot)
	for i in int(cfg["pickups"]):
		var p := Pickup.new()
		p.pos = _free_spot(placed, 200.0, 150.0)
		p.kind = "patch" if i % 3 == 0 else "scrap"
		p.t = _rng.randf() * TAU
		pickups.append(p)
		placed.append(p.pos)
	for i in int(cfg["barges"]):
		var b := BargeBrain.new()
		b.home = Vector2(WORLD.size.x * _rng.randf_range(0.6, 0.9), WORLD.size.y * _rng.randf_range(0.2, 0.8))
		b.pos = b.home
		b.spawn_time = float(cfg["barge_delay"]) + 6.0 * i
		barges.append(b)
	var star_rng := RandomNumberGenerator.new()
	star_rng.seed = 404 + int(run.sector)
	for _i in 220:
		stars.append(Vector3(star_rng.randf(), star_rng.randf(), star_rng.randf_range(0.15, 1.0)))


func _free_spot(placed: Array[Vector2], min_dist: float, margin: float) -> Vector2:
	var area := WORLD.grow(-margin)
	var spot := Vector2.ZERO
	for _attempt in 40:
		spot = Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
		var ok := true
		for other in placed:
			if spot.distance_to(other) < min_dist:
				ok = false
				break
		if ok:
			return spot
	return spot


func _make_debris(pos: Vector2, radius: float) -> Debris:
	var d := Debris.new()
	d.pos = pos
	d.radius = radius
	d.vel = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(8.0, 40.0)
	d.spin = _rng.randf_range(-1.2, 1.2)
	d.hp = ceili(radius / 11.0)
	var n := 7 + _rng.randi() % 4
	for k in n:
		d.shape.append(Vector2.from_angle(TAU * k / n) * radius * _rng.randf_range(0.72, 1.08))
	d.shape.append(d.shape[0])
	return d


# --- frame loop ------------------------------------------------------------------

func _process(delta: float) -> void:
	_haptic_cooldown = maxf(0.0, _haptic_cooldown - delta)
	damage_flash = maxf(0.0, damage_flash - delta)
	if controls.consume_pause() and can_pause():
		set_paused(not paused)
	if paused:
		_handle_pause_tap()
	elif phase == Phase.CLEARED or phase == Phase.DEAD:
		phase_timer += delta
		if controls.consume_tap() and phase_timer > OVERLAY_GUARD:
			_leave_overlay()
	else:
		controls.consume_tap()
		_accum = minf(_accum + delta, STEP * MAX_STEPS)
		while _accum >= STEP:
			_step(STEP)
			_accum -= STEP
	camera.position = ship.pos + ship.vel * 0.35
	queue_redraw()
	hud.queue_redraw()
	controls.queue_redraw()


func _notification(what: int) -> void:
	# Phone call / app switch: pause instead of flying on without you.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if controls != null and phase == Phase.PLAYING and not paused:
			set_paused(true)


func set_paused(value: bool) -> void:
	paused = value
	controls.clear_taps()


func _handle_pause_tap() -> void:
	if not controls.consume_tap():
		return
	var p := controls.tap_position()
	if hud.resume_rect.has_point(p):
		set_paused(false)
	elif hud.quit_rect.has_point(p):
		_quit_to_title()


func _leave_overlay() -> void:
	if phase == Phase.CLEARED and not result.get("chapter", false):
		get_tree().reload_current_scene()
	else:
		_quit_to_title()


func _quit_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)


# --- simulation --------------------------------------------------------------------

func _step(dt: float) -> void:
	elapsed += dt
	_fire_cooldown = maxf(0.0, _fire_cooldown - dt)
	_core_line_cooldown = maxf(0.0, _core_line_cooldown - dt)
	match phase:
		Phase.PLAYING:
			_step_ship(dt)
		Phase.WARPING:
			phase_timer += dt
			ship.overdrive = 1.0
			ship.add_force(ship.forward() * 1400.0)
			ship.integrate(dt)
			if phase_timer >= WARP_TIME:
				_finish_sector()
		Phase.EXPLODING:
			phase_timer += dt
			if phase_timer >= EXPLODE_TIME:
				_finish_death()
	_step_world(dt)


func _step_ship(dt: float) -> void:
	var aim := controls.aim_vector()
	if aim.length() > 0.2:
		ship.steer_toward(aim.angle(), dt)
	else:
		ship.steer_hold(dt)
	thrusting = controls.thrust_held()
	if thrusting:
		ship.apply_thrust(1.0)
	elif controls.retro_held():
		ship.apply_thrust(-ShipBody.RETRO_FACTOR)
	for w in wells:
		ship.add_force(Gravity.well_accel(ship.pos, w.pos, w.mass))
	ship.add_force(_wall_force(ship.pos))
	for b in barges:
		if b.state == BargeBrain.State.CLAMPED:
			ship.add_force(b.tether_accel(ship.pos))
			_damage(CLAMP_HULL_DRAIN * dt, false)
	ship.integrate(dt)
	_check_wells()
	_check_debris_hits()
	_check_pickups()
	_try_fire(controls.fire_held())
	if not jump_ready:
		time_left = maxf(0.0, time_left - dt)
		if time_left <= 0.0:
			jump_ready = true
			bax(BaxLines.pick(BaxLines.JUMP_READY))
			_haptic(120)
	if jump_ready and controls.consume_jump():
		_try_jump()
	if run.hull <= 0.0:
		_start_explosion()


func _wall_force(p: Vector2) -> Vector2:
	var f := Vector2.ZERO
	if p.x < WORLD.position.x:
		f.x += WALL_FORCE
	elif p.x > WORLD.end.x:
		f.x -= WALL_FORCE
	if p.y < WORLD.position.y:
		f.y += WALL_FORCE
	elif p.y > WORLD.end.y:
		f.y -= WALL_FORCE
	return f


func _check_wells() -> void:
	for w in wells:
		var r := ship.pos.distance_to(w.pos)
		w.ship_inside = r < w.tracker.band
		if r < w.core + ShipBody.RADIUS:
			w.tracker.cancel()
			var n := (ship.pos - w.pos).normalized()
			if n == Vector2.ZERO:
				n = Vector2.RIGHT
			ship.pos = w.pos + n * (w.core + ShipBody.RADIUS + 2.0)
			var vn := ship.vel.dot(n)
			if vn < 0.0:
				ship.vel -= n * vn * 1.8
			_damage(CORE_DAMAGE)
			if _core_line_cooldown <= 0.0:
				_core_line_cooldown = 6.0
				bax(BaxLines.pick(BaxLines.CORE))
		if w.tracker.update(r, ship.vel.length()):
			ship.overdrive = 3.0
			sector_credits += SLINGSHOT_CREDITS
			bax(BaxLines.pick(BaxLines.SLINGSHOT))
			_sparks(ship.pos, 18, CYAN)
			_haptic(70)


func _check_debris_hits() -> void:
	for d in debris:
		var delta := ship.pos - d.pos
		var min_d := d.radius * 0.9 + ShipBody.RADIUS
		if delta.length_squared() >= min_d * min_d:
			continue
		var n := delta.normalized()
		if n == Vector2.ZERO:
			n = Vector2.RIGHT
		var vn := (ship.vel - d.vel).dot(n)
		ship.pos = d.pos + n * (min_d + 1.0)
		if vn < 0.0:
			ship.vel -= n * vn * 1.5
			d.vel += n * vn * 0.3
			_damage(clampf((-vn - 40.0) * 0.09, 2.0, 28.0))
			_sparks(ship.pos - n * ShipBody.RADIUS, 8, AMBER)


func _check_pickups() -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var p := pickups[i]
		if ship.pos.distance_to(p.pos) > PICKUP_RADIUS:
			continue
		if p.kind == "patch":
			run.hull = minf(run.HULL_MAX, run.hull + PATCH_HULL)
			if run.hull >= 30.0:
				_hull_warned = false
			bax(BaxLines.pick(BaxLines.PATCH))
			_sparks(p.pos, 12, CYAN)
		else:
			sector_credits += SCRAP_CREDITS
			bax(BaxLines.pick(BaxLines.SCRAP))
			_sparks(p.pos, 12, AMBER)
		_haptic(30)
		pickups.remove_at(i)


func _try_fire(manual: bool) -> void:
	if _fire_cooldown > 0.0:
		return
	if not manual and not _autofire_target():
		return
	_fire_cooldown = FIRE_INTERVAL
	var b := Bullet.new()
	b.pos = ship.pos + ship.forward() * 18.0
	b.vel = ship.vel + ship.forward() * BULLET_SPEED
	b.life = BULLET_LIFE
	bullets.append(b)


func _autofire_target() -> bool:
	for d in debris:
		if _in_cone(d.pos, d.radius):
			return true
	for b in barges:
		if b.is_active() and _in_cone(b.pos, BargeBrain.RADIUS):
			return true
	return false


func _in_cone(target: Vector2, radius: float) -> bool:
	var to := target - ship.pos
	if to.length() > AUTOFIRE_RANGE + radius:
		return false
	return absf(wrapf(to.angle() - ship.rot, -PI, PI)) < AUTOFIRE_CONE


func _try_jump() -> void:
	for b in barges:
		if b.state == BargeBrain.State.CLAMPED:
			bax(BaxLines.pick(BaxLines.JUMP_CLAMPED))
			return
	phase = Phase.WARPING
	phase_timer = 0.0
	_haptic(200)


func _finish_sector() -> void:
	phase = Phase.CLEARED
	phase_timer = 0.0
	run.credits += sector_credits
	result = run.complete_sector()
	result["salvage"] = sector_credits
	controls.clear_taps()


func _start_explosion() -> void:
	phase = Phase.EXPLODING
	phase_timer = 0.0
	_sparks(ship.pos, 60, AMBER)
	_sparks(ship.pos, 30, RED)
	_haptic(400)


func _finish_death() -> void:
	phase = Phase.DEAD
	phase_timer = 0.0
	result = run.die()
	controls.clear_taps()


func _damage(amount: float, big := true) -> void:
	run.hull = maxf(0.0, run.hull - amount)
	if big:
		damage_flash = 0.3
		_haptic(int(30.0 + amount * 5.0))
	if run.hull < 30.0 and not _hull_warned:
		_hull_warned = true
		bax(BaxLines.pick(BaxLines.HULL_LOW))


func _step_world(dt: float) -> void:
	for d in debris:
		d.pos += d.vel * dt
		d.rot += d.spin * dt
		if d.pos.x < WORLD.position.x or d.pos.x > WORLD.end.x:
			d.vel.x = -d.vel.x
			d.pos.x = clampf(d.pos.x, WORLD.position.x, WORLD.end.x)
		if d.pos.y < WORLD.position.y or d.pos.y > WORLD.end.y:
			d.vel.y = -d.vel.y
			d.pos.y = clampf(d.pos.y, WORLD.position.y, WORLD.end.y)
	_step_bullets(dt)
	for i in range(sparks.size() - 1, -1, -1):
		var s := sparks[i]
		s.pos += s.vel * dt
		s.vel *= 0.96
		s.life -= dt
		if s.life <= 0.0:
			sparks.remove_at(i)
	for p in pickups:
		p.t += dt
	for b in barges:
		var event: String = b.update(dt, elapsed, ship.pos, ship.vel, phase == Phase.PLAYING)
		if event != "":
			_on_barge_event(event)


func _step_bullets(dt: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b := bullets[i]
		b.pos += b.vel * dt
		b.life -= dt
		var hit := false
		for j in range(debris.size() - 1, -1, -1):
			var d := debris[j]
			if b.pos.distance_squared_to(d.pos) < d.radius * d.radius:
				hit = true
				d.hp -= 1
				_sparks(b.pos, 4, DIM)
				if d.hp <= 0:
					_destroy_debris(j)
				break
		if not hit:
			for brg in barges:
				if brg.is_active() and b.pos.distance_to(brg.pos) < BargeBrain.RADIUS:
					hit = true
					_sparks(b.pos, 5, RED)
					var event: String = brg.register_hit()
					if event != "":
						_on_barge_event(event)
					break
		if hit or b.life <= 0.0:
			bullets.remove_at(i)


func _destroy_debris(index: int) -> void:
	var d := debris[index]
	debris.remove_at(index)
	sector_credits += DEBRIS_CREDITS
	_sparks(d.pos, 14, DIM)
	_haptic(25)
	if d.radius > 22.0:
		for k in 2:
			var child := _make_debris(d.pos + Vector2.from_angle(k * PI) * d.radius * 0.4, d.radius * 0.55)
			child.vel += d.vel
			debris.append(child)


func _on_barge_event(event: String) -> void:
	match event:
		"spotted":
			bax(BaxLines.pick(BaxLines.BARGE_SPOTTED))
			_haptic(60)
		"clamped":
			bax(BaxLines.pick(BaxLines.CLAMPED))
			_haptic(300)
		"snapped":
			bax(BaxLines.pick(BaxLines.SNAPPED))
			_haptic(150)
		"broken", "stunned":
			bax(BaxLines.pick(BaxLines.STUNNED))
			sector_credits += BARGE_STUN_CREDITS
			_haptic(150)


func _sparks(pos: Vector2, count: int, color: Color) -> void:
	for _k in count:
		var s := Spark.new()
		s.pos = pos
		s.vel = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(40.0, 220.0)
		s.max_life = _rng.randf_range(0.25, 0.6)
		s.life = s.max_life
		s.color = color
		sparks.append(s)


func _haptic(ms: int) -> void:
	if _haptic_cooldown > 0.0 or not OS.has_feature("mobile"):
		return
	_haptic_cooldown = 0.08
	Input.vibrate_handheld(clampi(ms, 10, 500))


# --- drawing (world space; the Camera2D follows the ship) ---------------------------

func _draw() -> void:
	var view := get_viewport_rect().size
	var centre := camera.get_screen_center_position() if camera != null else ship.pos
	_draw_stars(centre - view * 0.5, view)
	draw_rect(WORLD, Color(RED, 0.35), false, 3.0)
	for w in wells:
		_draw_well(w)
	for p in pickups:
		_draw_pickup(p)
	for d in debris:
		draw_polyline(Transform2D(d.rot, d.pos) * d.shape, DIM, 2.0, true)
	for b in bullets:
		draw_line(b.pos, b.pos - b.vel.normalized() * 12.0, CYAN, 2.0)
	for brg in barges:
		_draw_barge(brg)
	if phase == Phase.PLAYING or phase == Phase.WARPING:
		_draw_ship()
	for s in sparks:
		draw_rect(Rect2(s.pos - Vector2(1.5, 1.5), Vector2(3, 3)), Color(s.color, s.life / s.max_life))


func _draw_stars(top_left: Vector2, view: Vector2) -> void:
	for s in stars:
		var x := top_left.x + fposmod(s.x * view.x - top_left.x * s.z * 0.35, view.x)
		var y := top_left.y + fposmod(s.y * view.y - top_left.y * s.z * 0.35, view.y)
		var size := 1.0 + s.z * 1.6
		draw_rect(Rect2(x, y, size, size), Color(0.75, 0.82, 0.9, 0.2 + 0.6 * s.z))


func _draw_well(w: Well) -> void:
	var span := w.core * 3.2
	for k in 3:
		var rr := w.core + fposmod(span - elapsed * 40.0 - k * span / 3.0, span)
		var a := 0.35 * (1.0 - (rr - w.core) / span)
		draw_arc(w.pos, rr, 0.0, TAU, 56, Color(AMBER, a), 1.5, true)
	draw_arc(w.pos, w.tracker.band, 0.0, TAU, 72, Color(CYAN, 0.35 if w.ship_inside else 0.10), 1.5, true)
	draw_circle(w.pos, w.core, Color(0.04, 0.025, 0.02))
	draw_arc(w.pos, w.core, 0.0, TAU, 56, AMBER, 3.0, true)


func _draw_pickup(p: Pickup) -> void:
	var c := p.pos + Vector2(0, sin(p.t * 3.0) * 4.0)
	if p.kind == "patch":
		draw_arc(c, 16.0, 0.0, TAU, 32, CYAN, 2.0, true)
		draw_rect(Rect2(c - Vector2(3, 9), Vector2(6, 18)), CYAN)
		draw_rect(Rect2(c - Vector2(9, 3), Vector2(18, 6)), CYAN)
	else:
		var pts := PackedVector2Array([c + Vector2(0, -14), c + Vector2(11, 0), c + Vector2(0, 14), c + Vector2(-11, 0), c + Vector2(0, -14)])
		draw_polyline(pts, AMBER, 2.5, true)


func _draw_barge(b) -> void:
	if not b.is_active():
		return
	var stunned: bool = b.state == BargeBrain.State.STUNNED
	var color := DIM if stunned and int(elapsed * 8.0) % 2 == 0 else RED
	var xf := Transform2D(b.rot, b.pos)
	var hull := PackedVector2Array([Vector2(42, 0), Vector2(18, -30), Vector2(-34, -30), Vector2(-46, 0),
		Vector2(-34, 30), Vector2(18, 30), Vector2(42, 0)])
	draw_polyline(xf * hull, color, 3.0, true)
	var claw := PackedVector2Array([Vector2(42, -14), Vector2(58, -20), Vector2(58, 20), Vector2(42, 14)])
	draw_polyline(xf * claw, color, 2.0, true)
	draw_string(_font, b.pos + Vector2(-18, 6), "404", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	if b.state == BargeBrain.State.CLAMPED:
		var pts := PackedVector2Array()
		var b_pos: Vector2 = b.pos
		var to: Vector2 = ship.pos - b_pos
		var side: Vector2 = to.orthogonal().normalized()
		for k in 13:
			var f := k / 12.0
			pts.append(b.pos + to * f + side * sin(f * PI * 3.0 + elapsed * 12.0) * 6.0)
		draw_polyline(pts, AMBER, 2.0, true)
	if stunned:
		for k in 3:
			var a := elapsed * 3.0 + k * TAU / 3.0
			draw_circle(b.pos + Vector2.from_angle(a) * 38.0 + Vector2(0, -30), 3.0, AMBER)


func _draw_ship() -> void:
	var xf := Transform2D(ship.rot, ship.pos)
	var hull_color := WHITE if damage_flash > 0.0 and int(elapsed * 30.0) % 2 == 0 else AMBER
	if ship.overdrive > 0.0:
		draw_arc(ship.pos, 24.0, 0.0, TAU, 32, Color(CYAN, 0.45), 2.0, true)
	if phase == Phase.WARPING:
		draw_line(ship.pos, ship.pos - ship.forward() * (80.0 + phase_timer * 500.0), Color(CYAN, 0.8), 4.0)
	var hull := PackedVector2Array([Vector2(22, 0), Vector2(-12, -13), Vector2(-5, 0), Vector2(-12, 13), Vector2(22, 0)])
	draw_polyline(xf * hull, hull_color, 2.5, true)
	if thrusting or phase == Phase.WARPING:
		var flame := 10.0 + 6.0 * sin(elapsed * 40.0)
		draw_polyline(xf * PackedVector2Array([Vector2(-8, -5), Vector2(-8 - flame, 0), Vector2(-8, 5)]), CYAN, 2.0, true)
	elif controls != null and controls.retro_held() and phase == Phase.PLAYING:
		draw_polyline(xf * PackedVector2Array([Vector2(16, -6), Vector2(24, -9)]), CYAN, 2.0)
		draw_polyline(xf * PackedVector2Array([Vector2(16, 6), Vector2(24, 9)]), CYAN, 2.0)
