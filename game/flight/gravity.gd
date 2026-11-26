extends RefCounted
## Gravity wells: softened inverse-square pull. Returns an acceleration to
## feed into ShipBody.add_force() (never pre-multiplied by dt).

const G := 1.1e6
const SOFTEN := 70.0


static func well_accel(body_pos: Vector2, well_pos: Vector2, mass: float) -> Vector2:
	var d := well_pos - body_pos
	var r2 := d.length_squared() + SOFTEN * SOFTEN
	if d == Vector2.ZERO:
		return Vector2.ZERO
	return d.normalized() * (G * mass / r2)
