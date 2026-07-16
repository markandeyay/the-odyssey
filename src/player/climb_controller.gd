class_name ClimbController
extends Node
## Climbing (M3), the island's core system. Climb anything on the
## `climbable` layer — the gate is the material, not a stamina bar
## (ARCHITECTURE §5): SOLID holds forever, CRUMBLING fails after a hold
## window, SLICK refuses grip entirely, HOT grips fine and burns.
## Route-finding means reading materials; this is a puzzle, not parkour.
## Child of Player; the player calls physics_step while climbing and
## try_attach/passive_step while not.

signal attached()
signal detached(reason: StringName)
signal handhold_failing(time_left: float)
signal mantled()

const CLIMBABLE_MASK: int = 4     # physics layer 3 "climbable"
const GROUND_MASK: int = 5        # world|climbable, for finding a mantle floor
const BLOCKER_MASK: int = 13      # world|climbable|carryable, for mantle fit
const CHEST_HEIGHT: float = 1.1
const HEAD_HEIGHT: float = 1.6
const MAX_WALL_NORMAL_Y: float = 0.55
const MIN_WALL_NORMAL_Y: float = -0.4

@export var climb_speed: float = 2.0
@export var attach_distance: float = 0.7
@export var surface_offset: float = 0.45
@export var crumble_hold_time: float = 2.5
@export var hot_damage_per_second: float = 0.5
@export var wall_jump_speed: float = 4.0
@export var reattach_cooldown: float = 0.4
@export var mantle_duration: float = 0.35

var active: bool = false

var _wall_normal: Vector3 = Vector3.FORWARD
var _current_collider: Object = null
var _grip: Grip.Class = Grip.Class.SOLID
var _crumble_timer: float = 0.0
var _cooldown: float = 0.0
var _mantling: bool = false
var _mantle_from: Vector3 = Vector3.ZERO
var _mantle_to: Vector3 = Vector3.ZERO
var _mantle_t: float = 0.0

@onready var _player: Player = get_parent() as Player


## Probes for a climbable wall in `direction` and latches on when the
## surface can actually be gripped. Carrying blocks climbing outright (M4).
func try_attach(direction: Vector3) -> bool:
	if active or _cooldown > 0.0 or _player.is_carrying:
		return false
	if direction.length_squared() < 0.04:
		return false
	var dir: Vector3 = direction.normalized()
	var hit: Dictionary = _probe(CHEST_HEIGHT, dir, attach_distance)
	if hit.is_empty():
		return false
	var normal: Vector3 = hit["normal"]
	if normal.y > MAX_WALL_NORMAL_Y or normal.y < MIN_WALL_NORMAL_Y:
		return false
	if dir.dot(-normal) < 0.5:
		return false
	var grip_class: Grip.Class = Grip.class_from_collision(hit["collider"])
	if grip_class == Grip.Class.SLICK:
		return false  # cannot grip at all; slide off immediately
	_wall_normal = normal
	_current_collider = hit["collider"]
	_grip = grip_class
	_crumble_timer = 0.0
	active = true
	_player.velocity = Vector3.ZERO
	attached.emit()
	return true


## Forced detach from outside the controller (death). No-op when off-wall.
func release(reason: StringName = &"released") -> void:
	if active or _mantling:
		_detach(reason)


## Called by the player on frames spent not climbing.
func passive_step(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


## Called by the player instead of locomotion while attached.
func physics_step(input: Vector2, delta: float) -> void:
	if _mantling:
		_mantle_step(delta)
		return
	if Input.is_action_just_pressed(&"jump"):
		_wall_jump()
		return
	if Input.is_action_just_pressed(&"crouch"):
		_detach(&"released")
		return

	var hit: Dictionary = _probe(CHEST_HEIGHT, -_wall_normal, surface_offset + 0.6)
	if hit.is_empty():
		if input.y < -0.1 and _try_mantle():
			return
		_detach(&"lost_surface")
		return
	_wall_normal = hit["normal"]
	_update_grip(hit["collider"], delta)
	if not active:
		return

	# Pushing up with no wall left at head height means a ledge: mantle it.
	if input.y < -0.1:
		var head_hit: Dictionary = _probe(HEAD_HEIGHT, -_wall_normal, surface_offset + 0.6)
		if head_hit.is_empty() and _try_mantle():
			return

	var up_wall: Vector3 = (Vector3.UP - _wall_normal * Vector3.UP.dot(_wall_normal)).normalized()
	var right_wall: Vector3 = (-_wall_normal).cross(Vector3.UP).normalized()
	var climb_velocity: Vector3 = (right_wall * input.x + up_wall * -input.y) * climb_speed
	var chest_hit: Vector3 = hit["position"]
	var desired_root: Vector3 = chest_hit + _wall_normal * surface_offset - Vector3.UP * CHEST_HEIGHT
	var correction: Vector3 = desired_root - _player.global_position
	correction.y = 0.0
	_player.velocity = climb_velocity + correction * 8.0
	_player.move_and_slide()
	_player.face_toward(-_wall_normal, delta)

	if _player.is_on_floor() and input.y > 0.1:
		_detach(&"grounded")


func _update_grip(collider: Object, delta: float) -> void:
	var grip_class: Grip.Class = Grip.class_from_collision(collider)
	if collider != _current_collider or grip_class != _grip:
		# A new handhold: the crumble window restarts.
		_current_collider = collider
		_grip = grip_class
		_crumble_timer = 0.0
	match _grip:
		Grip.Class.SLICK:
			_detach(&"slick")
		Grip.Class.CRUMBLING:
			_crumble_timer += delta
			handhold_failing.emit(maxf(0.0, crumble_hold_time - _crumble_timer))
			if _crumble_timer >= crumble_hold_time:
				_detach(&"handhold_failed")
		Grip.Class.HOT:
			_player.apply_damage(hot_damage_per_second * delta, &"hot_surface")
		_:
			pass


func _wall_jump() -> void:
	_player.velocity = _wall_normal * wall_jump_speed + Vector3.UP * wall_jump_speed * 0.9
	_detach(&"jumped")


func _try_mantle() -> bool:
	var forward: Vector3 = -_wall_normal
	var over_ledge: Vector3 = _player.global_position \
			+ Vector3.UP * (HEAD_HEIGHT + 0.7) + forward * 0.6
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var down_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		over_ledge, over_ledge + Vector3.DOWN * 1.6, GROUND_MASK, [_player.get_rid()]
	)
	var floor_hit: Dictionary = space.intersect_ray(down_query)
	if floor_hit.is_empty():
		return false
	if (floor_hit["normal"] as Vector3).y < 0.7:
		return false
	var target: Vector3 = floor_hit["position"]
	if not _fits_standing(target):
		return false
	_mantling = true
	_mantle_from = _player.global_position
	_mantle_to = target
	_mantle_t = 0.0
	_player.velocity = Vector3.ZERO
	return true


func _fits_standing(at: Vector3) -> bool:
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.95)
	query.collision_mask = BLOCKER_MASK
	query.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _mantle_step(delta: float) -> void:
	_mantle_t = minf(1.0, _mantle_t + delta / mantle_duration)
	var pos: Vector3 = _mantle_from.lerp(_mantle_to, smoothstep(0.0, 1.0, _mantle_t))
	pos.y += sin(_mantle_t * PI) * 0.25
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	if _mantle_t >= 1.0:
		mantled.emit()
		_detach(&"mantled")


func _detach(reason: StringName) -> void:
	active = false
	_mantling = false
	_current_collider = null
	_crumble_timer = 0.0
	_cooldown = 0.0 if reason == &"mantled" else reattach_cooldown
	detached.emit(reason)


func _probe(height: float, direction: Vector3, distance: float) -> Dictionary:
	var origin: Vector3 = _player.global_position + Vector3.UP * height
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * distance, CLIMBABLE_MASK, [_player.get_rid()]
	)
	return _player.get_world_3d().direct_space_state.intersect_ray(query)
