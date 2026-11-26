extends Node
## Autoload "Audio". Renders the procedural soundtrack + SFX on a background
## thread at startup, then plays them. Until rendering finishes every call is a
## silent no-op, so the game never waits on audio.
##
## Moods crossfade the music layers:
##   calm     bed + pulse                (open flight)
##   chase    bed + pulse + tension      (something is hunting you)
##   terminal terminal bells            (negotiations)
##   title    bed only
##   silent   nothing but tape hum

const Synth := preload("res://game/audio/synth.gd")

const LAYERS := ["bed", "pulse", "tension", "terminal"]
const MOODS := {
	"calm": {"bed": 0.0, "pulse": -4.0},
	"chase": {"bed": -2.0, "pulse": 0.0, "tension": -1.0},
	"terminal": {"terminal": 0.0},
	"title": {"bed": -1.0},
	"silent": {},
}
const SILENT_DB := -60.0
const FADE_DB_PER_SEC := 30.0
const SFX_VOICES := 10

var is_ready := false
var music_db := -6.0
var sfx_db := -3.0

var _thread: Thread
var _layers := {}  # name -> AudioStreamPlayer
var _layer_db := {}  # name -> current dB
var _mood := "title"
var _sfx := {}  # name -> AudioStreamWAV
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _thrust: AudioStreamPlayer
var _thrust_on := false
var _hum: AudioStreamPlayer
var _music_bus := -1
var _lowpass: AudioEffectLowPassFilter
var _blip_cooldown := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_thread = Thread.new()
	_thread.start(_render)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _setup_buses() -> void:
	_music_bus = AudioServer.bus_count
	AudioServer.add_bus(_music_bus)
	AudioServer.set_bus_name(_music_bus, "Music")
	AudioServer.set_bus_send(_music_bus, "Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(_music_bus, _lowpass)
	var sfx_bus := AudioServer.bus_count
	AudioServer.add_bus(sfx_bus)
	AudioServer.set_bus_name(sfx_bus, "SFX")
	AudioServer.set_bus_send(sfx_bus, "Master")


## Background thread: pure sample math only, no scene-tree access.
func _render() -> void:
	var pcm := {}
	pcm["bed"] = Synth.to_pcm(Synth.render_pad())
	pcm["pulse"] = Synth.to_pcm(Synth.render_pulse())
	pcm["tension"] = Synth.to_pcm(Synth.render_tension())
	pcm["terminal"] = Synth.to_pcm(Synth.render_terminal())
	pcm["hum"] = Synth.to_pcm(Synth.render_hum())
	var sfx: Dictionary = Synth.render_sfx()
	var sfx_pcm := {}
	for key in sfx:
		sfx_pcm[key] = Synth.to_pcm(sfx[key])
	_on_rendered.call_deferred(pcm, sfx_pcm)


func _on_rendered(pcm: Dictionary, sfx_pcm: Dictionary) -> void:
	for layer in LAYERS:
		var p := AudioStreamPlayer.new()
		p.stream = Synth.make_stream(pcm[layer], true)
		p.bus = "Music"
		p.volume_db = SILENT_DB
		add_child(p)
		_layers[layer] = p
		_layer_db[layer] = SILENT_DB
	for layer in LAYERS:  # start together so the layers stay in sync
		_layers[layer].play()
	_hum = AudioStreamPlayer.new()
	_hum.stream = Synth.make_stream(pcm["hum"], true)
	_hum.bus = "Music"
	_hum.volume_db = -20.0
	add_child(_hum)
	_hum.play()
	for key in sfx_pcm:
		_sfx[key] = Synth.make_stream(sfx_pcm[key], key == "thrust_loop")
	for _i in SFX_VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = "SFX"
		add_child(v)
		_voices.append(v)
	_thrust = AudioStreamPlayer.new()
	_thrust.stream = _sfx["thrust_loop"]
	_thrust.bus = "SFX"
	_thrust.volume_db = SILENT_DB
	add_child(_thrust)
	_thrust.play()
	is_ready = true


func _process(delta: float) -> void:
	_blip_cooldown = maxf(0.0, _blip_cooldown - delta)
	if not is_ready:
		return
	var targets: Dictionary = MOODS.get(_mood, {})
	for layer in LAYERS:
		var target: float = (targets[layer] + music_db) if targets.has(layer) else SILENT_DB
		var cur: float = _layer_db[layer]
		cur = move_toward(cur, target, FADE_DB_PER_SEC * delta)
		_layer_db[layer] = cur
		_layers[layer].volume_db = cur
	var thrust_target := -8.0 + sfx_db if _thrust_on else SILENT_DB
	_thrust.volume_db = move_toward(_thrust.volume_db, thrust_target, 120.0 * delta)


func set_mood(mood: String) -> void:
	if MOODS.has(mood):
		_mood = mood


func mood() -> String:
	return _mood


func set_thrust(on: bool) -> void:
	_thrust_on = on


## Hull 0..100. Below 60 the music gets muffled, like hearing it through a
## cracked canopy.
func set_hull(hull: float) -> void:
	if _lowpass == null:
		return
	var t := clampf(hull / 60.0, 0.0, 1.0)
	_lowpass.cutoff_hz = lerpf(700.0, 20000.0, t * t)


func play(sound: String, volume_db := 0.0, pitch := 1.0, jitter := 0.04) -> void:
	if not is_ready or not _sfx.has(sound):
		return
	var v := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	v.stream = _sfx[sound]
	v.volume_db = volume_db + sfx_db
	v.pitch_scale = maxf(0.1, pitch * (1.0 + randf_range(-jitter, jitter)))
	v.play()


## Bax's voice: a tiny pitched square blip per few typed characters.
func bax_blip() -> void:
	if _blip_cooldown > 0.0:
		return
	_blip_cooldown = 0.055
	play("bax%d" % (randi() % 4), -6.0, 1.0, 0.08)
