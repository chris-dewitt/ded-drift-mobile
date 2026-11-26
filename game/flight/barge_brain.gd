extends RefCounted
## Local 404 repo barge (union repo men only; other factions use other hulls).
## DORMANT -> PATROL -> CHASE -> CLAMPED (harpoon tether) -> STUNNED -> CHASE.
## update() returns an event string ("" when nothing happened) so the flight
## scene can react with Bax lines, haptics and rewards.

enum State { DORMANT, PATROL, CHASE, CLAMPED, STUNNED }

const RADIUS := 44.0
const DETECT_RANGE := 900.0
const CHASE_ACCEL := 140.0
const CHASE_MAX := 205.0  # slower than the ship's 280: you can outrun it
const CLAMP_RANGE := 62.0
const TETHER_REST := 110.0
const TETHER_SNAP := 330.0
const TETHER_K := 0.85  # at snap distance the pull (~187) is below thrust (240)
const HITS_TO_STUN := 10
const CLAMP_HITS_TO_BREAK := 5
const SNAP_STUN := 2.5
const BREAK_STUN := 4.0
const HIT_STUN := 6.0

var state: State = State.DORMANT
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var rot := PI
var home := Vector2.ZERO
var spawn_time := 0.0
var timer := 0.0
var hits := 0


func is_active() -> bool:
	return state != State.DORMANT


func update(dt: float, elapsed: float, ship_pos: Vector2, ship_vel: Vector2, hunting: bool) -> String:
	var event := ""
	timer = maxf(0.0, timer - dt)
	var to_ship := ship_pos - pos
	var dist := to_ship.length()
	match state:
		State.DORMANT:
			if elapsed >= spawn_time:
				state = State.PATROL
			return ""
		State.PATROL:
			var to_home := home - pos
			var orbit := to_home.orthogonal().normalized() * 40.0
			vel = vel.move_toward(to_home.limit_length(60.0) + orbit, 40.0 * dt)
			if hunting and dist < DETECT_RANGE:
				state = State.CHASE
				event = "spotted"
		State.CHASE:
			var target := ship_pos + ship_vel * 0.6
			var desired := (target - pos).normalized() * CHASE_MAX
			vel = vel.move_toward(desired, CHASE_ACCEL * dt)
			if hunting and dist < CLAMP_RANGE:
				state = State.CLAMPED
				hits = 0
				event = "clamped"
		State.CLAMPED:
			vel = vel.move_toward(Vector2.ZERO, 120.0 * dt)
			if dist > TETHER_REST:
				vel += to_ship.normalized() * (dist - TETHER_REST) * 0.4 * dt
			if not hunting:
				state = State.STUNNED
				timer = 1.0
			elif dist > TETHER_SNAP:
				state = State.STUNNED
				timer = SNAP_STUN
				hits = 0
				event = "snapped"
		State.STUNNED:
			vel = vel.move_toward(Vector2.ZERO, 60.0 * dt)
			if timer <= 0.0:
				state = State.CHASE
				event = "recovered"
	pos += vel * dt
	var face := to_ship.angle() if state == State.CLAMPED else vel.angle()
	if state == State.CLAMPED or vel.length() > 5.0:
		rot = lerp_angle(rot, face, minf(1.0, 4.0 * dt))
	return event


## A bullet hit the barge. Returns "spotted", "broken", "stunned" or "".
func register_hit() -> String:
	if state == State.DORMANT:
		return ""
	hits += 1
	if state == State.PATROL:
		state = State.CHASE
		return "spotted"
	if state == State.CLAMPED and hits >= CLAMP_HITS_TO_BREAK:
		state = State.STUNNED
		timer = BREAK_STUN
		hits = 0
		return "broken"
	if state == State.CHASE and hits >= HITS_TO_STUN:
		state = State.STUNNED
		timer = HIT_STUN
		hits = 0
		return "stunned"
	return ""


## Tether pull on the ship (an acceleration; never pre-multiplied by dt).
func tether_accel(ship_pos: Vector2) -> Vector2:
	if state != State.CLAMPED:
		return Vector2.ZERO
	var d := pos - ship_pos
	var length := d.length()
	if length <= TETHER_REST:
		return Vector2.ZERO
	return d / length * (length - TETHER_REST) * TETHER_K
