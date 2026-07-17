class_name CairnEntrance
extends Area3D
## Cairn doorway (WORLD's M9 prefab request). WORLD instances one per
## Cairn socket and the builder assigns `cairn_id` and `target_scene`.
## Nau crossing it loads the Cairn interior far below the doorway
## (streaming distance is horizontal, so the host district stays
## resident), transfers him to the interior's `RouteMarkers/Entry`, and
## wires two runtime touch volumes inside it: one over each
## `heart_piece_reward` socket that emits `cairn_completed(cairn_id)`,
## and one over `RouteMarkers/Exit` that returns Nau to the doorway and
## frees the interior. GameState owns the consequences of
## `cairn_completed` (the heart piece and the autosave), so completing a
## Cairn twice is safely ignored there.

const INTERIOR_DEPTH_M: float = 600.0
const TOUCH_BOX_SIZE: Vector3 = Vector3(3.0, 3.0, 3.0)

@export var cairn_id: StringName = &""
@export var target_scene: PackedScene

var _interior: Node3D = null
var _armed: bool = true
var _return_transform: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # the player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player or not _armed or _interior != null:
		return
	if cairn_id == &"" or target_scene == null:
		push_warning("CairnEntrance: cairn_id or target_scene not set")
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
		push_error("CairnEntrance: %s root must be Node3D" % target_scene.resource_path)
		_armed = true
		return
	_interior.top_level = true
	add_child(_interior)
	var doorway: Vector3 = global_position
	_interior.global_transform = Transform3D(
		Basis.IDENTITY, doorway + Vector3(0.0, -INTERIOR_DEPTH_M, 0.0)
	)

	var entry: Node3D = _interior.get_node_or_null(^"RouteMarkers/Entry") as Node3D
	if entry == null:
		push_error("CairnEntrance: %s has no RouteMarkers/Entry" % target_scene.resource_path)
		_interior.queue_free()
		_interior = null
		_armed = true
		return
	var exit_marker: Node3D = _interior.get_node_or_null(^"RouteMarkers/Exit") as Node3D
	_add_touch_volume(exit_marker if exit_marker != null else entry, _on_exit_reached)
	for socket: Node in _interior.find_children("*", "Marker3D", true, false):
		if socket.get_meta(&"socket_type", &"") == &"heart_piece_reward":
			_add_touch_volume(socket as Node3D, _on_reward_reached)

	_teleport(player, entry.global_transform)


func _add_touch_volume(marker: Node3D, entered: Callable) -> void:
	var volume: Area3D = Area3D.new()
	volume.collision_layer = 0
	volume.collision_mask = 2
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = TOUCH_BOX_SIZE
	shape.shape = box
	volume.add_child(shape)
	marker.add_child(volume)
	volume.body_entered.connect(entered)


func _on_reward_reached(body: Node3D) -> void:
	if body is Player:
		EventBus.cairn_completed.emit(cairn_id)


func _on_exit_reached(body: Node3D) -> void:
	if not body is Player or _interior == null:
		return
	var interior: Node3D = _interior
	_interior = null
	interior.queue_free()
	_return.call_deferred(body)


func _return(player: Node3D) -> void:
	_teleport(player, _return_transform)


func _teleport(player: Node3D, destination: Transform3D) -> void:
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	player.global_transform = destination
