extends Control
## Flight HUD: top bar (hull, credits, sector, gate timer), Bax pill,
## off-screen barge arrows, first-sector tutorial, and the pause / sector
## cleared / death invoice / chapter overlays.
## Diegetic degradation: frame flicker under 60% hull, decorative text
## scramble under 30%. Numbers and prompts you act on never scramble.

const Screen := preload("res://game/ui/screen.gd")
const Fmt := preload("res://game/core/fmt.gd")

const CYAN := Color(0.25, 0.88, 0.82)
const AMBER := Color(1.0, 0.70, 0.28)
const RED := Color(1.0, 0.32, 0.28)
const MAGENTA := Color(1.0, 0.28, 0.78)
const DIM := Color(0.55, 0.60, 0.65)
const WHITE := Color(1, 1, 1)
const BAX_CPS := 45.0
const BAX_HOLD := 4.5

var flight  # the flight scene (untyped to avoid a preload cycle)
var resume_rect := Rect2()
var quit_rect := Rect2()

var _font: Font
var _bax_text := ""
var _bax_age := 99.0
var _bax_shown := 0
var _audio: Node


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_audio = get_node_or_null("/root/Audio")


func show_bax(line: String) -> void:
	_bax_text = line
	_bax_age = 0.0
	_bax_shown = 0


func bax_text() -> String:
	return _bax_text


func _process(delta: float) -> void:
	_bax_age += delta
	# Bax's voice: a blip every couple of typed characters.
	var shown := mini(_bax_text.length(), int(_bax_age * BAX_CPS))
	if shown > _bax_shown:
		if _audio != null and shown / 2 != _bax_shown / 2 and _bax_text[shown - 1] != " ":
			_audio.bax_blip()
		_bax_shown = shown


func _draw() -> void:
	if flight == null:
		return
	var safe := Screen.safe_rect(get_viewport())
	_draw_damage(safe)
	_draw_top_bar(safe)
	_draw_bax(safe)
	_draw_indicators(safe)
	if flight.run.sector == 1 and flight.elapsed < 9.0 and flight.is_playing():
		_draw_tutorial(safe)
	if flight.paused:
		_draw_pause(safe)
	elif flight.is_cleared():
		_draw_cleared(safe)
	elif flight.is_dead():
		_draw_dead(safe)


func _text(pos: Vector2, s: String, size: int, color: Color, width := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_font, pos, s, align, width, size, color)


func _draw_damage(_safe: Rect2) -> void:
	if flight.damage_flash <= 0.0:
		return
	var a := clampf(flight.damage_flash * 2.0, 0.0, 0.6)
	draw_rect(get_viewport_rect(), Color(RED, a), false, 18.0)


func _draw_top_bar(safe: Rect2) -> void:
	var hull: float = flight.run.hull
	var x := safe.position.x + 16.0
	var y := safe.position.y + 12.0
	var flicker := hull < 60.0 and randf() < (0.10 if hull >= 30.0 else 0.22)
	var bar_color := CYAN if hull > 60.0 else (AMBER if hull > 30.0 else RED)
	var strip := Rect2(0, 0, get_viewport_rect().size.x, safe.position.y + 52.0)
	draw_rect(strip, Color(0.0, 0.0, 0.0, 0.55))
	draw_line(Vector2(0, strip.end.y), Vector2(strip.end.x, strip.end.y), Color(CYAN, 0.18 if not flicker else 0.05), 2.0)
	# Hull bar
	_text(Vector2(x, y + 18), "HULL", 16, DIM)
	var bar := Rect2(x + 50.0, y + 4.0, 180.0, 16.0)
	if not flicker:
		draw_rect(bar, Color(bar_color, 0.8), false, 2.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(hull / 100.0, 0.0, 1.0), bar.size.y)), bar_color)
	_text(Vector2(bar.end.x + 8.0, y + 18), str(ceili(hull)), 18, bar_color)
	# Credits
	var total: int = flight.run.credits + flight.sector_credits
	_text(Vector2(x + 290.0, y + 18), "CR " + Fmt.cr(total), 18, AMBER)
	# Sector + name (name is decorative, so it scrambles at low hull)
	var name_text: String = flight.cfg["name"]
	if hull < 30.0:
		name_text = _scramble(name_text)
	_text(Vector2(safe.position.x, y + 18), "SECTOR %d/5 · %s" % [flight.run.sector, name_text], 18, DIM,
		safe.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# Gate timer
	var gate_x := safe.end.x - 330.0
	if flight.jump_ready:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
		_text(Vector2(gate_x, y + 18), "GATE OPEN · JUMP", 20, Color(CYAN, 0.6 + 0.4 * pulse))
	else:
		_text(Vector2(gate_x, y + 18), "GATE " + Fmt.clock(flight.time_left), 20, CYAN)
	if flight.ship.overdrive > 0.0:
		_text(Vector2(x + 290.0, y + 42), "OVERDRIVE", 16, CYAN)


func _scramble(s: String) -> String:
	var glyphs := "#%&@$*/?"
	var out := ""
	for c in s:
		out += glyphs[randi() % glyphs.length()] if (c != " " and randf() < 0.35) else c
	return out


func _draw_bax(safe: Rect2) -> void:
	if _bax_text.is_empty() or _bax_age > BAX_HOLD + 0.5:
		return
	var alpha := clampf((BAX_HOLD + 0.5 - _bax_age) / 0.5, 0.0, 1.0)
	var w := minf(560.0, safe.size.x * 0.46)
	var full := _font.get_multiline_string_size(_bax_text, HORIZONTAL_ALIGNMENT_LEFT, w - 68.0, 18)
	var box := Rect2(safe.position.x + 16.0, safe.position.y + 62.0, w, maxf(44.0, full.y + 20.0))
	var shown := _bax_text.substr(0, int(_bax_age * BAX_CPS))
	draw_rect(box, Color(0, 0, 0, 0.7 * alpha))
	draw_rect(box, Color(AMBER, alpha), false, 2.0)
	_text(box.position + Vector2(12, 22), "BAX", 16, Color(AMBER, alpha))
	draw_multiline_string(_font, box.position + Vector2(56, 22), shown, HORIZONTAL_ALIGNMENT_LEFT,
		w - 68.0, 18, -1, Color(WHITE, alpha))


func _draw_indicators(safe: Rect2) -> void:
	if not flight.is_playing():
		return
	var to_screen: Transform2D = flight.get_global_transform_with_canvas()
	var inner := safe.grow(-40.0)
	for b in flight.barges:
		if b.is_active():
			_indicator(to_screen * b.pos, inner, flight.ship.pos.distance_to(b.pos), "404", RED)
	for r in flight.raiders:
		if r.active and not r.dead:
			_indicator(to_screen * r.pos, inner, flight.ship.pos.distance_to(r.pos), "KRB", MAGENTA)


func _indicator(p: Vector2, inner: Rect2, world_dist: float, tag: String, color: Color) -> void:
	if inner.has_point(p):
		return
	var dir := (p - inner.get_center()).normalized()
	var edge := Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y + 90.0, inner.end.y))
	var tri := PackedVector2Array([edge + dir * 16.0, edge + dir.rotated(2.5) * 13.0, edge + dir.rotated(-2.5) * 13.0])
	draw_colored_polygon(tri, color)
	_text(edge - dir * 30.0 + Vector2(-20, 6), "%s %dm" % [tag, int(world_dist / 10.0)], 14, color)


func _draw_tutorial(safe: Rect2) -> void:
	var lines := [
		"LEFT THUMB: AIM  ·  RIGHT THUMB: THRUST",
		"RETRO slows you down",
		"Guns AUTO-FIRE at whatever you aim at",
		"Survive till the GATE opens, then JUMP",
	]
	# Bottom centre, between the thumbs: never over the ship (screen centre).
	var w := minf(480.0, safe.size.x * 0.36)
	var box := Rect2(safe.get_center().x - w * 0.5, safe.end.y - 128.0, w, 112.0)
	var fade := clampf((9.0 - flight.elapsed) / 1.0, 0.0, 1.0)
	draw_rect(box, Color(0, 0, 0, 0.6 * fade))
	draw_rect(box, Color(CYAN, 0.35 * fade), false, 1.5)
	for i in lines.size():
		_text(Vector2(box.position.x, box.position.y + 26.0 + 24.0 * i), lines[i], 16, Color(CYAN, fade),
			box.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _panel(safe: Rect2, title: String, title_color: Color, lines: Array, prompt: String) -> Rect2:
	draw_rect(get_viewport_rect(), Color(0, 0, 0, 0.72))
	var box := Rect2(safe.get_center().x - 380.0, safe.get_center().y - 190.0, 760.0, 380.0)
	draw_rect(box, Color(0.03, 0.035, 0.05, 0.95))
	draw_rect(box, title_color, false, 2.0)
	_text(Vector2(box.position.x, box.position.y + 62.0), title, 44, title_color, box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	for i in lines.size():
		_text(Vector2(box.position.x, box.position.y + 120.0 + 36.0 * i), lines[i], 22, WHITE,
			box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if prompt != "":
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
		_text(Vector2(box.position.x, box.end.y - 30.0), prompt, 24, Color(CYAN, 0.5 + 0.5 * pulse),
			box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	return box


func _draw_pause(safe: Rect2) -> void:
	var box := _panel(safe, "PAUSED", CYAN, ["Quitting forfeits this sector's salvage."], "")
	resume_rect = Rect2(box.position.x + 60.0, box.end.y - 150.0, 300.0, 90.0)
	quit_rect = Rect2(box.end.x - 360.0, box.end.y - 150.0, 300.0, 90.0)
	for pair in [[resume_rect, "RESUME", CYAN], [quit_rect, "QUIT TO TITLE", AMBER]]:
		var r: Rect2 = pair[0]
		var c: Color = pair[2]
		draw_rect(r, Color(c, 0.15))
		draw_rect(r, c, false, 2.0)
		_text(Vector2(r.position.x, r.position.y + 56.0), pair[1], 26, c, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_cleared(safe: Rect2) -> void:
	var r: Dictionary = flight.result
	if r.get("chapter", false):
		_panel(safe, "CHAPTER 1 COMPLETE", AMBER, [
			"All five sectors survived.",
			"Payout applied to debt: %s CR" % Fmt.cr(int(r.get("payout", 0))),
			"Debt remaining: %s CR" % Fmt.cr(int(r.get("debt", 0))),
			"Docking + delivery corridor come in a later build.",
		], "TAP TO RETURN TO TITLE")
	elif r.get("terminal", false):
		_panel(safe, "SECTOR %d CLEARED" % int(r.get("sector", 0)), CYAN, [
			"Salvage this sector: %s CR" % Fmt.cr(int(r.get("salvage", 0))),
			"Run credits: %s CR" % Fmt.cr(flight.run.credits),
			"!! INCOMING TRANSMISSION !!",
			"Someone wants a word before the next jump.",
		], "TAP TO ANSWER")
	else:
		_panel(safe, "SECTOR %d CLEARED" % int(r.get("sector", 0)), CYAN, [
			"Salvage this sector: %s CR" % Fmt.cr(int(r.get("salvage", 0))),
			"Run credits: %s CR" % Fmt.cr(flight.run.credits),
			"Hull: %d" % ceili(flight.run.hull),
			"Next: Sector %d" % flight.run.sector,
		], "TAP TO CONTINUE")


func _draw_dead(safe: Rect2) -> void:
	var r: Dictionary = flight.result
	_panel(safe, "DECANTING INVOICE", RED, [
		"Clone #%d decanted. Nova Soma thanks you." % int(r.get("clone", 0)),
		"Decanting fee: %s CR added to debt" % Fmt.cr(int(r.get("fee", 0))),
		"Debt: %s CR" % Fmt.cr(int(r.get("debt", 0))),
		"Next run restarts at Sector %d" % int(r.get("retry_sector", 1)),
	], "TAP TO CONTINUE")
