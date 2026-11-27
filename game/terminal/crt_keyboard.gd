extends Control
## On-screen CRT keyboard for terminals: a permanent code row (' " ; - = ( ) *
## / | > _ .), letters, a symbols page, SH / >>> mode keys and SYS KB to switch
## to the phone's own keyboard. Lays itself out inside `area` (canvas coords).

signal typed(text: String)
signal backspace
signal enter
signal special(name: String)  # "sh", "repl", "sys"

const CODE_ROW := ["'", "\"", ";", "-", "=", "(", ")", "*", "/", "|", ">", "_", "."]
const ALPHA := [
	["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", ["DEL", 1.5]],
	["a", "s", "d", "f", "g", "h", "j", "k", "l", ["ENTER", 2.0]],
	[["SHIFT", 1.5], "z", "x", "c", "v", "b", "n", "m", ",", "?", ["123", 1.5]],
	[["SH", 1.5], [">>>", 1.5], ["SPACE", 5.0], ["SYS KB", 2.0]],
]
const SYMBOLS := [
	["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", ["DEL", 1.5]],
	["@", "#", "$", "%", "&", "+", ":", "!", "[", "]", ["ENTER", 2.0]],
	[["ABC", 1.5], "~", "{", "}", "<", "\\", "^", "`", "'", "?", ["ABC", 1.5]],
	[["SH", 1.5], [">>>", 1.5], ["SPACE", 5.0], ["SYS KB", 2.0]],
]

const CYAN := Color(0.25, 0.92, 0.86)
const AMBER := Color(1.0, 0.70, 0.28)
const MAGENTA := Color(1.0, 0.28, 0.78)

var area := Rect2()
var enabled := true
var shift := false
var symbols := false

var _keys: Array = []  # [Rect2, label]
var _pressed := {}  # touch index -> label
var _flash := {}  # label -> seconds of highlight left
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	for k in _flash.keys():
		_flash[k] = float(_flash[k]) - delta
		if _flash[k] <= 0.0:
			_flash.erase(k)
	_layout()
	queue_redraw()


func _layout() -> void:
	_keys.clear()
	if not area.has_area():
		return
	var rows: Array = [CODE_ROW] + (SYMBOLS if symbols else ALPHA)
	var gap := 5.0
	var row_h := (area.size.y - gap * (rows.size() + 1)) / rows.size()
	for r in rows.size():
		var row: Array = rows[r]
		var total := 0.0
		for k in row:
			total += float(k[1]) if k is Array else 1.0
		var unit := (area.size.x - gap * (row.size() + 1)) / total
		var x := area.position.x + gap
		var y := area.position.y + gap + r * (row_h + gap)
		for k in row:
			var label: String = k[0] if k is Array else k
			var w := (float(k[1]) if k is Array else 1.0) * unit
			_keys.append([Rect2(x, y, w, row_h), label])
			x += w + gap


func key_at(pos: Vector2) -> String:
	for k in _keys:
		var r: Rect2 = k[0]
		if r.grow(2.0).has_point(pos):
			return k[1]
	return ""


func _input(event: InputEvent) -> void:
	if not enabled or not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var label := key_at(t.position)
			if label != "":
				_pressed[t.index] = label
				press(label)
				get_viewport().set_input_as_handled()
		else:
			_pressed.erase(t.index)


## Also called by tests to type without touches.
func press(label: String) -> void:
	_flash[label] = 0.12
	match label:
		"DEL":
			backspace.emit()
		"ENTER":
			enter.emit()
		"SHIFT":
			shift = not shift
		"123":
			symbols = true
		"ABC":
			symbols = false
		"SPACE":
			typed.emit(" ")
		"SH":
			special.emit("sh")
		">>>":
			special.emit("repl")
		"SYS KB":
			special.emit("sys")
		_:
			var ch := label.to_upper() if shift else label
			shift = false
			typed.emit(ch)


func _draw() -> void:
	if not visible or not area.has_area():
		return
	draw_rect(area, Color(0.01, 0.015, 0.02, 0.96))
	draw_line(area.position, Vector2(area.end.x, area.position.y), Color(CYAN, 0.4), 2.0)
	for k in _keys:
		var r: Rect2 = k[0]
		var label: String = k[1]
		var lit := _flash.has(label) or (label == "SHIFT" and shift)
		var col := CYAN
		if label in ["SH", ">>>", "SYS KB"]:
			col = MAGENTA
		elif label in ["DEL", "ENTER", "SHIFT", "123", "ABC"]:
			col = AMBER
		elif r.position.y < area.position.y + r.size.y:  # code row
			col = AMBER
		draw_rect(r, Color(col, 0.28 if lit else 0.07))
		draw_rect(r, Color(col, 0.9 if lit else 0.45), false, 1.5)
		var shown := label.to_upper() if (shift and label.length() == 1) else label
		var font_size := 22 if label.length() == 1 else 15
		draw_string(_font, Vector2(r.position.x, r.get_center().y + font_size * 0.35), shown,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size, Color(1, 1, 1, 0.95) if lit else col)
