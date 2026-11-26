extends RefCounted
## Neon drawing helpers: wide faint strokes under a bright core read as glow on
## the GL Compatibility renderer (no HDR bloom needed). Call from inside the
## target CanvasItem's _draw().

const PALETTE := {
	"amber": Color(1.0, 0.70, 0.28),
	"cyan": Color(0.25, 0.92, 0.86),
	"magenta": Color(1.0, 0.28, 0.78),
	"red": Color(1.0, 0.30, 0.26),
	"dim": Color(0.55, 0.60, 0.68),
	"hull": Color(0.05, 0.06, 0.08),
}


static func polyline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width := 2.0) -> void:
	ci.draw_polyline(pts, Color(color, color.a * 0.10), width * 5.0, true)
	ci.draw_polyline(pts, Color(color, color.a * 0.25), width * 2.4, true)
	ci.draw_polyline(pts, color, width, true)


static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width := 2.0) -> void:
	ci.draw_line(a, b, Color(color, color.a * 0.12), width * 5.0, true)
	ci.draw_line(a, b, Color(color, color.a * 0.3), width * 2.4, true)
	ci.draw_line(a, b, color, width, true)


static func ring(ci: CanvasItem, centre: Vector2, radius: float, color: Color, width := 2.0, segments := 48) -> void:
	ci.draw_arc(centre, radius, 0.0, TAU, segments, Color(color, color.a * 0.10), width * 5.0, true)
	ci.draw_arc(centre, radius, 0.0, TAU, segments, Color(color, color.a * 0.25), width * 2.4, true)
	ci.draw_arc(centre, radius, 0.0, TAU, segments, color, width, true)


## Filled dark body with a neon outline. pts must be closed (last == first).
static func body(ci: CanvasItem, pts: PackedVector2Array, outline: Color, fill := Color(0.05, 0.06, 0.08), width := 2.0) -> void:
	var open := pts.slice(0, pts.size() - 1)
	if open.size() >= 3:
		ci.draw_colored_polygon(open, fill)
	polyline(ci, pts, outline, width)


static func glow_dot(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	ci.draw_circle(pos, radius * 3.0, Color(color, color.a * 0.10))
	ci.draw_circle(pos, radius * 1.8, Color(color, color.a * 0.25))
	ci.draw_circle(pos, radius, color)
