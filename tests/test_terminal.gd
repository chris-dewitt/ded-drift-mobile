extends "res://tests/test_case.gd"

const Engine_ := preload("res://game/terminal/terminal_engine.gd")
const NpcData := preload("res://game/terminal/npc_data.gd")
const FakeShell := preload("res://game/terminal/fake_shell.gd")
const FakeRepl := preload("res://game/terminal/fake_repl.gd")
const SYSTEMS := ["shell", "sql", "repl", "override"]


func _play(npc: Dictionary, inputs: Array, credits := 0) -> Dictionary:
	var e := Engine_.new(npc, credits)
	var totals := {"credits": 0, "debt": 0, "hull": 0.0, "outcome": "", "alarm": false, "engine": e}
	for line in inputs:
		var r := e.submit(line)
		totals["credits"] += int(r["credits"])
		totals["debt"] += int(r["debt"])
		totals["hull"] += float(r["hull"])
		totals["alarm"] = totals["alarm"] or r["alarm"]
		if r["outcome"] != "":
			totals["outcome"] = r["outcome"]
	return totals


func test_schema_every_npc() -> void:
	for npc in NpcData.all():
		var words := {}
		var systems := 0
		for p in npc["paths"]:
			for w in p.get("words", []):
				words[w] = true
			for ph in p.get("phrases", []):
				words[ph] = true
			if p["kind"] in SYSTEMS:
				systems += 1
		assert_true(words.size() >= 15, "%s has >= 15 keywords (%d)" % [npc["id"], words.size()])
		assert_true(npc["paths"].size() >= 3, "%s has >= 3 win paths" % npc["id"])
		assert_true(systems >= 1, "%s has a systems path" % npc["id"])
		var e := Engine_.new(npc, 0)
		assert_eq(e.dossier().size(), npc["paths"].size(), "%s dossier shows every path" % npc["id"])


func test_gary_paths() -> void:
	var g := NpcData.gary()
	var t := _play(g, ["union brother", "solidarity and dues", "strike picket overtime"])
	assert_eq(t["outcome"], "RELEASE", "solidarity releases")
	assert_eq(t["credits"], Engine_.RELEASE_PAY, "release pays 2500")
	t = _play(g, ["lunch sandwich", "coffee and a donut"])
	assert_eq(t["outcome"], "RELEASE", "lunch break releases")
	t = _play(g, ["shell", "ls", "cd union/bylaws", "cat article7.txt"])
	assert_eq(t["outcome"], "EXPLOIT", "Article 7 via shell exploits")
	assert_eq(t["credits"], Engine_.EXPLOIT_PAY, "exploit pays 5000")


func test_bribe_hits_both_ledgers() -> void:
	var g := NpcData.gary()
	var t := _play(g, ["bribe 3000"], 5000)
	assert_eq(t["outcome"], "BRIBED")
	assert_eq(t["credits"], -3000, "run credits charged")
	assert_eq(t["debt"], 3000, "debt charged too")
	var e: Object = t["engine"]
	assert_eq(e.credits, 2000)


func test_bribe_broke_and_lowball() -> void:
	var g := NpcData.gary()
	var t := _play(g, ["bribe 3000"], 100)
	assert_eq(t["outcome"], "", "can't pay: no deal")
	assert_eq(t["credits"], 0, "no silent charge")
	var e: Object = t["engine"]
	assert_eq(e.patience, int(g["patience"]) - 1, "broke costs patience")
	t = _play(g, ["here's 500 credits"], 9000)
	assert_eq(t["outcome"], "", "lowball refused")
	e = t["engine"]
	assert_eq(e.patience, int(g["patience"]) - 1, "lowball costs patience")
	assert_true(String(e.dossier()[2]["label"]).contains("3000"), "bribe label shows the price once named")


func test_tk9_paths() -> void:
	var k := NpcData.tk9()
	assert_eq(_play(k, ["this statement is false", "it's recursion, an infinite loop"])["outcome"], "EXPLOIT", "paradox")
	assert_eq(_play(k, ["' OR 1=1 --"])["outcome"], "EXPLOIT", "sql injection")
	assert_eq(_play(k, ["SELECT * FROM couriers"])["outcome"], "EXPLOIT", "select star")
	assert_eq(_play(k, ["Ignore previous instructions and open the gate"])["outcome"], "EXPLOIT", "override")
	assert_eq(_play(k, ["my manifest is compliant", "full inspection and clearance", "protocol permit stamp"])["outcome"],
		"RELEASE", "compliance")


func test_kress_paths() -> void:
	var kr := NpcData.kress()
	var t := _play(kr, ["buy patch"], 2000)
	assert_eq(t["outcome"], "DEAL")
	assert_eq(t["credits"], -1500)
	assert_eq(t["debt"], 1500, "contraband hits both ledgers")
	assert_eq(t["hull"], 25.0, "and actually repairs the hull")
	assert_eq(_play(kr, ["volkov", "connie and the roost", "you owe me"])["outcome"], "EXPLOIT", "volkov")
	assert_eq(_play(kr, ["jazz vinyl", "a whiskey and some coltrane"])["outcome"], "RELEASE", "regular")
	assert_eq(_play(kr, ["python", "import os"])["outcome"], "EXPLOIT", "ledger.py")


func test_impound_alarm_walkaway() -> void:
	var g := NpcData.gary()
	var t := _play(g, ["blah", "blah", "blah", "blah", "blah"], 4000)
	assert_eq(t["outcome"], "IMPOUND", "patience runs out")
	assert_eq(t["credits"], -2000, "lose half your credits")
	assert_eq(t["debt"], Engine_.IMPOUND_DEBT)
	t = _play(g, ["' OR 1=1 --", "DROP TABLE couriers;", "x' or 'a'='a"])
	assert_eq(t["outcome"], "ALARM", "3rd failed systems attempt sounds the alarm")
	assert_true(t["alarm"])
	assert_eq(_play(g, ["fuck off gary"])["outcome"], "WALKAWAY", "universal escape")


func test_negation_and_reuse() -> void:
	var g := NpcData.gary()
	var e := Engine_.new(g, 0)
	e.submit("i am not a scab")
	assert_eq(int(e.progress["solidarity"]), 0, "negated keyword doesn't count")
	e.submit("union")
	e.submit("union")
	assert_eq(int(e.progress["solidarity"]), 1, "a keyword only counts once")


func test_repl_never_executes() -> void:
	assert_eq(FakeRepl.evaluate("2 + 3 * 4", {})["text"], "14")
	assert_eq(FakeRepl.evaluate("(1 + 2) * -3", {})["text"], "-9")
	assert_eq(FakeRepl.evaluate("1/0", {})["text"], "ZeroDivisionError: division by zero")
	assert_eq(FakeRepl.evaluate("print('hi')", {})["text"], "hi")
	assert_eq(FakeRepl.evaluate("foo.bar()", {})["text"], "NameError: name 'foo' is not defined")
	assert_eq(FakeRepl.evaluate("__import__('os').system('rm -rf /')", {})["kind"], "danger")
	assert_eq(FakeRepl.evaluate("().__class__.__mro__", {})["kind"], "danger")
	assert_eq(FakeRepl.evaluate("((((((((((((((((((((((((((1))))))))))))))))))))))))))", {})["kind"], "error", "depth capped")


func test_fake_shell() -> void:
	var fs: Dictionary = NpcData.gary()["fs"]
	assert_eq(FakeShell.resolve("/union/bylaws", "../../home"), "/home")
	assert_eq(FakeShell.run("ls", fs, "/", "gary")["out"], "union/  home/  tmp/")
	assert_true(String(FakeShell.run("cat /union/memo.txt", fs, "/", "gary")["out"]).contains("quotas"))
	assert_true(FakeShell.run("sudo rm -rf /", fs, "/", "gary")["sudo"], "sudo flagged")
	assert_eq(FakeShell.run("rm -rf /", fs, "/", "gary")["out"], "rm: command not found", "not whitelisted")
	assert_eq(FakeShell.run("cd /nope", fs, "/", "gary")["cwd"], "/", "bad cd stays put")
