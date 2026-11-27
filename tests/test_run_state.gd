extends "res://tests/test_case.gd"

const RunStateScript := preload("res://game/core/run_state.gd")
const SaveSchema := preload("res://game/core/save_schema.gd")
const PATH := "user://test_run_state_meta.json"


func _fresh() -> Node:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var rs = RunStateScript.new()
	rs.save_path = PATH
	rs.meta = SaveSchema.default_meta()
	return rs


func test_five_sectors_make_a_chapter() -> void:
	var rs := _fresh()
	var debt_before: int = rs.meta["debt"]
	for i in 4:
		assert_false(rs.complete_sector()["chapter"], "sector %d is not the end" % (i + 1))
	assert_eq(rs.sector, 5)
	rs.credits = 1000
	var r: Dictionary = rs.complete_sector()
	assert_true(r["chapter"], "sector 5 ends the chapter")
	assert_eq(int(rs.meta["chapters_completed"]), 1)
	assert_eq(int(rs.meta["debt"]), debt_before - RunStateScript.CHAPTER_PAYOUT - 1000, "payout + credits pay debt")
	assert_eq(rs.sector, 1, "next chapter starts at sector 1")
	rs.free()


func test_death_charges_fee_and_keeps_sector() -> void:
	var rs := _fresh()
	rs.sector = 3
	rs.credits = 500
	var debt_before: int = rs.meta["debt"]
	var r: Dictionary = rs.die()
	assert_eq(int(r["fee"]), RunStateScript.DEATH_FEES[3])
	assert_eq(int(rs.meta["debt"]), debt_before + RunStateScript.DEATH_FEES[3])
	assert_eq(int(rs.meta["clones"]), 1)
	assert_eq(rs.sector, 3, "retry the same sector")
	assert_eq(rs.credits, 0, "run credits lost")
	rs.free()


func test_meta_persists_to_disk() -> void:
	var rs := _fresh()
	rs.sector = 2
	rs.die()
	var again = RunStateScript.new()
	again.save_path = PATH
	again.load_meta()
	assert_eq(again.meta, rs.meta, "meta reloads from disk")
	rs.free()
	again.free()


func test_corrupt_save_loads_defaults() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{\"schema_version\": 1, \"meta\": ")
	f.close()
	var rs = RunStateScript.new()
	rs.save_path = PATH
	rs.load_meta()
	assert_eq(rs.meta, SaveSchema.default_meta(), "corrupt save -> fresh meta, no crash")
	rs.free()


func test_terminal_every_third_jump() -> void:
	var rs := _fresh()
	assert_false(rs.complete_sector()["terminal"], "jump 1")
	assert_false(rs.complete_sector()["terminal"], "jump 2")
	assert_true(rs.complete_sector()["terminal"], "jump 3 brings a terminal")
	assert_eq(rs.after_terminal, "flight")
	rs.credits = 100
	rs.finish_terminal(5000, 0, -20.0, true)
	assert_eq(rs.credits, 5100, "terminal winnings land in run credits")
	assert_eq(rs.hull, RunStateScript.HULL_MAX - 20.0)
	assert_true(rs.barges_alerted, "alarm alerts the next sector")
	assert_eq(int(rs.meta["terminals"]), 1, "next terminal rotates NPC")
	rs.free()

