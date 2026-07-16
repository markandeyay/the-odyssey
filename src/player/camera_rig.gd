class_name CameraRig
extends Node3D
## Third-person camera rig: yaw on this node, pitch on a child, and a
## SpringArm3D that collides with the world so the camera never clips.
## Mouse look plus right-stick look. The player body never yaw-rotates;
## the visual turns toward movement and this rig turns with the player's eye.

@export var mouse_sensitivity: float = 0.0025
@export var gamepad_look_speed: float = 2.5
@export_range(-89.0, 0.0) var pitch_min_degrees: float = -70.0
@export_range(0.0, 89.0) var pitch_max_degrees: float = 60.0

@onready var _pitch: Node3D = $Pitch


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look((event as InputEventMouseMotion).relative * mouse_sensitivity)
	elif event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and get_tree().get_first_node_in_group(&"modal_ui") == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var look: Vector2 = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look != Vector2.ZERO:
		_apply_look(look * gamepad_look_speed * delta)


## Movement input is projected through this so "forward" means camera-forward.
func yaw_basis() -> Basis:
	return Basis(Vector3.UP, rotation.y)


func _apply_look(amount: Vector2) -> void:
	rotation.y -= amount.x
	_pitch.rotation.x = clampf(
		_pitch.rotation.x - amount.y,
		deg_to_rad(pitch_min_degrees),
		deg_to_rad(pitch_max_degrees)
	)
