class_name DistrictTrigger
extends Area3D
## District entry volume (WORLD's M5 prefab request). WORLD sizes and
## places one per district mouth by overriding the instance's
## CollisionShape3D box; Nau crossing it emits
## `district_entered(district_id)` on the EventBus and nothing else.
## GameState owns the consequences: current district, the visited list,
## and the first-entry autosave — duplicate emissions with a stable id
## are safely ignored (M6), so re-entry costs nothing.

@export var district_id: StringName = &""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # the player
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if district_id == &"":
		push_warning("DistrictTrigger: no district_id set")
		return
	if body is Player:
		EventBus.district_entered.emit(district_id)
