class_name Cooker
extends Node
## The cooking state machine (M10): a timed physical interaction, not a
## menu. One slot. The thing goes on the fire, cooks, stays good through
## the cook window, then burns to charcoal and is wasted. Pure logic —
## the campfire owns flame state and steps this; tests drive it directly.

enum CookState { IDLE, RAW, COOKED, BURNT }

const CHARCOAL_ID: StringName = &"charcoal"

## Seconds on the fire before raw becomes cooked.
@export var cook_time: float = 8.0
## Seconds cooked stays good before it burns. This is the cook window.
@export var cook_window: float = 6.0

var item_id: StringName = &""
var elapsed: float = 0.0
var active: bool = false


func start(id: StringName) -> void:
	item_id = id
	elapsed = 0.0
	active = true


func step(delta: float) -> void:
	if active:
		elapsed += delta


func state() -> CookState:
	if not active:
		return CookState.IDLE
	if elapsed < cook_time:
		return CookState.RAW
	if elapsed < cook_time + cook_window:
		return CookState.COOKED
	return CookState.BURNT


## What comes off the fire right now: still raw, properly cooked, or
## charcoal. Taking it off early is allowed and returns the raw item.
func result_id() -> StringName:
	match state():
		CookState.RAW:
			return item_id
		CookState.COOKED:
			var def: FoodDef = ItemRegistry.get_def(item_id) as FoodDef
			return def.cooked_id if def != null else item_id
		CookState.BURNT:
			return CHARCOAL_ID
		_:
			return &""


func clear() -> void:
	item_id = &""
	elapsed = 0.0
	active = false
