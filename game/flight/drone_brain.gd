extends RefCounted
## Nova Soma Compliance drone: slow, relentless, detonates on contact.
## Two hits pop it. It never stops pursuing, so shoot it or out-fly it.

const RADIUS := 16.0
const MAX_SPEED := 150.0
const ACCEL := 90.0
const BLAST_DAMAGE := 18.0
const MAX_HP := 2

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var hp := MAX_HP
var spawn_time := 0.0
var active := false
var dead := false


## Returns "arrived", "detonate" or "".
func update(dt: float, elapsed: float, ship_pos: Vector2, hunting: bool) -> String:
	if dead:
		return ""
	if not active:
		if elapsed >= spawn_time:
			active = true
			return "arrived"
		return ""
	var desired := (ship_pos - pos).normalized() * MAX_SPEED
	vel = vel.move_toward(desired, ACCEL * dt)
	pos += vel * dt
	if hunting and pos.distance_to(ship_pos) < RADIUS + 16.0:
		dead = true
		return "detonate"
	return ""


func hit() -> bool:
	if dead or not active:
		return false
	hp -= 1
	if hp <= 0:
		dead = true
		return true
	return false
