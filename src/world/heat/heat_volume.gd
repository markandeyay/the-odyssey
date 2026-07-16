class_name HeatVolume
extends Area3D
## Ambient heat (M8): damage over time on physics layer `heat` (8),
## independent of touching anything — the air itself hurts. WORLD places
## and sizes instances and stacks them vertically in the Ember Quarter,
## because heat rises. Heat resistance (cooked charwood fruit, M10)
## negates the damage; that check lives in Player.apply_damage, so this
## volume just reports heat and stays dumb.

## Hearts per second inside the volume.
@export var damage_per_second: float = 0.25
@export var damage_interval: float = 0.5

var _accum: float = 0.0


func _ready() -> void:
	collision_layer = 128  # layer 8 `heat`
	collision_mask = 2     # the player


func _physics_process(delta: float) -> void:
	_accum += delta
	if _accum < damage_interval:
		return
	var dt: float = _accum
	_accum = 0.0
	for body: Node3D in get_overlapping_bodies():
		var player: Player = body as Player
		if player != null:
			player.apply_damage(damage_per_second * dt, &"heat")
