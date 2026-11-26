extends RefCounted
## Python REPL that accepts real syntax but NEVER executes anything.
##   - dangerous patterns (import os, dunder escapes, eval/exec, pickle...)
##     are detected structurally and reported as "danger"
##   - plain arithmetic is evaluated by a tiny recursive-descent parser
##     written here (no Expression class, no eval)
##   - print("text") echoes its literal
##   - anything else gets an authentic-looking NameError / SyntaxError

const MAX_LEN := 160
const MAX_DEPTH := 24

const DANGER := [
	"import os", "import sys", "import subprocess", "import socket", "import ctypes", "import pickle",
	"from os", "from subprocess", "__import__", "__class__", "__subclasses__", "__globals__",
	"__builtins__", "__mro__", "eval(", "exec(", "compile(", "open(", "os.system", "subprocess.",
	"pickle.loads", "getattr(",
]


static func is_dangerous(src: String) -> bool:
	var s := src.to_lower().replace("  ", " ")
	for d in DANGER:
		if s.contains(d):
			return true
	return false


## Returns {"kind": "danger"|"value"|"error"|"name", "text": String}.
## names: Dictionary of identifier -> flavour text for this NPC's REPL.
static func evaluate(src: String, names: Dictionary) -> Dictionary:
	var code := src.strip_edges()
	if code.length() > MAX_LEN:
		return {"kind": "error", "text": "SyntaxError: line too long"}
	if is_dangerous(code):
		return {"kind": "danger", "text": ""}
	var print_re := RegEx.create_from_string("^print\\(\\s*(['\"])(.*)\\1\\s*\\)$")
	var m := print_re.search(code)
	if m != null:
		return {"kind": "value", "text": m.get_string(2)}
	var str_re := RegEx.create_from_string("^(['\"])(.*)\\1$")
	m = str_re.search(code)
	if m != null:
		return {"kind": "value", "text": "'%s'" % m.get_string(2)}
	if names.has(code):
		return {"kind": "name", "text": String(names[code])}
	if RegEx.create_from_string("^[0-9+\\-*/%(). ]+$").search(code) != null:
		var parser := _Parser.new(code)
		var v = parser.parse()
		if parser.error != "":
			return {"kind": "error", "text": parser.error}
		return {"kind": "value", "text": _fmt(v)}
	var ident := RegEx.create_from_string("^[A-Za-z_][A-Za-z0-9_]*").search(code)
	if ident != null:
		return {"kind": "error", "text": "NameError: name '%s' is not defined" % ident.get_string()}
	return {"kind": "error", "text": "SyntaxError: invalid syntax"}


static func _fmt(v: float) -> String:
	if is_equal_approx(v, round(v)) and absf(v) < 1e15:
		return str(int(round(v)))
	return str(v)


class _Parser:
	var src := ""
	var i := 0
	var depth := 0
	var error := ""

	func _init(text: String) -> void:
		src = text.replace(" ", "")

	func parse() -> float:
		var v := _expr()
		if error == "" and i < src.length():
			error = "SyntaxError: invalid syntax"
		return v

	func _peek() -> String:
		return src[i] if i < src.length() else ""

	func _expr() -> float:
		var v := _term()
		while error == "" and (_peek() == "+" or _peek() == "-"):
			var op := _peek()
			i += 1
			var r := _term()
			v = v + r if op == "+" else v - r
		return v

	func _term() -> float:
		var v := _factor()
		while error == "" and (_peek() == "*" or _peek() == "/" or _peek() == "%"):
			var op := _peek()
			i += 1
			var r := _factor()
			if (op == "/" or op == "%") and r == 0.0:
				error = "ZeroDivisionError: division by zero"
				return 0.0
			if op == "*":
				v *= r
			elif op == "/":
				v /= r
			else:
				v = fposmod(v, r)
		return v

	func _factor() -> float:
		depth += 1
		if depth > MAX_DEPTH:
			error = "RecursionError: maximum recursion depth exceeded"
			return 0.0
		var v := 0.0
		var c := _peek()
		if c == "-":
			i += 1
			v = -_factor()
		elif c == "(":
			i += 1
			v = _expr()
			if _peek() != ")":
				error = "SyntaxError: '(' was never closed"
			else:
				i += 1
		else:
			var start := i
			while i < src.length() and (src[i].is_valid_int() or src[i] == "."):
				i += 1
			if start == i:
				error = "SyntaxError: invalid syntax"
			else:
				v = float(src.substr(start, i - start))
		depth -= 1
		return v
