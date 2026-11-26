extends Node
## Autoload "RunState": the current run (sector, hull, run credits) plus meta
## progression (debt, clones, chapters), which persists to user://meta.json
## through SaveSchema. Mid-sector checkpoints are not implemented yet (M.3).

const SaveSchema := preload("res://game/core/save_schema.gd")

const HULL_MAX := 100.0
const SECTORS := 5
const DEATH_FEES := [0, 6000, 9000, 13000, 18000, 24000]  # by sector reached
const CHAPTER_PAYOUT := 30000

var save_path := "user://meta.json"
var meta: Dictionary = SaveSchema.default_meta()
var sector := 1
var hull := HULL_MAX
var credits := 0


func _ready() -> void:
	load_meta()


## Called from the title screen. Full hull, no run credits, and the sector
## you died on (or sector 1 after a finished chapter).
func start_run() -> void:
	hull = HULL_MAX
	credits = 0


func complete_sector() -> Dictionary:
	var cleared := sector
	if sector < SECTORS:
		sector += 1
		return {"chapter": false, "sector": cleared}
	var payout := CHAPTER_PAYOUT + credits
	meta["debt"] = int(meta["debt"]) - payout
	meta["chapters_completed"] = int(meta["chapters_completed"]) + 1
	sector = 1
	credits = 0
	hull = HULL_MAX
	save_meta()
	return {"chapter": true, "sector": cleared, "payout": payout, "debt": int(meta["debt"])}


func die() -> Dictionary:
	var fee: int = DEATH_FEES[clampi(sector, 1, SECTORS)]
	meta["debt"] = int(meta["debt"]) + fee
	meta["clones"] = int(meta["clones"]) + 1
	credits = 0
	hull = HULL_MAX
	save_meta()
	return {"fee": fee, "clone": int(meta["clones"]), "debt": int(meta["debt"]), "retry_sector": sector}


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
