extends RefCounted
## Newtonian ship body. No drag, no auto-brake: real momentum.
##
## PHYSICS RULE: forces accumulate through add_force(). Only integrate(dt)
## applies dt. Callers never multiply a force by dt.

const MAX_SPEED := 280.0
const OVERDRIVE_SPEED := 420.0
const OVERSPEED_BLEED := 160.0  # px/s per second lost while above the cap
const THRUST := 240.0
const RETRO_FACTOR := 0.6
const MAX_TURN_RATE := 5.0
const TURN_ACCEL := 26.0
const RADIUS := 14.0

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var rot := 0.0
var turn_rate := 0.0
var overdrive := 0.0  # seconds of raised speed cap remaining

var _force := Vector2.ZERO


func forward() -> Vector2:
	return Vector2.from_angle(rot)


func add_force(force: Vector2) -> void:
	_force += force


func apply_thrust(amount: float) -> void:
	add_force(forward() * THRUST * amount)


func speed_cap() -> float:
	return OVERDRIVE_SPEED if overdrive > 0.0 else MAX_SPEED


## Turn toward a heading with limited angular acceleration (no instant snaps).
## Uses the fastest stop-on-target turn profile so it doesn't overshoot.
func steer_toward(target_angle: float, dt: float) -> void:
	var diff := wrapf(target_angle - rot, -PI, PI)
	var desired := signf(diff) * minf(MAX_TURN_RATE, sqrt(2.0 * TURN_ACCEL * absf(diff)))
	turn_rate = move_toward(turn_rate, desired, TURN_ACCEL * dt)


func steer_hold(dt: float) -> void:
	turn_rate = move_toward(turn_rate, 0.0, TURN_ACCEL * dt)


func integrate(dt: float) -> void:
	var previous_speed := vel.length()
	vel += _force * dt
	# Above the cap (e.g. overdrive just ended) speed bleeds off gradually;
	# thrust alone can never push past the cap.
	var allowed := maxf(speed_cap(), previous_speed - OVERSPEED_BLEED * dt)
	if vel.length() > allowed:
		vel = vel.normalized() * allowed
	pos += vel * dt
	rot = wrapf(rot + turn_rate * dt, -PI, PI)
	overdrive = maxf(0.0, overdrive - dt)
	_force = Vector2.ZERO
