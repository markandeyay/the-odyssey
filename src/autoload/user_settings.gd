extends Node
## User-owned machine settings, persisted outside the save file
## (`user://settings.cfg`). The first of these is the internal 3D render
## scale: the human rejected WORLD's 0.85 project-wide default — the game
## defaults to native (1.0, bilinear), and the measured 0.85 performance
## tier is an opt-in. A future settings menu writes through the setters
## here; nothing else touches the viewport's scaling.

const SETTINGS_PATH: String = "user://settings.cfg"
const RENDER_SCALE_MIN: float = 0.5
const RENDER_SCALE_MAX: float = 1.0

## Internal 3D resolution as a fraction of output. UI is unaffected.
var render_scale: float = 1.0


func _ready() -> void:
	_load()
	_apply_render_scale()


func set_render_scale(scale: float) -> void:
	render_scale = clampf(scale, RENDER_SCALE_MIN, RENDER_SCALE_MAX)
	_apply_render_scale()
	_save()


func _apply_render_scale() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = render_scale


func _load() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	render_scale = clampf(
		float(config.get_value("video", "render_scale", 1.0)),
		RENDER_SCALE_MIN, RENDER_SCALE_MAX
	)


func _save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("video", "render_scale", render_scale)
	config.save(SETTINGS_PATH)
