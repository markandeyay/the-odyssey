class_name ComponentPickup
extends StaticBody3D
## One of the five pieces of the broken bridge (M14, ARCHITECTURE §4).
## Interacting acquires it: `component_acquired` fires once, GameState
## records it and files the key item, and Setu mounts it visibly in the
## Shallows wherever Nau happens to be standing. An already-acquired
## pickup removes itself on ready, so a loaded save never shows a
## duplicate.

@export var component_id: StringName = &""

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	if GameState.components_acquired.has(component_id):
		queue_free()
		return
	_interactable.prompt = _build_prompt()
	_interactable.interacted.connect(_on_interacted)


func _build_prompt() -> String:
	var def: ItemDef = ItemRegistry.get_def(component_id)
	var label: String = def.display_name if def != null else String(component_id)
	return "Take the %s" % label


func _on_interacted(_player: Player) -> void:
	if component_id == &"":
		push_warning("ComponentPickup: no component_id set")
		return
	EventBus.component_acquired.emit(component_id)
	queue_free()
