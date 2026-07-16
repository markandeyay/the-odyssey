class_name ItemPickup
extends StaticBody3D
## A small pickup that goes into the inventory on interact (M4).
## Large objects are carried physically instead — this is for food,
## salvage, and other pocketable things.

@export var item_id: StringName = &""
@export var count: int = 1
@export var display_name: String = ""

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_interactable.prompt = _build_prompt()
	_interactable.interacted.connect(_on_interacted)


func _build_prompt() -> String:
	var label: String = display_name if display_name != "" else String(item_id)
	if count > 1:
		return "Take %s x%d" % [label, count]
	return "Take %s" % label


func _on_interacted(_player: Player) -> void:
	var leftover: int = Inventory.add_item(item_id, count)
	if leftover == 0:
		queue_free()
	else:
		count = leftover
		_interactable.prompt = _build_prompt()
