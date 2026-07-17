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

@export_group("Swimming")
@export var swim_speed: float = 3.0
@export var swim_vertical_speed: float = 2.0
## Water depth over the feet at which wading becomes swimming.
@export var swim_depth: float = 1.2
## Where the body settles relative to the surface while floating.
@export var swim_float_height: float = 1.5
@export var water_acceleration: float = 6.0
@export var head_height: float = 1.6
## Seconds of breath underwater before drowning damage starts.
@export var breath_time: float = 12.0
## Seconds to refill breath fully once surfaced.
@export var breath_refill_time: float = 2.0
@export var drowning_damage_per_second: float = 0.5

@export_group("Fall damage")
## Landing at or above this speed hurts (M6). ~12 m/s is a 7m drop.
@export var fall_damage_min_speed: float = 12.0
## Hearts dealt when landing exactly at the threshold speed.
@export var fall_damage_base: float = 0.5
## Additional hearts per m/s above the threshold.
@export var fall_damage_per_speed: float = 0.25

@export_group("Noise")
## Loudness is the radius in meters at which the drowned hear it (M11).
## Crouch is quiet: crouched movement emits nothing at all.
@export var walk_loudness: float = 6.0
@export var run_loudness: float = 16.0
@export var footstep_interval: float = 0.5
## Landing above this speed makes a thud the drowned hear.
@export var land_noise_min_speed: float = 4.0
@export var land_loudness: float = 12.0

@export_group("Character contract")
## The mounted character scene (ARCHITECTURE §16). Never a hardcoded path.
@export var mesh_scene: PackedScene

var is_crouching: bool = false
## Driven by the carry system (M4). Carrying blocks climbing and gliding.
var is_carrying: bool = false
## Seconds of breath left (M8). Full at breath_time; drowning at zero.
var breath: float = 12.0

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _water_volumes: Array[WaterVolume] = []
var _heat_resistance_timer: float = 0.0
var _footstep_accum: float = 0.0
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
@onready var _hud: GameHUD = $HUD/GameHUD
@onready var _heat_wisps: CPUParticles3D = $Visual/HeatWisps
@onready var _carry: CarryController = $CarryController
@onready var _glider: GliderController = $GliderController
@onready var _glider_canvas: MeshInstance3D = $Visual/GliderCanvas
@onready var health: PlayerHealth = $Health


func _ready() -> void:
	# Sub-resources are shared between instances; crouch resizes the capsule.
	_collider.shape = _collider.shape.duplicate()
	_climb.attached.connect(_on_climb_attached)
	_climb.detached.connect(_on_climb_detached)
	_climb.handhold_failing.connect(_on_handhold_failing)
	_glider.deployed.connect(_on_glider_deployed)
	_glider.stowed.connect(_on_glider_stowed)
	_interactor.target_changed.connect(_hud.set_interact_prompt)
	health.died.connect(_on_died)
	breath = breath_time
	_hud.bind(self)
	_mount_mesh()


func is_climbing() -> bool:
	return _climb.active


func is_gliding() -> bool:
	return _glider.active


func _physics_process(delta: float) -> void:
	_update_survival(delta)
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var direction: Vector3 = _camera_rig.yaw_basis() * Vector3(input.x, 0.0, input.y)

	if _climb.active:
		_climb.physics_step(input, delta)
		_update_animator()
		return

	if is_swimming():
		_swim_step(direction, delta)
		_update_animator()
		return

	var on_floor: bool = is_on_floor()
	_update_timers(on_floor, delta)
	_handle_crouch_input()

	if not on_floor:
		_handle_glide_input()
		_glider.airborne_step(delta)
		if not _glider.active:
			velocity.y -= _gravity * delta
		_airborne_velocity_y = velocity.y

	_handle_jump(on_floor)
	_apply_horizontal_movement(direction, on_floor, delta)
	move_and_slide()
	_detect_landing()
	_emit_movement_noise(delta)

	_climb.passive_step(delta)
	if direction != Vector3.ZERO and not is_crouching:
		_climb.try_attach(direction)
	_update_animator()


## Carry (M4) and the glider (M13) attach through these, never through bones.
func get_socket(socket_name: StringName) -> Node3D:
	return _sockets.get(socket_name, null)


## Damage entry point for fire, heat, falls, drowning, and the drowned.
## Amounts are in hearts (M6). Heat resistance (cooked charwood fruit)
## negates ambient heat and HOT-surface contact — that is what opens HOT
## routes (§5) — but not open flame, falls, or water.
func apply_damage(amount: float, source: StringName = &"") -> void:
	if is_heat_resistant() and (source == &"heat" or source == &"hot_surface"):
		return
	health.apply_damage(amount, source)


func grant_heat_resistance(duration: float) -> void:
	_heat_resistance_timer = maxf(_heat_resistance_timer, duration)


func is_heat_resistant() -> bool:
	return _heat_resistance_timer > 0.0


func heat_resistance_left() -> float:
	return _heat_resistance_timer


## The wisps burn steady while the buff holds, then gutter — on/off in
## beats — through the final seconds so expiry never surprises. This is
## the heat resistance indicator (M12); there is no HUD element for it.
static func heat_wisps_lit(time_left: float, gutter_below: float = 10.0) -> bool:
	if time_left <= 0.0:
		return false
	if time_left >= gutter_below:
		return true
	return fmod(time_left, 0.6) > 0.25


## Water volumes (M8) report themselves through these on enter/exit.
func enter_water(volume: WaterVolume) -> void:
	if not _water_volumes.has(volume):
		_water_volumes.append(volume)


func exit_water(volume: WaterVolume) -> void:
	_water_volumes.erase(volume)


func is_in_water() -> bool:
	return not _water_volumes.is_empty()


func water_surface_y() -> float:
	var top: float = -INF
	for volume: WaterVolume in _water_volumes:
		top = maxf(top, volume.surface_height())
	return top


func is_swimming() -> bool:
	return is_in_water() and water_surface_y() - global_position.y >= swim_depth


func is_submerged() -> bool:
	return is_in_water() and water_surface_y() > global_position.y + head_height


## For the breath meter (M12): 1.0 full, 0.0 drowning.
func breath_fraction() -> float:
	return clampf(breath / breath_time, 0.0, 1.0)


## What the carry system holds right now, if anything (M4/M10).
func carried_body() -> RigidBody3D:
	return _carry.held


## The drowned knock Nau's light out of his hands (M11). Returns what was
## dropped so the caller can scatter it.
func force_drop_carried() -> RigidBody3D:
	var body: RigidBody3D = _carry.held
	if body != null:
		_carry.drop()
	return body


## Eats the selected hotbar item if it is food (M10, §7). Heals; cooked
## charwood fruit also grants heat resistance — grants extend, never
## stack. Returns false if the selected item is not edible.
func try_eat_selected() -> bool:
	var stack: ItemStack = Inventory.selected_stack()
	if stack == null:
		return false
	var def: FoodDef = ItemRegistry.get_def(stack.id) as FoodDef
	if def == null:
		return false
	if Inventory.remove_item(stack.id, 1) != 1:
		return false
	health.heal(def.heal_hearts)
	if def.grants_heat_resistance > 0.0:
		grant_heat_resistance(def.grants_heat_resistance)
	return true


## Landing speed to hearts. Below the threshold falls are free; above it
## the base cost grows linearly with excess speed.
func fall_damage_hearts(impact_speed: float) -> float:
	if impact_speed < fall_damage_min_speed:
		return 0.0
	return fall_damage_base + (impact_speed - fall_damage_min_speed) * fall_damage_per_speed


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


## Breath and heat resistance tick every frame regardless of movement
## state (M8). Drowning damage is continuous once breath runs out.
## Heat resistance shows diegetically (M12): ember wisps rise off Nau
## while the charwood buff holds, and gutter in the final seconds.
func _update_survival(delta: float) -> void:
	if _heat_resistance_timer > 0.0:
		_heat_resistance_timer = maxf(0.0, _heat_resistance_timer - delta)
	_heat_wisps.emitting = heat_wisps_lit(_heat_resistance_timer)
	if is_submerged():
		breath = maxf(0.0, breath - delta)
		if breath <= 0.0:
			apply_damage(drowning_damage_per_second * delta, &"drowning")
	else:
		breath = minf(breath_time, breath + delta * breath_time / breath_refill_time)


## Buoyant locomotion (M8): float to the surface, jump to rise, crouch to
## dive, currents push. No gravity, no coyote time, no fall damage — the
## water catches everything.
func _swim_step(direction: Vector3, delta: float) -> void:
	_glider.stow(&"water")
	_airborne_velocity_y = 0.0
	_was_on_floor = is_on_floor()
	var push: Vector3 = Vector3.ZERO
	for volume: WaterVolume in _water_volumes:
		push += volume.current
	var target: Vector3 = direction * swim_speed + Vector3(push.x, 0.0, push.z)
	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	flat = flat.lerp(target, 1.0 - exp(-water_acceleration * delta))
	velocity.x = flat.x
	velocity.z = flat.z
	var vertical: float
	if Input.is_action_pressed(&"jump"):
		vertical = swim_vertical_speed
	elif Input.is_action_pressed(&"crouch"):
		vertical = -swim_vertical_speed
	else:
		var settle: float = water_surface_y() - (global_position.y + swim_float_height)
		vertical = clampf(settle * 2.0, -swim_vertical_speed, swim_vertical_speed)
	velocity.y = lerpf(velocity.y, vertical + push.y, 1.0 - exp(-water_acceleration * delta))
	move_and_slide()
	face_toward(direction, delta)


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


## Glide shares Space with jump: the second press in the air deploys, the
## next stows. A press inside the coyote window stays a jump (M13).
func _handle_glide_input() -> void:
	if not Input.is_action_just_pressed(&"glide"):
		return
	if _glider.active:
		_glider.stow(&"toggled")
	elif _coyote_timer <= 0.0:
		_glider.try_deploy()


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
	var acceleration: float
	if on_floor:
		acceleration = ground_acceleration
	elif _glider.active:
		acceleration = _glider.glide_acceleration
	else:
		acceleration = air_acceleration
	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	flat = flat.lerp(target, 1.0 - exp(-acceleration * delta))
	velocity.x = flat.x
	velocity.z = flat.z
	face_toward(direction, delta)


func _detect_landing() -> void:
	var on_floor: bool = is_on_floor()
	if on_floor and not _was_on_floor:
		_glider.stow(&"landed")
		var impact_speed: float = maxf(0.0, -_airborne_velocity_y)
		landed.emit(impact_speed)
		_animator.play_landed()
		var damage: float = fall_damage_hearts(impact_speed)
		if damage > 0.0:
			apply_damage(damage, &"fall")
		if impact_speed > land_noise_min_speed:
			EventBus.sound_emitted.emit(global_position, land_loudness)
	_was_on_floor = on_floor


## Footsteps (M11): crouch is quiet, walk is audible near, run is loud.
## The drowned listen.
func _emit_movement_noise(delta: float) -> void:
	var flat_speed: float = Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or is_crouching or flat_speed < 0.5:
		_footstep_accum = 0.0
		return
	_footstep_accum += delta
	if _footstep_accum < footstep_interval:
		return
	_footstep_accum = 0.0
	var loudness: float = walk_loudness if flat_speed < run_speed * walk_threshold else run_loudness
	EventBus.sound_emitted.emit(global_position, loudness)


func _update_animator() -> void:
	if _climb.active:
		_animator.set_locomotion(&"climb_move" if velocity.length() > 0.3 else &"climb_idle")
		return
	if is_swimming():
		var swim_flat: float = Vector2(velocity.x, velocity.z).length()
		_animator.set_locomotion(&"swim_move" if swim_flat > 0.5 else &"swim_idle")
		return
	var flat_speed: float = Vector2(velocity.x, velocity.z).length()
	var state: StringName
	if not is_on_floor():
		if _glider.active:
			state = &"glide"
		else:
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
	if _glider.active:
		return _glider.glide_speed
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


## Death is a hard reset to the last autosave (M6); the SaveSystem hears
## `player_died` and reloads. Here we only put the body in a loadable
## state: off the wall, empty-handed, still.
func _on_died() -> void:
	velocity = Vector3.ZERO
	if _climb.active:
		_climb.release(&"died")
	if is_carrying:
		_carry.drop()
	_glider.stow(&"died")


func _is_ceiling_blocked() -> bool:
	_ceiling_check.force_shapecast_update()
	return _ceiling_check.is_colliding()


func _on_climb_attached() -> void:
	_glider.stow(&"climbing")
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


## The canvas is the glide indicator (M12/M13): diegetic, no HUD element.
func _on_glider_deployed() -> void:
	_glider_canvas.visible = true


func _on_glider_stowed(_reason: StringName) -> void:
	_glider_canvas.visible = false


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
