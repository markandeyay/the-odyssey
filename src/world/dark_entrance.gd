class_name DarkEntrance
extends Area3D
## The doorway into The Dark (WORLD's M5 sublevel-transition request).
## The Dark never joins open-world streaming (ARCHITECTURE §10); this
## prefab is the only way in. Nau crossing it — once the required trial,
## if any, is complete — instances the Dark sub-scene at its authored
## world transform (WORLD builds it in world space under the Spine),
## transfers him to `RouteMarkers/Entry`, and wires a touch volume over
## `RouteMarkers/Exit` that returns him to the doorway and frees the
## interior. A carryable held on the way out — the Figurehead walk is
## the whole last beat (M14) — is reparented out of the interior before
## the free, so the carry survives the transition.

const EXIT_BOX_SIZE: Vector3 = Vector3(6.0, 4.0, 6.0)

@export var target_scene: PackedScene
## When set, the doorway stays inert until this trial is complete —
## The Dark opens only after the Spine (§4). Empty means always open.
@export var required_trial_id: StringName = &""

var _interior: Node3D = null
var _armed: bool = true
var _exit_armed: bool = true
var _return_transform: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # the player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player or not _armed or _interior != null:
		return
	if target_scene == null:
		push_warning("DarkEntrance: target_scene not set")
		return
	if required_trial_id != &"" and not GameState.trials_completed.has(required_trial_id):
		return
	_armed = false
	_enter.call_deferred(body)


func _on_body_exited(body: Node3D) -> void:
	# Re-arm only once Nau has stepped back out of the doorway after a
	# visit; the teleport into the interior also exits this volume, but
	# the live interior keeps it disarmed until he is returned and leaves.
	if body is Player and _interior == null:
		_armed = true


func _enter(player: Node3D) -> void:
	_return_transform = player.global_transform
	_interior = target_scene.instantiate() as Node3D
	if _interior == null:
		push_error("DarkEntrance: %s root must be Node3D" % target_scene.resource_path)
		_armed = true
		return
	# The Dark is authored in world space; keep it exactly where WORLD
	# built it instead of repositioning relative to the doorway.
	_interior.top_level = true
	add_child(_interior)

	var entry: Node3D = _interior.get_node_or_null(^"RouteMarkers/Entry") as Node3D
	if entry == null:
		push_error("DarkEntrance: %s has no RouteMarkers/Entry" % target_scene.resource_path)
		_interior.queue_free()
		_interior = null
		_armed = true
		return
	var exit_marker: Node3D = _interior.get_node_or_null(^"RouteMarkers/Exit") as Node3D
	# Without an authored Exit the mouth doubles as the way out, but then
	# the arrival overlap must not bounce Nau straight back: the exit
	# volume arms only after he has left it once.
	_exit_armed = exit_marker != null
	_add_exit_volume(exit_marker if exit_marker != null else entry)

	_teleport(player, entry.global_transform)


func _add_exit_volume(marker: Node3D) -> void:
	var volume: Area3D = Area3D.new()
	volume.collision_layer = 0
	volume.collision_mask = 2
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = EXIT_BOX_SIZE
	shape.shape = box
	volume.add_child(shape)
	marker.add_child(volume)
	volume.body_entered.connect(_on_exit_touched)
	volume.body_exited.connect(_on_exit_left)


func _on_exit_left(body: Node3D) -> void:
	if body is Player:
		_exit_armed = true


func _on_exit_touched(body: Node3D) -> void:
	if not body is Player or _interior == null or not _exit_armed:
		return
	var interior: Node3D = _interior
	_interior = null
	_leave.call_deferred(body, interior)


func _leave(player: Node3D, interior: Node3D) -> void:
	_rescue_carried(player, interior)
	interior.queue_free()
	_teleport(player, _return_transform)


## Carried bodies are not reparented by the carry system; one picked up
## inside the interior would be freed with it mid-carry.
func _rescue_carried(player: Node3D, interior: Node3D) -> void:
	var carry: CarryController = player.get_node_or_null(^"CarryController") as CarryController
	if carry == null or carry.held == null:
		return
	if interior.is_ancestor_of(carry.held):
		carry.held.reparent(self)


func _teleport(player: Node3D, destination: Transform3D) -> void:
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	player.global_transform = destination
