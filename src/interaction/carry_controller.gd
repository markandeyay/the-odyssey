class_name CarryController
extends Node
## Two-handed physical carry (M4). Large objects (layer `carryable`) are
## held in the world, not stored: RigidBody3D freezes on pickup, follows the
## CarryHold point, unfreezes on drop. Carrying blocks climbing and the
## glider and slows the player (ARCHITECTURE §8) — that is the Hold trial's
## whole design. Child of Player.

signal picked_up(body: RigidBody3D)
signal dropped(body: RigidBody3D)

@export var follow_speed: float = 12.0

var held: RigidBody3D = null

var _stored_layer: int = 0
var _stored_mask: int = 0
var _stored_freeze: bool = false

@onready var _player: Player = get_parent() as Player
@onready var _hold_point: Node3D = _player.get_node("Visual/CarryHold")


func _physics_process(delta: float) -> void:
	if held == null:
		return
	var target: Transform3D = _hold_point.global_transform
	var new_origin: Vector3 = held.global_position.lerp(
		target.origin, 1.0 - exp(-follow_speed * delta)
	)
	held.global_transform = Transform3D(target.basis, new_origin)


func pick_up(body: RigidBody3D) -> bool:
	if held != null or body == null or _player.is_climbing():
		return false
	_stored_layer = body.collision_layer
	_stored_mask = body.collision_mask
	_stored_freeze = body.freeze
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	# Held objects collide with nothing; the world gets them back on drop.
	body.collision_layer = 0
	body.collision_mask = 0
	held = body
	_player.is_carrying = true
	picked_up.emit(body)
	return true


func drop() -> bool:
	if held == null:
		return false
	var body: RigidBody3D = held
	held = null
	body.collision_layer = _stored_layer
	body.collision_mask = _stored_mask
	body.freeze = _stored_freeze
	body.linear_velocity = _player.velocity
	body.angular_velocity = Vector3.ZERO
	_player.is_carrying = false
	dropped.emit(body)
	return true
