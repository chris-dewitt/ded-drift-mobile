extends CanvasLayer
## Full-screen CRT post-process on top of everything (game, HUD, controls).
## Add one per screen: add_child(CrtOverlay.new()).

const SHADER := preload("res://assets/shaders/crt.gdshader")

var _rect: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	layer = 100


func _ready() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and not settings.crt:
		return  # safe mode: no screen-texture pass at all
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)


func set_glitch(amount: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("glitch", clampf(amount, 0.0, 1.0))


func set_intensity(amount: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("intensity", clampf(amount, 0.0, 1.0))
