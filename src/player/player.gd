class_name Player
extends CharacterBody3D
## Nau's third-person controller. M2 locomotion: run, walk, jump, crouch,
## fall, land, with coyote time and jump buffering. M3 climbing: delegated
## to ClimbController; grip is a material property, and there is no stamina,
## ever (ARCHITECTURE §2, §5). Locomotion is code-driven and root motion is
## off. The character mesh mounts through an exported PackedScene per the
## character contract (§16); until WORLD delivers a placeholder, the capsule
## fallback stays visible.

signal landed(impact_speed: float)
signal crouch_changed(is_crouching: bool)

const SOCKET_NAMES: Array[StringName] = [
	&"Socket_RightHand", &"Socket_LeftHand", &"Socket_Back", &"Socket_Hip",
]

@export_group("Speeds")
@export var run_speed: float = 5.0
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.0
## Two-handed carry slows everything (M4). Sprint is disabled while carrying.
@export var carry_speed_multiplier: float = 0.6
## Below this fraction of run speed the animator reads "walk".
@export var walk_threshold: float = 0.6

@export_group("Acceleration")
@export var ground_acceleration: float = 14.0
@export var air_acceleration: float = 4.0
@export var turn_speed: float = 12.0

@export_group("Jumping")
@export var jump_velocity: float = 4.8
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_group("Crouch")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.2

@export_group("Character contract")
## The mounted character scene (ARCHITECTURE §16). Never a hardcoded path.
@export var mesh_scene: PackedScene

var is_crouching: bool = false
## Driven by the carry system (M4). Carrying blocks climbing and gliding.
var is_carrying: bool = false
## Stub accumulator until the hearts system lands (M6).
var total_damage_taken: float = 0.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _airborne_velocity_y: float = 0.0
var _was_on_floor: bool = true
var _handhold_telegraphed: bool = false
var _skeleton: Skeleton3D = null
var _sockets: Dictionary = {}

@onready var _collider: CollisionShape3D = $Collider
@onready var _visual: Node3D = $Visual
@onready var _fallback_capsule: MeshInstance3D = $Visual/FallbackCapsule
@onready var _ceiling_check: ShapeCast3D = $CeilingCheck
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _animator: PlayerAnimator = $Animator
@onready var _climb: ClimbController = $ClimbController
@onready var _dust: CPUParticles3D = $GripDust
@onready var _interactor: PlayerInteractor = $PlayerInteractor
@onready var _prompt_label: InteractPromptLabel = $HUD/InteractPrompt


func _ready() -> void:
	# Sub-resources are shared between instances; crouch resizes the capsule.
	_collider.shape = _collider.shape.duplicate()
	_climb.attached.connect(_on_climb_attached)
	_climb.detached.connect(_on_climb_detached)
	_climb.handhold_failing.connect(_on_handhold_failing)
	_interactor.target_changed.connect(_prompt_label.set_prompt)
	_mount_mesh()


func is_climbing() -> bool:
	return _climb.active


func _physics_process(delta: float) -> void:
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction: Vector3 = _camera_rig.yaw_basis() * Vector3(input.x, 0.0, input.y)

	if _climb.active:
		_climb.physics_step(input, delta)
		_update_animator()
		return

	var on_floor: bool = is_on_floor()
	_update_timers(on_floor, delta)
	_handle_crouch_input()

	if not on_floor:
		velocity.y -= _gravity * delta
		_airborne_velocity_y = velocity.y

	_handle_jump(on_floor)
	_apply_horizontal_movement(direction, on_floor, delta)
	move_and_slide()
	_detect_landing()

	_climb.passive_step(delta)
	if direction != Vector3.ZERO and not is_crouching:
		_climb.try_attach(direction)
	_update_animator()


## Carry (M4) and the glider (M13) attach through these, never through bones.
func get_socket(socket_name: StringName) -> Node3D:
	return _sockets.get(socket_name, null)


## Damage entry point for fire, heat, falls, and the drowned. M6 replaces
## the body with the hearts system; the signature is stable for callers.
func apply_damage(amount: float, _source: StringName = &"") -> void:
	total_damage_taken += amount


## Smoothly turns the visual (never the body) toward a world direction.
func face_toward(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(-direction.x, -direction.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


## Returns false when standing up is blocked by a ceiling.
func set_crouching(value: bool) -> bool:
	if value == is_crouching:
		return true
	if not value and _is_ceiling_blocked():
		return false
	is_crouching = value
	var capsule: CapsuleShape3D = _collider.shape as CapsuleShape3D
	capsule.height = crouch_height if value else stand_height
	_collider.position.y = capsule.height * 0.5
	crouch_changed.emit(is_crouching)
	return true


func _update_timers(on_floor: bool, delta: float) -> void:
	if on_floor:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)


func _handle_crouch_input() -> void:
	if Input.is_action_just_pressed(&"crouch"):
		set_crouching(not is_crouching)


func _handle_jump(on_floor: bool) -> void:
	if _jump_buffer_timer <= 0.0:
		return
	if not on_floor and _coyote_timer <= 0.0:
		return
	if is_crouching and not set_crouching(false):
		return
	velocity.y = jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func _apply_horizontal_movement(direction: Vector3, on_floor: bool, delta: float) -> void:
	var target: Vector3 = direction * _current_speed()
	var acceleration: float = ground_acceleration if on_floor else air_acceleration
	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	flat = flat.lerp(target, 1.0 - exp(-acceleration * delta))
	velocity.x = flat.x
	velocity.z = flat.z
	face_toward(direction, delta)


func _detect_landing() -> void:
	var on_floor: bool = is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit(maxf(0.0, -_airborne_velocity_y))
		_animator.play_landed()
	_was_on_floor = on_floor


func _update_animator() -> void:
	if _climb.active:
		_animator.set_locomotion(&"climb_move" if velocity.length() > 0.3 else &"climb_idle")
		return
	var flat_speed: float = Vector2(velocity.x, velocity.z).length()
	var state: StringName
	if not is_on_floor():
		state = &"jump" if velocity.y > 0.0 else &"fall"
	elif is_crouching:
		state = &"crouch_walk" if flat_speed > 0.5 else &"crouch_idle"
	elif flat_speed <= 0.5:
		state = &"idle"
	elif flat_speed > run_speed + 0.5:
		state = &"sprint"
	elif flat_speed < run_speed * walk_threshold:
		state = &"walk"
	else:
		state = &"run"
	_animator.set_locomotion(state)


func _current_speed() -> float:
	var speed: float
	if is_crouching:
		speed = crouch_speed
	elif Input.is_action_pressed(&"sprint") and not is_carrying:
		speed = sprint_speed
	else:
		speed = run_speed
	if is_carrying:
		speed *= carry_speed_multiplier
	return speed


func _is_ceiling_blocked() -> bool:
	_ceiling_check.force_shapecast_update()
	return _ceiling_check.is_colliding()


func _on_climb_attached() -> void:
	_handhold_telegraphed = false
	_visual.position = Vector3.ZERO


func _on_climb_detached(reason: StringName) -> void:
	_visual.position = Vector3.ZERO
	_handhold_telegraphed = false
	# No buffered jump or coyote hop straight off a detach.
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	if reason == &"handhold_failed":
		_dust.restart()


## Telegraphs a failing CRUMBLING handhold: hand-slip jitter plus dust.
func _on_handhold_failing(time_left: float) -> void:
	if time_left > 1.0:
		return
	_visual.position = Vector3(randf_range(-0.03, 0.03), 0.0, randf_range(-0.03, 0.03))
	if not _handhold_telegraphed:
		_handhold_telegraphed = true
		_dust.restart()


func _mount_mesh() -> void:
	if mesh_scene == null:
		return
	var instance: Node = mesh_scene.instantiate()
	_visual.add_child(instance)
	_fallback_capsule.visible = false
	var skeletons: Array[Node] = instance.find_children("*", "Skeleton3D", true, false)
	if skeletons.size() > 0:
		_skeleton = skeletons[0] as Skeleton3D
	else:
		push_warning("Player: mounted mesh has no Skeleton3D (character contract, ARCHITECTURE §16)")
	for socket_name: StringName in SOCKET_NAMES:
		var socket: Node3D = instance.find_child(String(socket_name), true, false) as Node3D
		if socket == null:
			push_warning("Player: mounted mesh is missing %s (character contract, ARCHITECTURE §16)" % socket_name)
		else:
			_sockets[socket_name] = socket
	_animator.bind_to(instance)
