class_name Drowned
extends CharacterBody3D
## The drowned (M11): Nau's own dead crew, come out of the water. Only in
## The Dark — WORLD places them there and nowhere else, and a leash
## enforces it mechanically. They cannot be hurt: there is no health
## here, no damage entry point, and no attack input anywhere in the game.
## There is no combat. Ever (ARCHITECTURE §10).
##
## They hunt by sound (`sound_emitted` on the EventBus; loudness is a
## radius in meters) and by light (anything in the `burning` group,
## line-of-sight checked — carried fire is a beacon). Break line of sight
## and go quiet and they lose track of you. Contact deals damage and a
## knockback that separates Nau from his light source: he is thrown one
## way, his brand scatters the other, toward the dark. Not instant death.
## Losing your light in the dark with them is the scare.

enum State { LURK, INVESTIGATE, HUNT, SEARCH }

@export_group("Senses")
## Multiplies incoming loudness radii. 1.0 hears exactly at loudness range.
@export var hearing_multiplier: float = 1.0
## How far a burning light is visible to them.
@export var sight_range: float = 24.0
@export var sight_interval: float = 0.25
## Seconds a hunted light can stay unseen before the trail goes cold.
@export var lose_sight_time: float = 1.5
## Seconds spent lingering at the last known position before giving up.
@export var search_time: float = 6.0
## Stimuli beyond this distance from home are ignored: they never leave
## The Dark (§10).
@export var leash_radius: float = 40.0

@export_group("Movement")
@export var lurk_speed: float = 1.0
@export var investigate_speed: float = 2.5
@export var hunt_speed: float = 4.5
@export var turn_speed: float = 8.0
@export var arrive_distance: float = 1.2

@export_group("Contact")
## Hearts per touch. Not instant death (§10).
@export var contact_damage: float = 1.0
@export var knockback_speed: float = 7.0
@export var knockback_lift: float = 3.0
## How hard the dropped light is flung — toward the dark, away from Nau.
@export var light_scatter_speed: float = 6.0
@export var contact_cooldown: float = 1.5

@export_group("Appearance")
## Placeholder until WORLD delivers a drowned mesh; never hardcode one.
@export var mesh_scene: PackedScene

var state: State = State.LURK

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _home: Vector3 = Vector3.ZERO
var _target_pos: Vector3 = Vector3.ZERO
var _sight_accum: float = 0.0
var _lost_timer: float = 0.0
var _search_timer: float = 0.0
var _contact_timer: float = 0.0

@onready var _hitbox: Area3D = $Hitbox
@onready var _fallback_mesh: MeshInstance3D = $FallbackMesh


func _ready() -> void:
	_home = global_position
	EventBus.sound_emitted.connect(_on_sound_emitted)
	if mesh_scene != null:
		add_child(mesh_scene.instantiate())
		_fallback_mesh.visible = false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	_contact_timer = maxf(0.0, _contact_timer - delta)
	_sight_accum += delta
	if _sight_accum >= sight_interval:
		_sight_accum = 0.0
		_scan_for_light()
	match state:
		State.LURK:
			_step_lurk()
		State.INVESTIGATE:
			if _move_toward(_target_pos, investigate_speed, delta):
				_begin_search()
		State.HUNT:
			_lost_timer += delta
			if _lost_timer > lose_sight_time:
				_begin_search()
			else:
				_move_toward(_target_pos, hunt_speed, delta)
		State.SEARCH:
			_search_timer -= delta
			velocity.x = 0.0
			velocity.z = 0.0
			if _search_timer <= 0.0:
				state = State.LURK
	move_and_slide()
	_check_contact()


## Hearing: a sound is heard when the drowned stands inside its loudness
## radius. Crouched movement emits nothing, so crouching walks right past.
func _on_sound_emitted(position: Vector3, loudness: float) -> void:
	if _home.distance_to(position) > leash_radius:
		return
	if global_position.distance_to(position) > loudness * hearing_multiplier:
		return
	if state == State.HUNT:
		return  # a seen light outranks a noise
	_target_pos = position
	state = State.INVESTIGATE


## Sight: any burning body in range with clear line of sight. Carried
## fire is a beacon; a dropped brand on the ground draws them the same.
func _scan_for_light() -> void:
	for node: Node in get_tree().get_nodes_in_group(Grip.BURNING_GROUP):
		var body: Node3D = node as Node3D
		if body == null or not is_instance_valid(body):
			continue
		var pos: Vector3 = body.global_position
		if _home.distance_to(pos) > leash_radius:
			continue
		if global_position.distance_to(pos) > sight_range:
			continue
		if not _line_of_sight(pos):
			continue
		_target_pos = pos
		state = State.HUNT
		_lost_timer = 0.0
		return


func _line_of_sight(target: Vector3) -> bool:
	var from: Vector3 = global_position + Vector3.UP * 1.5
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, target + Vector3.UP * 0.2, 1, [get_rid()]  # world geometry blocks sight
	)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _begin_search() -> void:
	state = State.SEARCH
	_search_timer = search_time


func _step_lurk() -> void:
	if global_position.distance_to(_home) > arrive_distance:
		var to_home: Vector3 = _home - global_position
		to_home.y = 0.0
		var dir: Vector3 = to_home.normalized()
		velocity.x = dir.x * lurk_speed
		velocity.z = dir.z * lurk_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0


## Walks toward a point; returns true on arrival.
func _move_toward(target: Vector3, speed: float, delta: float) -> bool:
	var to: Vector3 = target - global_position
	to.y = 0.0
	if to.length() <= arrive_distance:
		velocity.x = 0.0
		velocity.z = 0.0
		return true
	var dir: Vector3 = to.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-turn_speed * delta))
	return false


## Contact: damage plus a knockback that separates Nau from his light.
## He is thrown away; the brand is flung the other way, toward the dark.
func _check_contact() -> void:
	if _contact_timer > 0.0:
		return
	for body: Node3D in _hitbox.get_overlapping_bodies():
		var player: Player = body as Player
		if player == null:
			continue
		_contact_timer = contact_cooldown
		var away: Vector3 = player.global_position - global_position
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.001 else Vector3.FORWARD
		var dropped: RigidBody3D = player.force_drop_carried()
		if dropped != null:
			dropped.apply_central_impulse(
				(-away * light_scatter_speed + Vector3.UP * 2.0) * dropped.mass
			)
		player.velocity = away * knockback_speed + Vector3.UP * knockback_lift
		player.apply_damage(contact_damage, &"drowned")
		return
