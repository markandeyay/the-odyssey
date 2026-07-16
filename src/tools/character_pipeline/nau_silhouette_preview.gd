@tool
extends Node3D

const VISUAL_PATH: String = "res://assets/characters/nau/nau_visual.tscn"

@export_range(25.0, 250.0, 1.0, "suffix:m") var viewing_distance_m: float = 200.0:
	set(value):
		viewing_distance_m = value
		_update_camera()


func _ready() -> void:
	if get_node_or_null("NauVisual") == null:
		_load_visual()
	_update_camera()


func _load_visual() -> void:
	if not ResourceLoader.exists(VISUAL_PATH, "PackedScene"):
		push_warning("M3 silhouette preview is waiting for %s" % VISUAL_PATH)
		return
	var packed: PackedScene = load(VISUAL_PATH) as PackedScene
	var visual: Node = packed.instantiate()
	visual.name = "NauVisual"
	add_child(visual)
	if visual is Node3D:
		var bounds: AABB = _collect_bounds(visual, Transform3D.IDENTITY, AABB(), false)
		(visual as Node3D).position.y -= bounds.position.y
	var players: Array[Node] = visual.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		(players[0] as AnimationPlayer).play(&"idle")


func _update_camera() -> void:
	var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	camera.fov = 8.0 if viewing_distance_m >= 100.0 else 22.5
	camera.position = Vector3(0.0, 1.05, viewing_distance_m)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)


func _collect_bounds(node: Node, parent_transform: Transform3D, bounds: AABB, has_bounds: bool) -> AABB:
	var current_transform: Transform3D = parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_bounds: AABB = current_transform * mesh_instance.get_aabb()
			bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
			has_bounds = true
	for child: Node in node.get_children():
		var child_bounds: AABB = _collect_bounds(child, current_transform, AABB(), false)
		if child_bounds.size != Vector3.ZERO:
			bounds = bounds.merge(child_bounds) if has_bounds else child_bounds
			has_bounds = true
	return bounds
