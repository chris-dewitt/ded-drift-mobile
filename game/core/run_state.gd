extends Node
## Autoload "RunState": the current run (sector, hull, run credits) plus meta
## progression (debt, clones, chapters), which persists to user://meta.json
## through SaveSchema. Mid-sector checkpoints are not implemented yet (M.3).

const SaveSchema := preload("res://game/core/save_schema.gd")

const HULL_MAX := 100.0
const SECTORS := 5
const DEATH_FEES := [0, 6000, 9000, 13000, 18000, 24000]  # by sector reached
const CHAPTER_PAYOUT := 30000
const JUMPS_PER_TERMINAL := 3

var save_path := "user://meta.json"
var meta: Dictionary = SaveSchema.default_meta()
var sector := 1
var hull := HULL_MAX
var credits := 0
## Where to go after a terminal: "flight" (next sector) or "title" (chapter done).
var after_terminal := "flight"
## Set by a terminal security alarm: next sector's barges start hunting at once.
var barges_alerted := false


func _ready() -> void:
	load_meta()


## Called from the title screen. Full hull, no run credits, and the sector
## you died on (or sector 1 after a finished chapter).
func start_run() -> void:
	hull = HULL_MAX
	credits = 0


func complete_sector() -> Dictionary:
	var cleared := sector
	meta["jumps"] = int(meta["jumps"]) + 1
	var terminal := int(meta["jumps"]) % JUMPS_PER_TERMINAL == 0
	if sector < SECTORS:
		sector += 1
		after_terminal = "flight"
		save_meta()
		return {"chapter": false, "sector": cleared, "terminal": terminal}
	var payout := CHAPTER_PAYOUT + credits
	meta["debt"] = int(meta["debt"]) - payout
	meta["chapters_completed"] = int(meta["chapters_completed"]) + 1
	sector = 1
	credits = 0
	hull = HULL_MAX
	after_terminal = "title"
	save_meta()
	return {"chapter": true, "sector": cleared, "payout": payout, "debt": int(meta["debt"]),
		"terminal": terminal}


func die() -> Dictionary:
	var fee: int = DEATH_FEES[clampi(sector, 1, SECTORS)]
	meta["debt"] = int(meta["debt"]) + fee
	meta["clones"] = int(meta["clones"]) + 1
	credits = 0
	hull = HULL_MAX
	save_meta()
	return {"fee": fee, "clone": int(meta["clones"]), "debt": int(meta["debt"]), "retry_sector": sector}


## Which NPC answers the next terminal (rotates through the roster).
func terminal_index() -> int:
	return int(meta["terminals"])


## Apply a finished terminal's results. Numbers come from the rule engine.
func finish_terminal(credit_delta: int, debt_delta: int, hull_delta: float, alarm: bool) -> void:
	if after_terminal == "title" and credit_delta > 0:
		# Chapter is over and run credits are already banked: winnings pay debt.
		meta["debt"] = int(meta["debt"]) - credit_delta + debt_delta
	else:
		credits = maxi(0, credits + credit_delta)
		meta["debt"] = int(meta["debt"]) + debt_delta
	hull = clampf(hull + hull_delta, 1.0, HULL_MAX)
	meta["terminals"] = int(meta["terminals"]) + 1
	barges_alerted = barges_alerted or alarm
	save_meta()


## Atomic write: temp file, then rename over the real save.
func save_meta() -> bool:
	meta = SaveSchema.sanitize_meta(meta)
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("meta save failed: %s" % FileAccess.get_open_error())
		return false
	f.store_string(SaveSchema.to_json(meta))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(save_path))
	if err != OK:
		push_warning("meta save rename failed: %s" % err)
		return false
	return true


func load_meta() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var result := SaveSchema.parse(FileAccess.get_file_as_string(save_path))
	meta = result["meta"]
	if not result["ok"]:
		push_warning("meta save rejected (%s); starting fresh" % result["error"])
