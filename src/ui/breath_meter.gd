class_name BreathMeter
extends Control
## Breath meter, only while underwater (M12). A thin ring at screen center
## that empties clockwise as breath runs out. Sea green while safe; below
## LOW_FRACTION it turns ember and pulses — ember always means danger.
## Fades out within a second of surfacing so the HUD stays empty on land.

const RADIUS: float = 42.0
const WIDTH: float = 5.0
const LOW_FRACTION: float = 0.25
const FADE_IN_SPEED: float = 8.0
const FADE_OUT_SPEED: float = 2.5

var _player: Player = null
var _alpha: float = 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false


func bind(player: Player) -> void:
	_player = player


func _process(delta: float) -> void:
	if _player == null:
		return
	var target: float = 1.0 if _player.is_submerged() else 0.0
	var speed: float = FADE_IN_SPEED if target > _alpha else FADE_OUT_SPEED
	_alpha = move_toward(_alpha, target, speed * delta)
	visible = _alpha > 0.01
	if visible:
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var fraction: float = _player.breath_fraction() if _player != null else 0.0
	draw_arc(center, RADIUS, 0.0, TAU, 48, Color(UIPalette.WET_BLACK, 0.55 * _alpha), WIDTH, true)
	if fraction <= 0.0:
		return
	var color: Color = breath_color(fraction)
	if fraction < LOW_FRACTION:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		color = color.lerp(UIPalette.BONE_WHITE, 0.35 * pulse)
	color.a = _alpha
	draw_arc(center, RADIUS, -PI / 2.0, -PI / 2.0 + TAU * fraction, 48, color, WIDTH, true)


## Sea green while safe, sliding to ember as the last quarter drains.
static func breath_color(fraction: float) -> Color:
	if fraction >= LOW_FRACTION:
		return UIPalette.SEA_GREEN
	return UIPalette.EMBER_ORANGE.lerp(UIPalette.SEA_GREEN, fraction / LOW_FRACTION)
