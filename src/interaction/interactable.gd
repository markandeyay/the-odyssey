class_name Interactable
extends Node
## Composition component (M4): add as a child of any physics object on the
## `interactable` layer and it becomes a raycast interact target. The owner
## connects to `interacted` — campfires cook, pickups collect, Keffer talks.

signal interacted(player: Player)

@export var prompt: String = "Interact"
@export var enabled: bool = true
## Campfires set this: interacting with a brand in hand lights it (M10).
## Everything else keeps interact-while-carrying meaning "drop".
@export var usable_while_carrying: bool = false


func interact(player: Player) -> void:
	if enabled:
		interacted.emit(player)
