@tool
extends EditorScenePostImport

const DEFAULT_SOURCE_UNITS_PER_METER: float = 1.0
const HEIGHT_TOLERANCE_RATIO: float = 0.1


func _post_import(scene: Node) -> Object:
	var source_path: String = get_source_file()
	var profile: ConfigFile = ConfigFile.new()
	var profile_path: String = source_path + ".odyssey_import.cfg"
	if FileAccess.file_exists(profile_path):
		var profile_error: Error = profile.load(profile_path)
		if profile_error != OK:
			push_error("Invalid Odyssey import profile %s: %s" % [profile_path, error_string(profile_error)])
			return scene

	var units_per_meter: float = float(profile.get_value(
		"scale", "source_units_per_meter", DEFAULT_SOURCE_UNITS_PER_METER
	))
	if units_per_meter <= 0.0:
		push_error("source_units_per_meter must be greater than zero: %s" % profile_path)
		return scene
	if not is_equal_approx(units_per_meter, DEFAULT_SOURCE_UNITS_PER_METER):
		var import_scale: float = 1.0 / units_per_meter
		if scene is Node3D:
			var root_3d: Node3D = scene as Node3D
			root_3d.scale *= Vector3.ONE * import_scale

	var collision_mode: String = str(profile.get_value("collision", "mode", "none")).to_lower()
	if collision_mode not in ["none", "trimesh", "convex"]:
		push_error("Unsupported collision mode '%s' in %s" % [collision_mode, profile_path])
	else:
		_add_collisions(scene, collision_mode)

	var expected_height_m: float = float(profile.get_value("scale", "expected_height_m", 0.0))
	if expected_height_m > 0.0:
		_validate_height(scene, expected_height_m, source_path)
	return scene


func _add_collisions(node: Node, mode: String) -> void:
	if mode != "none" and node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			if mode == "trimesh":
				mesh_instance.create_trimesh_collision()
			else:
				mesh_instance.create_multiple_convex_collisions()
	for child: Node in node.get_children():
		_add_collisions(child, mode)


func _validate_height(scene: Node, expected_height_m: float, source_path: String) -> void:
	var bounds: AABB = _collect_bounds(scene, Transform3D.IDENTITY, AABB(), false)
	if bounds.size == Vector3.ZERO:
		push_warning("No mesh bounds found for scale validation: %s" % source_path)
		return
	var difference_ratio: float = absf(bounds.size.y - expected_height_m) / expected_height_m
	if difference_ratio > HEIGHT_TOLERANCE_RATIO:
		push_error(
			"Scale contract failed for %s: imported height %.3fm, expected %.3fm (+/- %.0f%%)."
			% [source_path, bounds.size.y, expected_height_m, HEIGHT_TOLERANCE_RATIO * 100.0]
		)


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
