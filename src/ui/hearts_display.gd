class_name HeartsDisplay
extends Control
## Hearts — the only permanent HUD element (M12, ARCHITECTURE §2, §7).
## Draws one heart per container, filled left-to-right by current health,
## in ember orange (danger and warmth are the one saturated color). Damage
## flashes the outline for a beat. The geometry is code-drawn; no assets.

const HEART_SIZE: float = 26.0
const GAP: float = 6.0
const CURVE_SAMPLES: int = 32
const FLASH_TIME: float = 0.35

var _current: float = 0.0
var _max: int = 0
var _flash: float = 0.0

static var _unit_points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(false)


func bind(health: PlayerHealth) -> void:
	health.health_changed.connect(_on_health_changed)
	_current = health.current_hearts
	_max = health.max_hearts()
	_resize()
	queue_redraw()


func _on_health_changed(current_hearts: float, max_hearts: int) -> void:
	if current_hearts < _current:
		_flash = FLASH_TIME
		set_process(true)
	_current = current_hearts
	_max = max_hearts
	_resize()
	queue_redraw()


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if _flash <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var points: PackedVector2Array = heart_points(HEART_SIZE)
	for i: int in _max:
		var offset: Vector2 = Vector2(i * (HEART_SIZE + GAP), 0.0)
		var placed: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in points:
			placed.append(p + offset)
		draw_colored_polygon(placed, Color(UIPalette.WET_BLACK, 0.6))
		var fraction: float = fill_fraction(i, _current)
		if fraction > 0.0:
			var cut_x: float = offset.x + fraction * HEART_SIZE
			var filled: PackedVector2Array = clip_left_of(placed, cut_x)
			if filled.size() >= 3:
				draw_colored_polygon(filled, UIPalette.EMBER_ORANGE)
		var outline: PackedVector2Array = placed.duplicate()
		outline.append(placed[0])
		var outline_color: Color = Color(UIPalette.BONE_WHITE, 0.5)
		if _flash > 0.0:
			outline_color = Color(UIPalette.BONE_WHITE, 0.5 + 0.5 * _flash / FLASH_TIME)
		draw_polyline(outline, outline_color, 1.5, true)


## How full heart `index` is on a 0..1 scale given total hearts. Heart 2
## at 2.5 total hearts is half full; heart 3 is empty.
static func fill_fraction(index: int, current_hearts: float) -> float:
	return clampf(current_hearts - float(index), 0.0, 1.0)


## The classic cardioid-ish heart curve, sampled once and cached, scaled
## to fit a size x size box with screen-space y (down is positive).
static func heart_points(size: float) -> PackedVector2Array:
	if _unit_points.is_empty():
		var raw: PackedVector2Array = PackedVector2Array()
		for i: int in CURVE_SAMPLES:
			var t: float = TAU * float(i) / float(CURVE_SAMPLES)
			var x: float = 16.0 * pow(sin(t), 3.0)
			var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
			raw.append(Vector2(x, -y))
		var lo: Vector2 = raw[0]
		var hi: Vector2 = raw[0]
		for p: Vector2 in raw:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		var span: Vector2 = hi - lo
		for p: Vector2 in raw:
			_unit_points.append((p - lo) / span)
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in _unit_points:
		out.append(p * size)
	return out


## Sutherland–Hodgman clip of a polygon against the half-plane x <= cut_x.
## This is how a heart fills partially, left to right.
static func clip_left_of(points: PackedVector2Array, cut_x: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var count: int = points.size()
	for i: int in count:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		var a_in: bool = a.x <= cut_x
		var b_in: bool = b.x <= cut_x
		if a_in:
			out.append(a)
		if a_in != b_in:
			var t: float = (cut_x - a.x) / (b.x - a.x)
			out.append(a.lerp(b, t))
	return out


func _resize() -> void:
	custom_minimum_size = Vector2(
		maxf(0.0, _max * (HEART_SIZE + GAP) - GAP), HEART_SIZE
	)
