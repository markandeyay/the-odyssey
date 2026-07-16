class_name Campfire
extends StaticBody3D
## Campfire (M10): cooks AND autosaves. Same object, two jobs
## (ARCHITECTURE §7). Interacting always requests an autosave; if a raw
## ingredient is selected in the hotbar it goes on the fire, interacting
## again takes it off in whatever state it reached. A carried brand
## exchanges fire with the campfire: a lit campfire lights an unlit
## brand, a lit brand lights a cold campfire.
##
## Flame states: LIT is a real flame and cooks everything; EMBERS cook
## everything except blind fish (they need real flame, §7); UNLIT cooks
## nothing. WORLD sets the initial state per placement. The campfire is a
## controlled fire — it does not register with the FireGrid and never
## spreads.

enum FlameState { UNLIT, EMBERS, LIT }

@export var initial_flame: FlameState = FlameState.LIT

var flame_state: FlameState = FlameState.LIT

@onready var cooker: Cooker = $Cooker
@onready var _interactable: Interactable = $Interactable
@onready var _cook_spot: MeshInstance3D = $CookSpot
@onready var _flame: CPUParticles3D = $Flame
@onready var _light: OmniLight3D = $Light


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)
	set_flame(initial_flame)


func _physics_process(delta: float) -> void:
	cooker.step(delta)
	_cook_spot.visible = cooker.active
	_update_prompt()


func is_real_flame() -> bool:
	return flame_state == FlameState.LIT


func set_flame(state: FlameState) -> void:
	flame_state = state
	_flame.emitting = state == FlameState.LIT
	_flame.visible = state == FlameState.LIT
	_light.visible = state != FlameState.UNLIT
	_light.light_energy = 1.6 if state == FlameState.LIT else 0.5


func _on_interacted(player: Player) -> void:
	var brand: Brand = player.carried_body() as Brand
	if brand != null and _exchange_fire(brand):
		pass
	elif cooker.active:
		_take_off()
	elif flame_state != FlameState.UNLIT:
		_try_put_on()
	# Campfire use is an autosave trigger (M6), whatever the use was:
	# cooking, lighting, or just resting at the fire.
	EventBus.autosave_requested.emit(&"campfire")


## A brand and a campfire trade whichever fire exists between them.
func _exchange_fire(brand: Brand) -> bool:
	if flame_state == FlameState.LIT and not brand.is_lit():
		return brand.light()
	if brand.is_lit() and flame_state != FlameState.LIT:
		set_flame(FlameState.LIT)
		return true
	return false


func _try_put_on() -> void:
	var stack: ItemStack = Inventory.selected_stack()
	if stack == null:
		return
	var def: FoodDef = ItemRegistry.get_def(stack.id) as FoodDef
	if def == null or def.cooked_id == &"":
		return
	if def.requires_real_flame and not is_real_flame():
		return  # blind fish on embers: nothing happens
	if Inventory.remove_item(stack.id, 1) != 1:
		return
	cooker.start(stack.id)


func _take_off() -> void:
	if Inventory.add_item(cooker.result_id(), 1) > 0:
		return  # no room anywhere; it stays on the fire
	cooker.clear()


func _update_prompt() -> void:
	if cooker.active:
		match cooker.state():
			Cooker.CookState.COOKED:
				_interactable.prompt = "Take (done)"
			Cooker.CookState.BURNT:
				_interactable.prompt = "Take (burnt)"
			_:
				_interactable.prompt = "Take (raw)"
	elif flame_state == FlameState.UNLIT:
		_interactable.prompt = "Campfire (cold)"
	else:
		_interactable.prompt = "Campfire"
