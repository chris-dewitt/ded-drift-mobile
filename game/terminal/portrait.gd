extends RefCounted
## Procedural CRT portraits for terminal NPCs, drawn in vector neon inside a
## scanlined screen. `talking` animates the mouth while their line types out.

const Neon := preload("res://game/ui/neon.gd")


static func draw(ci: CanvasItem, rect: Rect2, face: String, color: Color, talking: bool, time: float) -> void:
	ci.draw_rect(rect, Color(0.02, 0.025, 0.03))
	var c := rect.get_center() + Vector2(0, 10)
	var glitch := 0.0
	if fmod(time, 5.3) > 5.1:
		glitch = sin(time * 90.0) * 6.0
	c.x += glitch
	var mouth := (0.5 + 0.5 * sin(time * 22.0)) if talking else 0.0
	match face:
		"gary":
			_gary(ci, c, color, mouth, time)
		"tk9":
			_tk9(ci, c, color, mouth, time)
		"kress":
			_kress(ci, c, color, mouth, time)
	var y := rect.position.y
	while y < rect.end.y:
		ci.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0, 0, 0, 0.35), 1.0)
		y += 3.0
	ci.draw_rect(rect, Color(color, 0.12), false, 8.0)
	ci.draw_rect(rect, color, false, 2.0)


static func _circle_pts(c: Vector2, rx: float, ry: float, n := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		var a := TAU * k / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _gary(ci: CanvasItem, c: Vector2, col: Color, mouth: float, time: float) -> void:
	# shoulders
	Neon.polyline(ci, PackedVector2Array([c + Vector2(-80, 85), c + Vector2(-50, 55), c + Vector2(50, 55), c + Vector2(80, 85)]), col, 2.0)
	Neon.body(ci, _circle_pts(c, 48, 54), col, Color(0.06, 0.05, 0.04), 2.0)
	# union cap
	Neon.body(ci, PackedVector2Array([c + Vector2(-50, -28), c + Vector2(-44, -62), c + Vector2(44, -62), c + Vector2(50, -28), c + Vector2(-50, -28)]), col, Color(0.12, 0.08, 0.03), 2.0)
	Neon.line(ci, c + Vector2(-50, -28), c + Vector2(70, -24), col, 2.0)
	ci.draw_string(ThemeDB.fallback_font, c + Vector2(-16, -38), "404", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
	# tired eyes
	var blink := fmod(time, 4.0) > 3.85
	for sx in [-1.0, 1.0]:
		var e := c + Vector2(18 * sx, -6)
		if blink:
			ci.draw_line(e + Vector2(-7, 0), e + Vector2(7, 0), col, 2.0)
		else:
			Neon.glow_dot(ci, e, 3.0, col)
			ci.draw_line(e + Vector2(-9, -6), e + Vector2(9, -4), col, 2.0)
	# mustache + mouth
	Neon.polyline(ci, PackedVector2Array([c + Vector2(-22, 22), c + Vector2(-8, 14), c + Vector2(0, 17), c + Vector2(8, 14), c + Vector2(22, 22)]), col, 3.0)
	ci.draw_colored_polygon(_circle_pts(c + Vector2(0, 30), 10, 1.0 + mouth * 7.0, 16), Color(0.0, 0.0, 0.0))
	ci.draw_polyline(_circle_pts(c + Vector2(0, 30), 10, 1.0 + mouth * 7.0, 16), col, 1.5)


static func _tk9(ci: CanvasItem, c: Vector2, col: Color, mouth: float, time: float) -> void:
	Neon.polyline(ci, PackedVector2Array([c + Vector2(-70, 85), c + Vector2(-40, 60), c + Vector2(40, 60), c + Vector2(70, 85)]), col, 2.0)
	var head := PackedVector2Array([c + Vector2(-46, -50), c + Vector2(46, -50), c + Vector2(52, 40), c + Vector2(-52, 40), c + Vector2(-46, -50)])
	Neon.body(ci, head, col, Color(0.03, 0.06, 0.07), 2.0)
	Neon.line(ci, c + Vector2(0, -50), c + Vector2(0, -74), col, 1.5)
	Neon.glow_dot(ci, c + Vector2(0, -76), 3.0, Color(1.0, 0.3, 0.3) if int(time * 2.0) % 2 == 0 else col)
	# visor with scanning eye
	ci.draw_rect(Rect2(c + Vector2(-36, -20), Vector2(72, 16)), Color(0, 0, 0))
	ci.draw_rect(Rect2(c + Vector2(-36, -20), Vector2(72, 16)), col, false, 1.5)
	var eye_x := sin(time * 2.2) * 28.0
	Neon.glow_dot(ci, c + Vector2(eye_x, -12), 5.0, Color(1.0, 0.3, 0.3))
	# speaker grille flashes while talking
	for k in 4:
		var w := 30.0 if mouth <= 0.0 else 16.0 + mouth * 24.0 * (1.0 if k % 2 == 0 else 0.6)
		ci.draw_line(c + Vector2(-w * 0.5, 14 + k * 6), c + Vector2(w * 0.5, 14 + k * 6), Color(col, 0.9), 2.0)
	ci.draw_string(ThemeDB.fallback_font, c + Vector2(-46, 56), "TK-9", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col, 0.7))


static func _kress(ci: CanvasItem, c: Vector2, col: Color, mouth: float, time: float) -> void:
	Neon.polyline(ci, PackedVector2Array([c + Vector2(-78, 85), c + Vector2(-30, 58), c + Vector2(0, 75), c + Vector2(30, 58), c + Vector2(78, 85)]), col, 2.0)
	Neon.body(ci, _circle_pts(c + Vector2(0, 4), 36, 56), col, Color(0.06, 0.03, 0.05), 2.0)
	# fedora
	Neon.line(ci, c + Vector2(-64, -36), c + Vector2(64, -40), col, 2.5)
	Neon.body(ci, PackedVector2Array([c + Vector2(-38, -37), c + Vector2(-30, -72), c + Vector2(0, -64), c + Vector2(30, -72), c + Vector2(38, -39), c + Vector2(-38, -37)]), col, Color(0.08, 0.03, 0.06), 2.0)
	# narrow eyes
	for sx in [-1.0, 1.0]:
		ci.draw_line(c + Vector2(14 * sx - 8, -8), c + Vector2(14 * sx + 8, -10), col, 2.5)
	# smirk
	var m := PackedVector2Array([c + Vector2(-14, 30), c + Vector2(2, 32 + mouth * 6.0), c + Vector2(16, 26)])
	Neon.polyline(ci, m, col, 2.0)
	# cigarette + smoke
	var tip := c + Vector2(34, 32)
	ci.draw_line(c + Vector2(14, 28), tip, Color(0.9, 0.9, 0.9), 3.0)
	Neon.glow_dot(ci, tip, 2.5, Color(1.0, 0.45, 0.1) if fmod(time, 1.7) > 0.4 else Color(1.0, 0.8, 0.3))
	for k in 3:
		var t := fmod(time * 0.6 + k * 0.33, 1.0)
		var p := tip + Vector2(sin(t * 9.0 + k) * 8.0, -t * 60.0)
		ci.draw_circle(p, 3.0 + t * 6.0, Color(0.8, 0.8, 0.9, 0.18 * (1.0 - t)))
