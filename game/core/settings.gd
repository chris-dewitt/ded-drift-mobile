extends Node
## Autoload "Settings" (loads first). Player toggles + crash breadcrumbs.
##
## Safe-mode toggles: CRT shader and sound are the two riskiest native systems
## (GPU screen-texture pass, background audio synthesis), so either can be
## switched off from the title screen.
##
## Crash breadcrumb: a lock file exists while the app is in the foreground.
## If it is still there at the next launch, the last session died, and the
## title screen shows the tail of the previous log so it can be screenshotted.

const PATH := "user://settings.json"
const LOCK := "user://session.lock"
const MAX_BYTES := 16 * 1024

var crt := true
var sound := true
var last_session_crashed := false
var last_log_tail: Array[String] = []
## Consecutive crashed sessions. Escalates safe mode automatically:
## 1 crash -> CRT off, 2+ crashes -> sound off too. Reset by a clean session.
var crash_streak := 0
var auto_safe_note := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	last_session_crashed = FileAccess.file_exists(LOCK)
	if last_session_crashed:
		last_log_tail = _previous_log_tail(14)
		crash_streak += 1
		if crash_streak >= 1 and crt:
			crt = false
			auto_safe_note = "Safe mode: CRT effect switched OFF automatically."
		if crash_streak >= 2 and sound:
			sound = false
			auto_safe_note = "Safe mode: CRT and SOUND switched OFF automatically."
		_save()
	_write_lock()


## Called once the player has been playing a while without a crash.
func mark_session_healthy() -> void:
	if crash_streak != 0:
		crash_streak = 0
		_save()


## Clean shutdown (any platform): not a crash.
func _exit_tree() -> void:
	_clear_lock()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			_clear_lock()
		NOTIFICATION_APPLICATION_RESUMED:
			_write_lock()


func set_crt(on: bool) -> void:
	crt = on
	_save()


func set_sound(on: bool) -> void:
	sound = on
	_save()
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master, not on)


func dismiss_crash() -> void:
	last_session_crashed = false


func _write_lock() -> void:
	var f := FileAccess.open(LOCK, FileAccess.WRITE)
	if f != null:
		f.store_string(Time.get_datetime_string_from_system())
		f.close()


var _healthy_timer := 0.0


func _process(delta: float) -> void:
	if crash_streak > 0:
		_healthy_timer += delta
		if _healthy_timer > 120.0:
			mark_session_healthy()


func _clear_lock() -> void:
	if FileAccess.file_exists(LOCK):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK))


## The newest rotated log in user://logs is the previous session's.
func _previous_log_tail(lines: int) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("user://logs")
	if dir == null:
		return out
	var newest := ""
	for f in dir.get_files():
		if f.ends_with(".log") and f != "godot.log" and f > newest:
			newest = f
	if newest.is_empty():
		return out
	var text := FileAccess.get_file_as_string("user://logs/" + newest)
	var all := text.strip_edges().split("\n")
	for i in range(maxi(0, all.size() - lines), all.size()):
		out.append(all[i].left(140))
	return out


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var text := FileAccess.get_file_as_string(PATH)
	if text.length() > MAX_BYTES:
		return
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = json.data
	crt = d.get("crt", true) == true
	sound = d.get("sound", true) == true
	var streak = d.get("crash_streak", 0)
	crash_streak = clampi(int(streak), 0, 99) if (typeof(streak) == TYPE_FLOAT or typeof(streak) == TYPE_INT) else 0


func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"crt": crt, "sound": sound, "crash_streak": crash_streak}))
		f.close()
