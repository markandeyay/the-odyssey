extends RefCounted

const BUDGETS_PATH: String = "res://src/tools/world_tooling/scene_budgets.cfg"
const LANKA_SCENE_ROOTS: PackedStringArray = [
	"res://scenes/levels/lanka",
	"res://scenes/levels/cairns",
]

var _budgets: ConfigFile


func _init() -> void:
	_budgets = ConfigFile.new()
	var load_error: Error = _budgets.load(BUDGETS_PATH)
	assert(load_error == OK)


func available_profiles() -> PackedStringArray:
	return _budgets.get_sections()


func analyze_root(root: Node) -> Dictionary:
	var metrics: Dictionary = {
		"draw_calls": 0,
		"triangles": 0,
		"active_lights": 0,
		"mesh_instances": 0,
		"multimesh_instances": 0,
	}
	_analyze_node(root, true, metrics)
	return metrics


func validate_root(root: Node, profile: String) -> Array[String]:
	var metrics: Dictionary = analyze_root(root)
	return validate_metrics(metrics, profile)


func validate_metrics(metrics: Dictionary, profile: String) -> Array[String]:
	var issues: Array[String] = []
	var resolved_profile: String = profile if _budgets.has_section(profile) else "default"
	var max_draw_calls: int = int(_budgets.get_value(resolved_profile, "max_draw_calls", 0))
	var max_triangles: int = int(_budgets.get_value(resolved_profile, "max_triangles", 0))
	var max_active_lights: int = int(_budgets.get_value(resolved_profile, "max_active_lights", 0))
	if int(metrics.get("draw_calls", 0)) > max_draw_calls:
		issues.append(
			"%s draw calls %d exceed budget %d"
			% [resolved_profile, int(metrics.get("draw_calls", 0)), max_draw_calls]
		)
	if int(metrics.get("triangles", 0)) > max_triangles:
		issues.append(
			"%s triangles %d exceed budget %d"
			% [resolved_profile, int(metrics.get("triangles", 0)), max_triangles]
		)
	if int(metrics.get("active_lights", 0)) > max_active_lights:
		issues.append(
			"%s active lights %d exceed budget %d"
			% [resolved_profile, int(metrics.get("active_lights", 0)), max_active_lights]
		)
	return issues


func validate_lanka_scenes() -> Array[String]:
	var scene_paths: PackedStringArray = PackedStringArray()
	for root_path: String in LANKA_SCENE_ROOTS:
		_collect_scenes(root_path, scene_paths)
	var issues: Array[String] = []
	for scene_path: String in scene_paths:
		var resource: Resource = ResourceLoader.load(scene_path, "PackedScene")
		if not resource is PackedScene:
			issues.append("%s: unable to load PackedScene for budget check" % scene_path)
			continue
		var root: Node = (resource as PackedScene).instantiate()
		var profile: String = profile_for_scene(scene_path, root)
		for issue: String in validate_root(root, profile):
			issues.append("%s: %s" % [scene_path, issue])
		root.free()
	return issues


func profile_for_scene(scene_path: String, root: Node = null) -> String:
	if root != null and root.has_meta(&"budget_profile"):
		var metadata_profile: String = str(root.get_meta(&"budget_profile")).to_lower()
		if _budgets.has_section(metadata_profile):
			return metadata_profile
	var lower_path: String = scene_path.to_lower()
	for profile: String in _budgets.get_sections():
		if profile != "default" and profile in lower_path:
			return profile
	if "/cairns/" in lower_path:
		return "cairn"
	return "default"


func budget_for_profile(profile: String) -> Dictionary:
	var resolved_profile: String = profile if _budgets.has_section(profile) else "default"
	return {
		"profile": resolved_profile,
		"max_draw_calls": int(_budgets.get_value(resolved_profile, "max_draw_calls", 0)),
		"max_triangles": int(_budgets.get_value(resolved_profile, "max_triangles", 0)),
		"max_active_lights": int(_budgets.get_value(resolved_profile, "max_active_lights", 0)),
	}


func _analyze_node(node: Node, ancestors_visible: bool, metrics: Dictionary) -> void:
	var node_visible: bool = ancestors_visible
	if node is VisualInstance3D:
		node_visible = ancestors_visible and (node as VisualInstance3D).visible
	if node_visible:
		if node is MeshInstance3D:
			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			if mesh_instance.mesh != null:
				metrics["mesh_instances"] = int(metrics["mesh_instances"]) + 1
				metrics["draw_calls"] = int(metrics["draw_calls"]) + mesh_instance.mesh.get_surface_count()
				metrics["triangles"] = int(metrics["triangles"]) + _mesh_triangles(mesh_instance.mesh)
		elif node is MultiMeshInstance3D:
			var multimesh_instance: MultiMeshInstance3D = node as MultiMeshInstance3D
			if multimesh_instance.multimesh != null and multimesh_instance.multimesh.mesh != null:
				var visible_count: int = multimesh_instance.multimesh.visible_instance_count
				if visible_count < 0:
					visible_count = multimesh_instance.multimesh.instance_count
				metrics["multimesh_instances"] = int(metrics["multimesh_instances"]) + 1
				metrics["draw_calls"] = int(metrics["draw_calls"]) + multimesh_instance.multimesh.mesh.get_surface_count()
				metrics["triangles"] = int(metrics["triangles"]) + _mesh_triangles(multimesh_instance.multimesh.mesh) * visible_count
		elif node is GridMap:
			_analyze_grid_map(node as GridMap, metrics)
		elif node is GPUParticles3D:
			_analyze_particles(node as GPUParticles3D, metrics)
		if node is Light3D:
			metrics["active_lights"] = int(metrics["active_lights"]) + 1
	for child: Node in node.get_children():
		_analyze_node(child, node_visible, metrics)


func _mesh_triangles(mesh: Mesh) -> int:
	var triangle_count: int = 0
	for surface_index: int in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		if not indices.is_empty():
			triangle_count += indices.size() / 3
		else:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			triangle_count += vertices.size() / 3
	return triangle_count


func _analyze_grid_map(grid_map: GridMap, metrics: Dictionary) -> void:
	if grid_map.mesh_library == null:
		return
	var item_counts: Dictionary = {}
	for cell: Vector3i in grid_map.get_used_cells():
		var item_id: int = grid_map.get_cell_item(cell)
		item_counts[item_id] = int(item_counts.get(item_id, 0)) + 1
	for item_value: Variant in item_counts:
		var item_id: int = int(item_value)
		var item_mesh: Mesh = grid_map.mesh_library.get_item_mesh(item_id)
		if item_mesh == null:
			continue
		metrics["draw_calls"] = int(metrics["draw_calls"]) + item_mesh.get_surface_count()
		metrics["triangles"] = int(metrics["triangles"]) + _mesh_triangles(item_mesh) * int(item_counts[item_id])


func _analyze_particles(particles: GPUParticles3D, metrics: Dictionary) -> void:
	for pass_index: int in particles.draw_passes:
		var pass_mesh: Mesh = particles.get_draw_pass_mesh(pass_index)
		if pass_mesh == null:
			continue
		metrics["draw_calls"] = int(metrics["draw_calls"]) + pass_mesh.get_surface_count()
		metrics["triangles"] = int(metrics["triangles"]) + _mesh_triangles(pass_mesh) * particles.amount


func _collect_scenes(root_path: String, output: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(root_path)
	if directory == null:
		return
	for filename: String in directory.get_files():
		if filename.get_extension().to_lower() == "tscn":
			output.append(root_path.path_join(filename))
	for child: String in directory.get_directories():
		_collect_scenes(root_path.path_join(child), output)
