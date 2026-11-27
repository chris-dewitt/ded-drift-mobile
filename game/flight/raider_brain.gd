extends RefCounted
## Krellborn pirate raider: fast, fragile, keeps ~280 px off your hull and
## circles while firing leading bolts. Pirates use their own hulls (never
## barges: barges are Local 404 only).

const RADIUS := 20.0
const MAX_SPEED := 300.0
const ACCEL := 260.0
const ORBIT := 280.0
const FIRE_RANGE := 620.0
const FIRE_EVERY := 1.6
const BOLT_SPEED := 430.0
const MAX_HP := 4

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var rot := 0.0
var hp := MAX_HP
var spawn_time := 0.0
var active := false
var dead := false
var cooldown := 1.2
var orbit_dir := 1.0
var aim := Vector2.RIGHT  # direction of the last shot


## Returns "arrived", "fire" or "".
func update(dt: float, elapsed: float, ship_pos: Vector2, ship_vel: Vector2, hunting: bool) -> String:
	if dead:
		return ""
	if not active:
		if elapsed >= spawn_time:
			active = true
			return "arrived"
		return ""
	cooldown = maxf(0.0, cooldown - dt)
	var away := pos - ship_pos
	var dist := away.length()
	var dir := away / dist if dist > 1.0 else Vector2.RIGHT
	var slot := ship_pos + dir.rotated(orbit_dir * 0.55) * ORBIT
	var desired := (slot - pos).limit_length(MAX_SPEED)
	vel = vel.move_toward(desired, ACCEL * dt)
	pos += vel * dt
	rot = lerp_angle(rot, (ship_pos - pos).angle(), minf(1.0, 6.0 * dt))
	if hunting and cooldown <= 0.0 and dist < FIRE_RANGE:
		cooldown = FIRE_EVERY
		var lead := ship_pos + ship_vel * (dist / BOLT_SPEED)
		aim = (lead - pos).normalized().rotated(sin(elapsed * 13.7) * 0.07)
		return "fire"
	return ""


## Returns true when this hit destroys it.
func hit() -> bool:
	if dead or not active:
		return false
	hp -= 1
	orbit_dir = -orbit_dir  # jink when shot
	if hp <= 0:
		dead = true
		return true
	return false
