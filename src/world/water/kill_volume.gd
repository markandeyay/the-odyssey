class_name KillVolume
extends Area3D
## The ocean is the wall (ARCHITECTURE §2): a kill volume with waves on
## it, never playable water. No invisible barriers — the world is the
## gate. WORLD sizes and places instances around the island; entering
## kills Nau outright and the M6 death rule (hard reset to the last
## autosave) does the rest.


func _ready() -> void:
	collision_layer = 32  # layer 6 `water`
	collision_mask = 2    # the player
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player != null:
		player.apply_damage(1000.0, &"drowning")
