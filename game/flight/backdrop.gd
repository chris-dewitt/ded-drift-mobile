extends RefCounted
## "Futuristic corporate hellscape" backdrop, drawn in world space with
## parallax: industrial smog, floating arcology slabs with lit windows and
## blinking spires, and flickering corporate ad billboards.
## An element with parallax p appears to move at p x the camera's speed.

const SLOGANS := [
	["NOVA SOMA", "DEBT IS A JOURNEY"],
	["LOCAL 404", "WE REPO SO YOU DON'T HAVE TO"],
	["CLONE TODAY", "PAY FOREVER"],
	["SOMACOLA", "TASTE THE COMPLIANCE"],
	["NOVA SOMA FINANCIAL", "YOUR LIFE. OUR ASSET."],
	["DECANT-U", "2ND BODY 50% OFF*"],
	["COMPLIANCE IS FREEDOM", "REPORT IRREGULAR COURIERS"],
	["KRESS & SON", "NO QUESTIONS. SOME ANSWERS."],
]
const SMOG_COLORS := [Color(0.55, 0.08, 0.45), Color(0.05, 0.38, 0.45), Color(0.45, 0.22, 0.05)]
const NEON := [Color(1.0, 0.28, 0.78), Color(0.25, 0.92, 0.86), Color(1.0, 0.70, 0.28)]


static func generate(sector: int, world: Rect2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + sector * 77
	var smog := []
	for i in 7:
		smog.append({
			"pos": Vector2(rng.randf_range(-800, world.size.x * 0.4 + 800), rng.randf_range(-400, world.size.y * 0.4 + 400)),
			"r": rng.randf_range(260.0, 520.0),
			"color": SMOG_COLORS[i % SMOG_COLORS.size()],
		})
	var slabs := []
	for i in 9:
		var w := rng.randf_range(90.0, 180.0)
		var h := rng.randf_range(260.0, 620.0)
		var windows := []
		for _k in int(w * h / 1800.0):
			windows.append(Vector3(rng.randf_range(8, w - 12), rng.randf_range(20, h - 10), rng.randf()))
		slabs.append({
			"pos": Vector2(rng.randf_range(-200, world.size.x * 0.55), rng.randf_range(-100, world.size.y * 0.55)),
			"size": Vector2(w, h),
			"windows": windows,
			"spire": rng.randf_range(40.0, 140.0),
			"blink": rng.randf() * TAU,
		})
	var boards := []
	var order := range(SLOGANS.size())
	for i in 5:
		var pick: int = order[(sector * 3 + i) % order.size()]
		boards.append({
			"pos": Vector2(rng.randf_range(100, world.size.x * 0.7), rng.randf_range(80, world.size.y * 0.7)),
			"text": SLOGANS[pick],
			"color": NEON[(i + sector) % NEON.size()],
			"phase": rng.randf() * 10.0,
		})
	return {"smog": smog, "slabs": slabs, "boards": boards}


static func _place(anchor: Vector2, centre: Vector2, parallax: float) -> Vector2:
	return anchor + centre * (1.0 - parallax)


static func draw(ci: CanvasItem, data: Dictionary, centre: Vector2, view: Vector2, time: float, font: Font) -> void:
	var screen := Rect2(centre - view * 0.5, view).grow(200.0)
	# Smog (very far)
	for s in data["smog"]:
		var p := _place(s["pos"], centre, 0.12)
		var r: float = s["r"]
		if not screen.grow(r).has_point(p):
			continue
		var c: Color = s["color"]
		for k in 5:
			ci.draw_circle(p, r * (1.0 - k * 0.17), Color(c, 0.035))
	# Arcology slabs (far)
	for slab in data["slabs"]:
		var p := _place(slab["pos"], centre, 0.28)
		var size: Vector2 = slab["size"]
		if not screen.intersects(Rect2(p, size).grow(150.0)):
			continue
		ci.draw_rect(Rect2(p, size), Color(0.035, 0.04, 0.06))
		ci.draw_rect(Rect2(p, size), Color(0.18, 0.2, 0.28, 0.6), false, 1.5)
		for wdw in slab["windows"]:
			var lit: bool = fmod(wdw.z * 50.0 + time * 0.05, 1.0) > 0.25
			if lit:
				var wc := Color(1.0, 0.75, 0.35, 0.55) if wdw.z > 0.4 else Color(0.3, 0.9, 0.9, 0.45)
				ci.draw_rect(Rect2(p + Vector2(wdw.x, wdw.y), Vector2(5, 3)), wc)
		var spire_top := p + Vector2(size.x * 0.5, -float(slab["spire"]))
		ci.draw_line(p + Vector2(size.x * 0.5, 0), spire_top, Color(0.25, 0.27, 0.35), 2.0)
		if sin(time * 2.5 + float(slab["blink"])) > 0.3:
			ci.draw_circle(spire_top, 4.0, Color(1.0, 0.2, 0.2, 0.9))
			ci.draw_circle(spire_top, 10.0, Color(1.0, 0.2, 0.2, 0.15))
	# Billboards (mid)
	for b in data["boards"]:
		var p := _place(b["pos"], centre, 0.5)
		var rect := Rect2(p, Vector2(420, 130))
		if not screen.intersects(rect):
			continue
		var c: Color = b["color"]
		var t := time + float(b["phase"])
		var flicker := 1.0
		if fmod(t, 7.0) > 6.6:
			flicker = 0.25 if int(t * 30.0) % 2 == 0 else 1.0
		ci.draw_rect(rect, Color(c.r * 0.08, c.g * 0.08, c.b * 0.08, 0.85))
		ci.draw_rect(rect, Color(c, 0.12 * flicker), false, 10.0)
		ci.draw_rect(rect, Color(c, 0.9 * flicker), false, 2.0)
		var lines: Array = b["text"]
		ci.draw_string(font, rect.position + Vector2(0, 58), lines[0], HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x, 38, Color(c, flicker))
		ci.draw_string(font, rect.position + Vector2(0, 98), lines[1], HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x, 20, Color(1, 1, 1, 0.75 * flicker))
		for k in 6:  # scan bars rolling over the ad
			var y := rect.position.y + fposmod(t * 40.0 + k * 22.0, rect.size.y)
			ci.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0, 0, 0, 0.25), 2.0)
