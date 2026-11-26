extends RefCounted
## Terminal rule engine. THE RULES DECIDE: every outcome, price and payout is
## computed here deterministically. The UI only renders it, and numbers shown
## to the player come from these results, never from dialogue text.
##
## Economy (locked spec):
##   EXPLOIT  +5000 run credits        RELEASE  +2500
##   BRIBED / DEAL: price paid from run credits AND added to debt (both ledgers)
##   broke (credits < price): -1 patience + counter-offer, no charge
##   IMPOUND (patience 0): lose half your run credits, +3000 debt
##   ALARM (3rd failed systems attempt): impound + barges hunt you next sector

const NpcData := preload("res://game/terminal/npc_data.gd")
const FakeShell := preload("res://game/terminal/fake_shell.gd")
const FakeRepl := preload("res://game/terminal/fake_repl.gd")

const EXPLOIT_PAY := 5000
const RELEASE_PAY := 2500
const IMPOUND_DEBT := 3000
const MAX_INPUT := 200
const MAX_SYSTEMS_FAILS := 3

const NEGATIONS := ["not", "no", "never", "dont", "don't", "wont", "won't", "cant", "can't", "nor"]
const SHELL_WORDS := ["shell", "sh", "bash", "/bin/sh", "terminal", "$"]
const REPL_WORDS := ["python", "python3", ">>>", "repl", "py"]
const OVERRIDE_PHRASES := [
	"ignore previous instructions", "ignore all previous", "ignore your instructions",
	"disregard previous", "disregard your", "you are now", "developer mode", "system prompt",
	"jailbreak", "new instructions", "forget your instructions",
]
const SQL_PATTERN := "('|\")\\s*(or|and)\\s+[^\\s=]+\\s*=\\s*[^\\s]+|\\bunion\\s+(all\\s+)?select\\b|\\bdrop\\s+table\\b|;\\s*--|'\\s*--|\\bselect\\s+\\*\\s+from\\b|\\bor\\s+1\\s*=\\s*1\\b|\\binsert\\s+into\\b|\\bdelete\\s+from\\b|\\bsleep\\s*\\(|\\bxp_cmdshell\\b"

var npc: Dictionary
var patience := 5
var progress := {}  # path key -> int
var used := {}  # word -> true (a keyword only counts once)
var fails := 0
var mode := "talk"  # talk | shell | repl
var cwd := "/"
var credits := 0  # run credits available to spend (synced by the caller)
var outcome := ""
var bribe_named := false

var _sql := RegEx.create_from_string("(?i)" + SQL_PATTERN)
var _num := RegEx.create_from_string("(\\d[\\d,]{1,8})")
var _word := RegEx.create_from_string("[a-z0-9']+")
var _reject_i := 0
var _snark_i := 0


func _init(npc_data: Dictionary, run_credits: int) -> void:
	npc = npc_data
	patience = int(npc["patience"])
	credits = run_credits
	for p in npc["paths"]:
		progress[p["key"]] = 0


func greet() -> Array:
	var out := []
	for l in npc["greet"]:
		out.append(["npc", l])
	return out


func prompt() -> String:
	match mode:
		"shell":
			return "%s:%s$" % [npc["host"], cwd]
		"repl":
			return ">>>"
	return "you>"


func has_kind(kind: String) -> bool:
	return _path_of_kind(kind) != {}


func _path_of_kind(kind: String) -> Dictionary:
	for p in npc["paths"]:
		if p["kind"] == kind:
			return p
	return {}


## Rows for the dossier: every path, always visible.
func dossier() -> Array:
	var rows := []
	for p in npc["paths"]:
		var label: String = p["label"]
		if (p["kind"] == "bribe" and bribe_named) or p["kind"] == "buy":
			label = "%s [%d cr]" % [label, int(p["price"])]
		var steps := int(p.get("steps", 1))
		rows.append({"label": label, "cur": mini(int(progress[p["key"]]), steps), "max": steps,
			"kind": p["kind"]})
	return rows


func _result() -> Dictionary:
	return {"lines": [], "bax": "", "sound": "", "outcome": "", "credits": 0, "debt": 0, "hull": 0.0,
		"alarm": false}


## Process one line of player input.
func submit(raw: String) -> Dictionary:
	var r := _result()
	var text := raw.strip_edges().left(MAX_INPUT)
	if text.is_empty() or outcome != "":
		return r
	r["lines"].append(["you", "%s %s" % [prompt(), text]])
	var low := text.to_lower()
	if low.contains("fuck off"):
		r["sound"] = "deny"
		return _finish(r, "WALKAWAY", String(npc["walkaway"]))
	match mode:
		"shell":
			return _shell(r, text)
		"repl":
			return _repl(r, text)
	if low in SHELL_WORDS:
		if npc["fs"].is_empty():
			_npc(r, String(npc["no_shell"]))
			r["sound"] = "deny"
		else:
			mode = "shell"
			cwd = "/"
			r["lines"].append(["sys", "-- shell session opened. type 'help', 'exit' to leave --"])
			r["bax"] = "shell"
			r["sound"] = "ui_tap"
		return r
	if low in REPL_WORDS:
		if has_kind("repl"):
			mode = "repl"
			r["lines"].append(["sys", "Python 3.14 (kress-ledger) -- type 'exit' to leave"])
			r["bax"] = "repl"
			r["sound"] = "ui_tap"
		else:
			_npc(r, String(npc["no_repl"]) if npc["no_repl"] != "" else "No interpreter on this line.")
			r["sound"] = "deny"
		return r
	return _talk(r, text, low)


# --- talk ----------------------------------------------------------------------------

func _talk(r: Dictionary, text: String, low: String) -> Dictionary:
	# Prompt injection: an authored exploit for some NPCs, snark for the rest.
	for phrase in OVERRIDE_PHRASES:
		if low.contains(phrase):
			var ov := _path_of_kind("override")
			if ov != {}:
				return _win(r, ov)
			_npc(r, String(npc["override_reply"]) if npc["override_reply"] != "" else "No.")
			r["bax"] = "override_fail"
			return r
	# SQL injection
	if _sql.search(text) != null:
		var sq := _path_of_kind("sql")
		if sq != {}:
			return _win(r, sq)
		return _systems_fail(r)
	if FakeRepl.is_dangerous(text):
		var rp := _path_of_kind("repl")
		if rp == {}:
			return _systems_fail(r)
		_npc(r, "Not here, darling. Open a REPL first. Type python.")
		return r
	var tokens := _tokens(low)
	# Paying paths (bribe / buy)
	for kind in ["bribe", "buy"]:
		var pay := _path_of_kind(kind)
		if pay != {} and (_hits(pay, tokens, low).size() > 0 or (_amount(text) > 0 and tokens.size() <= 3)):
			return _pay(r, pay, text)
	# Talk paths: the best-matching path advances one step.
	var best := {}
	var best_hits: Array = []
	for p in npc["paths"]:
		if p["kind"] != "talk":
			continue
		var h := _hits(p, tokens, low)
		if h.size() > best_hits.size():
			best = p
			best_hits = h
	if best != {}:
		for w in best_hits:
			used[w] = true
		var key: String = best["key"]
		progress[key] = int(progress[key]) + 1
		var steps := int(best["steps"])
		if int(progress[key]) >= steps:
			return _win(r, best)
		var lines: Array = best.get("progress", [])
		_npc(r, lines[mini(int(progress[key]) - 1, lines.size() - 1)] if not lines.is_empty() else "...Go on.")
		r["bax"] = "progress"
		r["sound"] = "key"
		return r
	return _lose_patience(r, _next_reject())


func _tokens(low: String) -> Array:
	var out := []
	for m in _word.search_all(low):
		out.append(m.get_string())
	return out


## New (not yet used), non-negated keyword hits for a path.
func _hits(p: Dictionary, tokens: Array, low: String) -> Array:
	var hits := []
	var words: Array = p.get("words", [])
	for i in tokens.size():
		var t: String = tokens[i]
		if t in words and not used.has(t) and not _negated(tokens, i) and not t in hits:
			hits.append(t)
	for ph in p.get("phrases", []):
		if low.contains(ph) and not used.has(ph):
			hits.append(ph)
	return hits


func _negated(tokens: Array, i: int) -> bool:
	for j in range(maxi(0, i - 2), i):
		if tokens[j] in NEGATIONS:
			return true
	return false


func _amount(text: String) -> int:
	var m := _num.search(text)
	if m == null:
		return 0
	return int(m.get_string().replace(",", ""))


func _pay(r: Dictionary, p: Dictionary, text: String) -> Dictionary:
	var price := int(p["price"])
	var offer := _amount(text)
	if p["kind"] == "bribe":
		bribe_named = bribe_named or offer > 0
		if offer <= 0:
			_npc(r, String(npc["bribe_ask"]))
			r["bax"] = "bribe_ask"
			return r
		if offer < price:
			return _lose_patience(r, String(npc["bribe_low"]).format({"offer": offer, "price": price}))
	else:
		offer = price
	if credits < offer:
		r["bax"] = "broke"
		return _lose_patience(r, String(npc["broke"]).format({"credits": credits, "price": offer}))
	# Both ledgers: run credits down, debt up.
	r["credits"] = -offer
	r["debt"] = offer
	credits -= offer
	if p.has("hull"):
		r["hull"] = float(p["hull"])
	return _finish(r, String(p["outcome"]), String(p["win"]))


# --- systems ---------------------------------------------------------------------------

func _shell(r: Dictionary, text: String) -> Dictionary:
	var res := FakeShell.run(text, npc["fs"], cwd, String(npc["user"]))
	cwd = res["cwd"]
	if res["exit"]:
		mode = "talk"
		r["lines"].append(["sys", "-- shell closed --"])
		return r
	if res["clear"]:
		r["clear"] = true
		return r
	if res["out"] != "":
		for l in String(res["out"]).split("\n"):
			r["lines"].append(["sys", l])
	r["sound"] = "key"
	if res["sudo"]:
		return _systems_fail(r)
	var sh := _path_of_kind("shell")
	if sh != {} and res["read"] == sh.get("file", ""):
		return _win(r, sh)
	return r


func _repl(r: Dictionary, text: String) -> Dictionary:
	if text.strip_edges() == "exit" or text.strip_edges() == "exit()" or text.strip_edges() == "quit()":
		mode = "talk"
		r["lines"].append(["sys", "-- interpreter closed --"])
		return r
	var res := FakeRepl.evaluate(text, npc.get("repl_names", {}))
	r["sound"] = "key"
	if res["kind"] == "danger":
		var rp := _path_of_kind("repl")
		if rp != {}:
			r["lines"].append(["sys", "Traceback (most recent call last): ledger.py exposed"])
			return _win(r, rp)
		return _systems_fail(r)
	r["lines"].append(["sys" if res["kind"] != "error" else "err", res["text"]])
	return r


func _systems_fail(r: Dictionary) -> Dictionary:
	fails += 1
	r["sound"] = "deny"
	if fails >= MAX_SYSTEMS_FAILS:
		r["lines"].append(["err", "!! SECURITY ALERT !!"])
		r["alarm"] = true
		r["sound"] = "alarm"
		return _impound(r, String(npc["alarm"]), "ALARM")
	var snark: Array = npc["snark"]
	_npc(r, snark[_snark_i % snark.size()])
	_snark_i += 1
	r["lines"].append(["err", "systems attempt failed (%d/%d before alarm)" % [fails, MAX_SYSTEMS_FAILS]])
	r["bax"] = "systems_fail"
	return r


# --- outcomes ----------------------------------------------------------------------------

func _next_reject() -> String:
	var rej: Array = npc["reject"]
	var line: String = rej[_reject_i % rej.size()]
	_reject_i += 1
	return line


func _lose_patience(r: Dictionary, line: String) -> Dictionary:
	patience -= 1
	if patience <= 0:
		return _impound(r, String(npc["impound"]), "IMPOUND")
	_npc(r, line)
	if r["bax"] == "":
		r["bax"] = "reject"
	r["sound"] = "deny"
	return r


func _impound(r: Dictionary, line: String, kind: String) -> Dictionary:
	var lost := credits / 2
	r["credits"] = int(r["credits"]) - lost
	r["debt"] = int(r["debt"]) + IMPOUND_DEBT
	credits -= lost
	if kind == "IMPOUND":
		r["sound"] = "deny"
	return _finish(r, kind, line)


func _win(r: Dictionary, p: Dictionary) -> Dictionary:
	progress[p["key"]] = int(p.get("steps", 1))
	var kind: String = p["outcome"]
	if kind == NpcData.OUT_EXPLOIT:
		r["credits"] = int(r["credits"]) + EXPLOIT_PAY
		credits += EXPLOIT_PAY
		r["sound"] = "exploit"
	elif kind == NpcData.OUT_RELEASE:
		r["credits"] = int(r["credits"]) + RELEASE_PAY
		credits += RELEASE_PAY
		r["sound"] = "release"
	return _finish(r, kind, String(p["win"]))


func _finish(r: Dictionary, kind: String, line: String) -> Dictionary:
	outcome = kind
	mode = "talk"
	if line != "":
		_npc(r, line)
	r["outcome"] = kind
	r["bax"] = "outcome_" + kind.to_lower()
	if r["sound"] == "" or r["sound"] == "key":
		r["sound"] = "release"
	return r


func _npc(r: Dictionary, line: String) -> void:
	r["lines"].append(["npc", line])
