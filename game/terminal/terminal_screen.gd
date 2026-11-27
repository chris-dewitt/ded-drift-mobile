extends Node2D
## Terminal encounter (every 3rd jump). A retro terminal in a corporate
## hellscape: procedural CRT portrait, transcript, keyword chips, CRT keyboard,
## dossier of every win path, Bax heckling on the left.
##
## THE RULES DECIDE: TerminalEngine owns every outcome and number. This screen
## only renders it and hands the engine's totals to RunState at the end.

const TerminalEngine := preload("res://game/terminal/terminal_engine.gd")
const NpcData := preload("res://game/terminal/npc_data.gd")
const Portrait := preload("res://game/terminal/portrait.gd")
const CrtKeyboard := preload("res://game/terminal/crt_keyboard.gd")
const CrtOverlay := preload("res://game/ui/crt_overlay.gd")
const Backdrop := preload("res://game/flight/backdrop.gd")
const BaxLines := preload("res://game/bax/bax_lines.gd")
const Screen := preload("res://game/ui/screen.gd")
const Fmt := preload("res://game/core/fmt.gd")
const Neon := preload("res://game/ui/neon.gd")

const FLIGHT_SCENE := "res://game/flight/flight.tscn"
const TITLE_SCENE := "res://game/ui/title_screen.tscn"
const NPC_CPS := 70.0
const SYS_CPS := 600.0
const ABORT_HULL := 20.0
const MAX_LINES := 120
const OUTCOME_GUARD := 1.0

const CYAN := Color(0.25, 0.92, 0.86)
const AMBER := Color(1.0, 0.70, 0.28)
const MAGENTA := Color(1.0, 0.28, 0.78)
const RED := Color(1.0, 0.30, 0.26)
const DIM := Color(0.55, 0.60, 0.68)
const WHITE := Color(1, 1, 1)

var run: Node
var audio: Node
var npc: Dictionary
var engine: TerminalEngine
var keyboard: CrtKeyboard
var buffer := ""

## Totals applied to RunState when the call ends.
var total_credits := 0
var total_debt := 0
var total_hull := 0.0
var alarm := false
var finished := false  # outcome reached; waiting for the tap to leave
var outcome := ""

var _lines: Array = []  # revealed [speaker, text]
var _wrap_cache := {}  # "width|text" -> wrapped rows (measuring fonts every frame is slow on phones)
var _queue: Array = []  # pending [speaker, text]
var _typing := 0.0  # chars revealed of the head of _queue
var _bax := ""
var _bax_age := 0.0
var _time := 0.0
var _outcome_age := 0.0
var _scroll := 0.0
var _drag_from := -1.0
var _chip_rects: Array = []  # [Rect2, text]
var _hangup_rect := Rect2()
var _continue_rect := Rect2()
var _sys_edit: LineEdit
var _font: Font
var _mono: Font
var _backdrop := {}
var _cascade: Array = []  # exploit glyph columns


func _ready() -> void:
	run = get_node("/root/RunState")
	audio = get_node_or_null("/root/Audio")
	_font = ThemeDB.fallback_font
	var sys_font := SystemFont.new()
	sys_font.font_names = PackedStringArray(["monospace", "Droid Sans Mono", "DejaVu Sans Mono", "Roboto Mono", "Courier New"])
	_mono = sys_font
	npc = NpcData.by_index(run.terminal_index())
	engine = TerminalEngine.new(npc, run.credits)
	_backdrop = Backdrop.generate(4, Rect2(0, 0, 3600, 2100))
	var layer := CanvasLayer.new()
	add_child(layer)
	keyboard = CrtKeyboard.new()
	layer.add_child(keyboard)
	keyboard.typed.connect(_on_typed)
	keyboard.backspace.connect(_on_backspace)
	keyboard.enter.connect(submit_buffer)
	keyboard.special.connect(_on_special)
	_sys_edit = LineEdit.new()
	_sys_edit.modulate = Color(1, 1, 1, 0.01)
	_sys_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sys_edit.position = Vector2(-4000, -4000)
	_sys_edit.text_changed.connect(func(t: String): buffer = t.left(TerminalEngine.MAX_INPUT))
	_sys_edit.text_submitted.connect(func(_t: String): submit_buffer())
	layer.add_child(_sys_edit)
	add_child(CrtOverlay.new())
	if audio != null:
		audio.set_mood("terminal")
		audio.set_thrust(false)
	_push_lines([["sys", "NOVA SOMA SECURE LINE // ENCRYPTION: DECORATIVE"], ["sys", "connecting to %s ..." % npc["title"]]])
	_push_lines(engine.greet())
	_set_bax(BaxLines.terminal("open"))


# --- input -------------------------------------------------------------------------------

func _on_typed(ch: String) -> void:
	if finished or buffer.length() >= TerminalEngine.MAX_INPUT:
		return
	buffer += ch
	_sfx("key", -10.0)


func _on_backspace() -> void:
	buffer = buffer.left(buffer.length() - 1)
	_sfx("key", -12.0, 0.8)


func _on_special(which: String) -> void:
	match which:
		"sh":
			if engine.mode == "talk":
				buffer = "shell"
				submit_buffer()
		"repl":
			if engine.mode == "talk":
				buffer = "python"
				submit_buffer()
		"sys":
			_sys_edit.text = buffer
			_sys_edit.position = Vector2(0, -4000)
			_sys_edit.grab_focus()
			_sys_edit.caret_column = buffer.length()
			if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
				DisplayServer.virtual_keyboard_show(buffer)


## Send the typed line to the rule engine and render its verdict.
func submit_buffer() -> void:
	if finished:
		return
	var text := buffer
	buffer = ""
	_sys_edit.text = ""
	if text.strip_edges().is_empty():
		return
	var r := engine.submit(text)
	total_credits += int(r["credits"])
	total_debt += int(r["debt"])
	total_hull += float(r["hull"])
	alarm = alarm or bool(r["alarm"])
	if r.get("clear", false):
		_lines.clear()
		_queue.clear()
	_push_lines(r["lines"])
	if r["bax"] != "":
		var line := BaxLines.terminal(String(r["bax"]))
		if line != "":
			_set_bax(line)
	if r["sound"] != "":
		_sfx(String(r["sound"]))
	if r["outcome"] != "":
		_on_outcome(String(r["outcome"]))


func _on_outcome(kind: String) -> void:
	finished = true
	outcome = kind
	_outcome_age = 0.0
	keyboard.enabled = false
	_sys_edit.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	if kind == "EXPLOIT":
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 40:
			_cascade.append(Vector3(rng.randf(), rng.randf() * -1.0, rng.randf_range(0.6, 1.4)))


## Leave the terminal: apply the engine's totals, then fly on (or go home).
func leave() -> void:
	if not finished:
		return
	run.finish_terminal(total_credits, total_debt, total_hull, alarm)
	_sfx("ui_tap")
	if run.after_terminal == "title":
		get_tree().change_scene_to_file(TITLE_SCENE)
	else:
		get_tree().change_scene_to_file(FLIGHT_SCENE)


## Hang up early: costs hull, earns nothing.
func hang_up() -> void:
	if finished:
		return
	total_hull -= ABORT_HULL
	_push_lines([["sys", "-- line cut. the comm array sparks: -%d hull --" % int(ABORT_HULL)]])
	_sfx("hit")
	_on_outcome("HUNG UP")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and not _sys_edit.has_focus():
		var k := event as InputEventKey
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			if finished:
				leave()
			else:
				submit_buffer()
		elif k.keycode == KEY_BACKSPACE:
			_on_backspace()
		elif k.unicode >= 32 and not finished:
			_on_typed(String.chr(k.unicode))
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_tap(touch.position)
		else:
			_drag_from = -1.0
		return
	var drag := event as InputEventScreenDrag
	if drag != null and _drag_from >= 0.0:
		_scroll = maxf(0.0, _scroll + drag.relative.y)


func _tap(pos: Vector2) -> void:
	if finished:
		if _outcome_age > OUTCOME_GUARD:
			leave()
		return
	if _hangup_rect.has_point(pos):
		hang_up()
		return
	for chip in _chip_rects:
		var r: Rect2 = chip[0]
		if r.has_point(pos):
			insert_chip(String(chip[1]))
			return
	if _layout()["transcript"].has_point(pos):
		_drag_from = pos.y


func insert_chip(text: String) -> void:
	if not buffer.is_empty() and not buffer.ends_with(" "):
		buffer += " "
	buffer = (buffer + text).left(TerminalEngine.MAX_INPUT)
	_sfx("ui_tap")


func chips() -> Array:
	match engine.mode:
		"shell":
			return ["ls", "cd ..", "cat ", "pwd", "help", "exit"]
		"repl":
			return ["import os", "2 + 2", "print(\"hi\")", "ledger", "exit"]
	return npc["chips"]


# --- per-frame -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_bax_age += delta
	if finished:
		_outcome_age += delta
	_advance_typing(delta)
	var lay := _layout()
	keyboard.area = lay["keyboard"]
	keyboard.visible = not finished
	queue_redraw()


func _advance_typing(delta: float) -> void:
	if _queue.is_empty():
		return
	var head: Array = _queue[0]
	var cps := NPC_CPS if head[0] == "npc" else SYS_CPS
	var before := int(_typing)
	_typing += cps * delta
	if head[0] == "npc" and int(_typing) > before and int(_typing) % 3 == 0 and audio != null:
		audio.play("bax%d" % (int(_typing) % 4), -10.0, float(npc["voice"]), 0.06)
	if _typing >= String(head[1]).length():
		_lines.append(head)
		_queue.remove_at(0)
		_typing = 0.0
		while _lines.size() > MAX_LINES:
			_lines.remove_at(0)


func _push_lines(lines: Array) -> void:
	for l in lines:
		if l[0] == "you":
			_lines.append(l)  # your own line appears instantly
		else:
			_queue.append(l)
	_scroll = 0.0


func _set_bax(line: String) -> void:
	_bax = line
	_bax_age = 0.0


func _sfx(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if audio != null:
		audio.play(sound, volume_db, pitch)


func is_npc_talking() -> bool:
	return not _queue.is_empty() and _queue[0][0] == "npc"


# --- layout + drawing --------------------------------------------------------------------------

func _layout() -> Dictionary:
	var s := Screen.safe_rect(get_viewport())
	var kb_h := s.size.y * 0.40
	var kb := Rect2(s.position.x, s.end.y - kb_h, s.size.x, kb_h)
	var left := Rect2(s.position.x + 8.0, s.position.y + 50.0, 220.0, kb.position.y - s.position.y - 58.0)
	var right := Rect2(s.end.x - 258.0, s.position.y + 50.0, 250.0, kb.position.y - s.position.y - 58.0)
	var cx := left.end.x + 10.0
	var cw := right.position.x - 10.0 - cx
	var input := Rect2(cx, kb.position.y - 46.0, cw, 40.0)
	var chips_r := Rect2(cx, kb.position.y - 90.0, cw, 38.0)
	var transcript := Rect2(cx, s.position.y + 50.0, cw, chips_r.position.y - 8.0 - (s.position.y + 50.0))
	return {"safe": s, "keyboard": kb, "left": left, "right": right, "input": input, "chips": chips_r,
		"transcript": transcript}


func _draw() -> void:
	var lay := _layout()
	var view := get_viewport_rect()
	var s: Rect2 = lay["safe"]
	draw_rect(view, Color(0.015, 0.018, 0.025))
	Backdrop.draw(self, _backdrop, view.size * 0.5 + Vector2(_time * 6.0, 0), view.size, _time, _font)
	draw_rect(view, Color(0.0, 0.0, 0.0, 0.55))
	_draw_header(s)
	_draw_left(lay["left"])
	_draw_dossier(lay["right"])
	_draw_transcript(lay["transcript"])
	if not finished:
		_draw_chips(lay["chips"])
		_draw_input(lay["input"])
	else:
		_draw_outcome(lay)


func _draw_header(s: Rect2) -> void:
	var col: Color = npc["color"]
	draw_rect(Rect2(0, 0, get_viewport_rect().size.x, s.position.y + 42.0), Color(0, 0, 0, 0.75))
	draw_line(Vector2(0, s.position.y + 42.0), Vector2(get_viewport_rect().size.x, s.position.y + 42.0), Color(col, 0.5), 2.0)
	draw_string(_mono, Vector2(s.position.x + 12, s.position.y + 28), "SECURE LINE // " + String(npc["title"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	var cr_text := "CR " + Fmt.cr(engine.credits)
	draw_string(_mono, Vector2(s.end.x - 520, s.position.y + 28), cr_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, AMBER)
	# patience pips
	var maxp := int(npc["patience"])
	draw_string(_font, Vector2(s.end.x - 380, s.position.y + 28), "PATIENCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	for i in maxp:
		var r := Rect2(s.end.x - 300 + i * 18, s.position.y + 14, 12, 16)
		draw_rect(r, col if i < engine.patience else Color(col, 0.15))
	_hangup_rect = Rect2(s.end.x - 150, s.position.y + 6, 140, 32)
	if not finished:
		draw_rect(_hangup_rect, Color(RED, 0.12))
		draw_rect(_hangup_rect, RED, false, 1.5)
		draw_string(_font, Vector2(_hangup_rect.position.x, _hangup_rect.position.y + 22), "HANG UP -20 HULL",
			HORIZONTAL_ALIGNMENT_CENTER, _hangup_rect.size.x, 13, RED)


func _draw_left(r: Rect2) -> void:
	var col: Color = npc["color"]
	var portrait := Rect2(r.position, Vector2(r.size.x, minf(190.0, r.size.y * 0.62)))
	Portrait.draw(self, portrait, String(npc["face"]), col, is_npc_talking(), _time)
	draw_string(_mono, Vector2(r.position.x, portrait.end.y + 24), String(npc["name"]),
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, col)
	var bax_box := Rect2(r.position.x, portrait.end.y + 34, r.size.x, r.end.y - portrait.end.y - 34)
	if bax_box.size.y < 30.0 or _bax.is_empty():
		return
	draw_rect(bax_box, Color(0, 0, 0, 0.7))
	draw_rect(bax_box, Color(AMBER, 0.7), false, 1.5)
	draw_string(_font, bax_box.position + Vector2(8, 18), "BAX", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AMBER)
	var shown := _bax.substr(0, int(_bax_age * 50.0))
	draw_multiline_string(_font, bax_box.position + Vector2(8, 36), shown, HORIZONTAL_ALIGNMENT_LEFT,
		bax_box.size.x - 16.0, 14, int((bax_box.size.y - 24.0) / 17.0), WHITE)


func _draw_dossier(r: Rect2) -> void:
	draw_rect(r, Color(0, 0, 0, 0.65))
	draw_rect(r, Color(CYAN, 0.35), false, 1.5)
	draw_string(_mono, r.position + Vector2(10, 24), "DOSSIER // WIN PATHS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CYAN)
	var y := r.position.y + 44.0
	var row_h := minf(46.0, (r.size.y - 56.0) / maxf(1.0, engine.dossier().size()))
	for row in engine.dossier():
		var done: bool = int(row["cur"]) >= int(row["max"]) and outcome != ""
		var col := CYAN if not done else AMBER
		var how := _kind_hint(String(row["kind"]))
		draw_string(_font, Vector2(r.position.x + 10, y + 14), String(row["label"]), HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - 20.0, 15, col)
		draw_string(_font, Vector2(r.position.x + 10, y + 30), how, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20.0, 11, DIM)
		var steps := int(row["max"])
		for i in steps:
			var cell := Rect2(r.end.x - 120.0 + i * (110.0 / steps), y + 20, 110.0 / steps - 3.0, 8)
			draw_rect(cell, col if i < int(row["cur"]) else Color(col, 0.15))
		y += row_h


func _kind_hint(kind: String) -> String:
	match kind:
		"talk":
			return "say the right things"
		"bribe":
			return "name your price"
		"buy":
			return "pay for goods"
		"shell":
			return "SYSTEMS: shell (SH)"
		"sql":
			return "SYSTEMS: SQL injection"
		"repl":
			return "SYSTEMS: python (>>>)"
		"override":
			return "SYSTEMS: prompt injection"
	return ""


func _draw_transcript(r: Rect2) -> void:
	draw_rect(r, Color(0.0, 0.02, 0.015, 0.8))
	draw_rect(r, Color(CYAN, 0.25), false, 1.0)
	var font_size := 16
	var line_h := 20.0
	var w := r.size.x - 20.0
	var rows: Array = []  # [text, color] wrapped bottom-up
	var all := _lines.duplicate()
	var typing_index := -1
	if not _queue.is_empty():
		var head: Array = _queue[0]
		typing_index = all.size()
		all.append([head[0], String(head[1]).substr(0, int(_typing)) + ("_" if int(_time * 4.0) % 2 == 0 else "")])
	for li in all.size():
		var l: Array = all[li]
		var col := WHITE
		var prefix := ""
		match String(l[0]):
			"npc":
				col = npc["color"]
				prefix = String(npc["name"]) + ": "
			"you":
				col = CYAN
			"sys":
				col = Color(0.55, 0.95, 0.6)
			"err":
				col = RED
		for wrapped in _wrap(prefix + String(l[1]), w, font_size, li != typing_index):
			rows.append([wrapped, col])
	var visible_rows := int((r.size.y - 12.0) / line_h)
	var max_scroll := maxf(0.0, (rows.size() - visible_rows) * line_h)
	_scroll = minf(_scroll, max_scroll)
	var first := maxi(0, rows.size() - visible_rows - int(_scroll / line_h))
	var y := r.position.y + 20.0
	for i in range(first, mini(rows.size(), first + visible_rows)):
		draw_string(_mono, Vector2(r.position.x + 10, y), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, w, font_size, rows[i][1])
		y += line_h


func _wrap(text: String, width: float, font_size: int, cache := true) -> Array:
	var key := "%d|%s" % [int(width), text]
	if cache and _wrap_cache.has(key):
		return _wrap_cache[key]
	if _wrap_cache.size() > 400:
		_wrap_cache.clear()
	var out: Array = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line.is_empty() else line + " " + word
			if _mono.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not line.is_empty():
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	if cache:
		_wrap_cache[key] = out
	return out


func _draw_chips(r: Rect2) -> void:
	_chip_rects.clear()
	var x := r.position.x
	for c in chips():
		var label := String(c)
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 26.0
		if x + w > r.end.x:
			break
		var chip := Rect2(x, r.position.y, w, r.size.y)
		draw_rect(chip, Color(MAGENTA, 0.10))
		draw_rect(chip, Color(MAGENTA, 0.7), false, 1.5)
		draw_string(_font, Vector2(chip.position.x, chip.get_center().y + 6), label, HORIZONTAL_ALIGNMENT_CENTER,
			chip.size.x, 16, MAGENTA)
		_chip_rects.append([chip, label])
		x += w + 8.0


func _draw_input(r: Rect2) -> void:
	draw_rect(r, Color(0, 0, 0, 0.85))
	draw_rect(r, Color(CYAN, 0.8), false, 1.5)
	var prompt := engine.prompt()
	var caret := "_" if int(_time * 3.0) % 2 == 0 else " "
	var text := "%s %s%s" % [prompt, buffer, caret]
	if buffer.is_empty():
		text = "%s %s   (type, or tap a chip)" % [prompt, caret]
	draw_string(_mono, Vector2(r.position.x + 10, r.position.y + 27), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20.0, 18,
		CYAN if not buffer.is_empty() else Color(CYAN, 0.5))


func _draw_outcome(lay: Dictionary) -> void:
	var kb: Rect2 = lay["keyboard"]
	var col := AMBER
	var title := outcome
	var sub := ""
	match outcome:
		"EXPLOIT":
			col = CYAN
			title = "EXPLOIT // TRANSACTION REROUTED"
		"RELEASE":
			title = "RELEASED"
		"BRIBED":
			title = "PAID OFF"
		"DEAL":
			title = "DEAL DONE"
		"IMPOUND":
			col = RED
			title = "IMPOUNDED"
		"ALARM":
			col = RED
			title = "SECURITY ALARM"
			sub = "Barges hunt you from the first second of the next sector."
		"HUNG UP", "WALKAWAY":
			col = DIM
			title = "LINE DEAD"
	if outcome == "EXPLOIT":
		_draw_cascade()
	draw_rect(kb, Color(0, 0, 0, 0.9))
	draw_rect(kb, Color(col, 0.6), false, 2.0)
	draw_string(_mono, Vector2(kb.position.x, kb.position.y + 56), title, HORIZONTAL_ALIGNMENT_CENTER, kb.size.x, 34, col)
	var parts: Array[String] = []
	if total_credits != 0:
		parts.append("%s%s CR" % ["+" if total_credits > 0 else "", Fmt.cr(total_credits)])
	if total_debt != 0:
		parts.append("DEBT %s%s" % ["+" if total_debt > 0 else "", Fmt.cr(total_debt)])
	if total_hull != 0.0:
		parts.append("HULL %s%d" % ["+" if total_hull > 0 else "", int(total_hull)])
	if parts.is_empty():
		parts.append("no change")
	draw_string(_mono, Vector2(kb.position.x, kb.position.y + 100), "  ·  ".join(PackedStringArray(parts)),
		HORIZONTAL_ALIGNMENT_CENTER, kb.size.x, 22, WHITE)
	if sub != "":
		draw_string(_font, Vector2(kb.position.x, kb.position.y + 134), sub, HORIZONTAL_ALIGNMENT_CENTER, kb.size.x, 16, RED)
	if _outcome_age > OUTCOME_GUARD:
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		draw_string(_font, Vector2(kb.position.x, kb.end.y - 36), "TAP TO CONTINUE", HORIZONTAL_ALIGNMENT_CENTER,
			kb.size.x, 26, Color(CYAN, 0.5 + 0.5 * pulse))


func _draw_cascade() -> void:
	var view := get_viewport_rect().size
	var glyphs := "0123456789ABCDEF#$%&@"
	for c in _cascade:
		var x: float = c.x * view.x
		var head_y := fmod((c.y + _outcome_age * c.z) * view.y, view.y + 200.0)
		for k in 8:
			var ch := glyphs[int(x + k * 7.0 + _time * 20.0) % glyphs.length()]
			var a := clampf(1.0 - k / 8.0, 0.0, 1.0) * clampf(2.5 - _outcome_age, 0.0, 1.0)
			draw_string(_mono, Vector2(x, head_y - k * 18.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(CYAN, a))
