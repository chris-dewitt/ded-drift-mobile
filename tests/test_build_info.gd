extends "res://tests/test_case.gd"

const BuildInfo := preload("res://game/core/build_info.gd")


func test_label_has_version_and_build() -> void:
	var label := BuildInfo.label()
	assert_true(label.begins_with("v" + BuildInfo.VERSION), "label starts with version")
	assert_true(label.contains(BuildInfo.BUILD), "label contains build")


func test_version_matches_project_settings() -> void:
	assert_eq(BuildInfo.VERSION, str(ProjectSettings.get_setting("application/config/version")),
		"build_info VERSION vs project.godot")
