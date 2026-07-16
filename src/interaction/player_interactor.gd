class_name PlayerInteractor
extends Node
## Raycast interact targeting (M4). Casts from the camera through screen
## center, but reach is measured from the player so you cannot interact
## with things only the camera can touch. Child of Player.
## Targets: Interactable components (layer `interactable`) and carryable
## RigidBody3Ds (layer `carryable`). Interact picks up; interact or drop
## releases what is held.

signal target_changed(prompt: String)

const INTERACT_MASK: int = 24  # interactable(16) | carryable(8)
const CARRYABLE_LAYER: int = 8

@export var reach: float = 2.6

var _target_interactable: Interactable = null
var _target_carryable: RigidBody3D = null
var _last_prompt: String = ""

@onready var _player: Player = get_parent() as Player
@onready var _camera: Camera3D = _player.get_node("CameraRig/Pitch/SpringArm3D/Camera3D")
@onready var _carry: CarryController = _player.get_node("CarryController")


func _physics_process(_delta: float) -> void:
	_refresh_target()
	_handle_input()


func _refresh_target() -> void:
	_target_interactable = null
	_target_carryable = null
	var prompt: String = ""
	if _carry.held != null:
		prompt = "Drop"
	elif not _player.is_climbing():
		var hit: Dictionary = _raycast()
		if not hit.is_empty():
			var collider: Object = hit["collider"]
			var interactable: Interactable = _find_interactable(collider)
			if interactable != null and interactable.enabled:
				_target_interactable = interactable
				prompt = interactable.prompt
			elif collider is RigidBody3D \
					and ((collider as RigidBody3D).collision_layer & CARRYABLE_LAYER) != 0:
				_target_carryable = collider as RigidBody3D
				prompt = "Carry"
	if prompt != _last_prompt:
		_last_prompt = prompt
		target_changed.emit(prompt)


func _handle_input() -> void:
	if Input.is_action_just_pressed(&"drop") and _carry.held != null:
		_carry.drop()
		return
	if not Input.is_action_just_pressed(&"interact"):
		return
	if _carry.held != null:
		_carry.drop()
	elif _target_interactable != null:
		_target_interactable.interact(_player)
	elif _target_carryable != null:
		_carry.pick_up(_target_carryable)


func _raycast() -> Dictionary:
	var chest: Vector3 = _player.global_position + Vector3.UP * 1.2
	var origin: Vector3 = _camera.global_position
	var direction: Vector3 = -_camera.global_basis.z
	var length: float = origin.distance_to(chest) + reach
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * length, INTERACT_MASK, [_player.get_rid()]
	)
	query.collide_with_areas = true
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return hit
	if (hit["position"] as Vector3).distance_to(chest) > reach:
		return {}
	return hit


static func _find_interactable(obj: Object) -> Interactable:
	var node: Node = obj as Node
	if node == null:
		return null
	for child: Node in node.get_children():
		if child is Interactable:
			return child as Interactable
	return null
