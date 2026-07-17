@tool
extends Node3D
class_name OdysseyScatter3D

const GENERATED_META: StringName = &"odyssey_scatter_generated"
const TRANSFORMS_META: StringName = &"odyssey_scatter_transforms"

@export_category("Sources")
@export var prop_scenes: Array[PackedScene] = []
@export_range(1, 100000, 1) var seed: int = 1

@export_category("Distribution")
@export var bounds_size_m: Vector2 = Vector2(100.0, 100.0)
@export_range(0.0, 1000.0, 0.1) var density_per_100m2: float = 2.0
@export_range(1, 100000, 1) var max_instances: int = 10000
@export_range(1, 32, 1) var attempts_per_instance: int = 8

@export_category("Surface Rules")
@export_range(0.0, 90.0, 0.1) var minimum_slope_degrees: float = 0.0
@export_range(0.0, 90.0, 0.1) var maximum_slope_degrees: float = 45.0
@export var minimum_altitude_m: float = -100.0
@export var maximum_altitude_m: float = 500.0
@export_flags_3d_physics var surface_collision_mask: int = 1
@export_range(1.0, 5000.0, 1.0) var raycast_margin_m: float = 100.0

@export_category("Transform Variation")
@export var random_yaw: bool = true
@export var align_to_surface_normal: bool = true
@export_range(0.01, 10.0, 0.01) var minimum_scale: float = 0.85
@export_range(0.01, 10.0, 0.01) var maximum_scale: float = 1.15
@export_storage var paint_stroke_index: int = 0


func rebuild() -> Dictionary:
	clear_generated()
	var validation_error: String = _validate_configuration()
	if not validation_error.is_empty():
		return {"ok": false, "error": validation_error}
	if not is_inside_tree() or get_world_3d() == null:
		return {"ok": false, "error": "Scatter node must be inside an edited 3D scene"}

	var source_meshes: Array[Dictionary] = []
	for prop_scene: PackedScene in prop_scenes:
		var source_data: Dictionary = _extract_source_mesh(prop_scene)
		if bool(source_data.get("ok", false)):
			source_meshes.append(source_data)
	if source_meshes.is_empty():
		return {"ok": false, "error": "No prop scene contains a usable MeshInstance3D"}

	var area_m2: float = bounds_size_m.x * bounds_size_m.y
	var requested_count: int = mini(
		max_instances,
		maxi(0, roundi(area_m2 * density_per_100m2 / 100.0))
	)
	if requested_count == 0:
		return {"ok": true, "placed": 0, "requested": 0}

	var transforms_by_source: Array[Array] = []
	transforms_by_source.resize(source_meshes.size())
	for source_index: int in transforms_by_source.size():
		transforms_by_source[source_index] = []
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var placed_count: int = 0
	var maximum_attempts: int = requested_count * attempts_per_instance
	for _attempt: int in maximum_attempts:
		if placed_count >= requested_count:
			break
		var local_offset: Vector3 = Vector3(
			random.randf_range(-bounds_size_m.x * 0.5, bounds_size_m.x * 0.5),
			0.0,
			random.randf_range(-bounds_size_m.y * 0.5, bounds_size_m.y * 0.5)
		)
		var world_sample: Vector3 = global_transform * local_offset
		var ray_start: Vector3 = Vector3(world_sample.x, maximum_altitude_m + raycast_margin_m, world_sample.z)
		var ray_end: Vector3 = Vector3(world_sample.x, minimum_altitude_m - raycast_margin_m, world_sample.z)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			ray_start, ray_end, surface_collision_mask
		)
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var position: Vector3 = hit.get("position", Vector3.ZERO) as Vector3
		var normal: Vector3 = (hit.get("normal", Vector3.UP) as Vector3).normalized()
		if position.y < minimum_altitude_m or position.y > maximum_altitude_m:
			continue
		var slope_degrees: float = rad_to_deg(acos(clampf(normal.dot(Vector3.UP), -1.0, 1.0)))
		if slope_degrees < minimum_slope_degrees or slope_degrees > maximum_slope_degrees:
			continue
		var source_index: int = random.randi_range(0, source_meshes.size() - 1)
		var scale_value: float = random.randf_range(minimum_scale, maximum_scale)
		var yaw: float = random.randf_range(0.0, TAU) if random_yaw else 0.0
		var basis: Basis = _basis_for_surface(normal, yaw).scaled(Vector3.ONE * scale_value)
		var world_instance_transform: Transform3D = Transform3D(basis, position)
		var local_instance_transform: Transform3D = global_transform.affine_inverse() * world_instance_transform
		(transforms_by_source[source_index] as Array).append(local_instance_transform)
		placed_count += 1

	for source_index: int in source_meshes.size():
		var transforms: Array = transforms_by_source[source_index]
		if transforms.is_empty():
			continue
		_create_multimesh(source_meshes[source_index], transforms, source_index)
	return {"ok": true, "placed": placed_count, "requested": requested_count}


func clear_generated() -> void:
	for child: Node in get_children():
		if child.has_meta(GENERATED_META):
			remove_child(child)
			child.queue_free()
	paint_stroke_index = 0


func paint_at(world_position: Vector3, brush_radius_m: float) -> Dictionary:
	var validation_error: String = _validate_configuration()
	if not validation_error.is_empty():
		return {"ok": false, "error": validation_error}
	if brush_radius_m <= 0.0:
		return {"ok": false, "error": "Paint brush radius must be positive"}
	if not is_inside_tree() or get_world_3d() == null:
		return {"ok": false, "error": "Scatter node must be inside an edited 3D scene"}
	var current_count: int = _current_instance_count()
	var remaining_capacity: int = maxi(0, max_instances - current_count)
	if remaining_capacity == 0:
		return {"ok": false, "error": "Scatter reached max_instances"}
	var source_meshes: Array[Dictionary] = []
	for prop_scene: PackedScene in prop_scenes:
		var source_data: Dictionary = _extract_source_mesh(prop_scene)
		if bool(source_data.get("ok", false)):
			source_meshes.append(source_data)
	if source_meshes.is_empty():
		return {"ok": false, "error": "No prop scene contains a usable MeshInstance3D"}
	var brush_area_m2: float = PI * brush_radius_m * brush_radius_m
	var requested_count: int = mini(
		remaining_capacity,
		maxi(1, roundi(brush_area_m2 * density_per_100m2 / 100.0))
	)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed + paint_stroke_index * 104729
	var transforms_by_source: Array[Array] = []
	transforms_by_source.resize(source_meshes.size())
	for source_index: int in transforms_by_source.size():
		transforms_by_source[source_index] = []
	var placed_count: int = 0
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for _attempt: int in requested_count * attempts_per_instance:
		if placed_count >= requested_count:
			break
		var angle: float = random.randf_range(0.0, TAU)
		var distance: float = sqrt(random.randf()) * brush_radius_m
		var sample_position: Vector3 = world_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		var surface: Dictionary = _sample_surface(sample_position, space_state)
		if surface.is_empty():
			continue
		var source_index: int = random.randi_range(0, source_meshes.size() - 1)
		var scale_value: float = random.randf_range(minimum_scale, maximum_scale)
		var yaw: float = random.randf_range(0.0, TAU) if random_yaw else 0.0
		var normal: Vector3 = surface.get("normal", Vector3.UP) as Vector3
		var basis: Basis = _basis_for_surface(normal, yaw).scaled(Vector3.ONE * scale_value)
		var world_instance_transform: Transform3D = Transform3D(
			basis, surface.get("position", Vector3.ZERO) as Vector3
		)
		var local_instance_transform: Transform3D = global_transform.affine_inverse() * world_instance_transform
		(transforms_by_source[source_index] as Array).append(local_instance_transform)
		placed_count += 1
	for source_index: int in source_meshes.size():
		var transforms: Array = transforms_by_source[source_index]
		if not transforms.is_empty():
			_append_multimesh(source_meshes[source_index], transforms, source_index)
	paint_stroke_index += 1
	return {"ok": true, "placed": placed_count, "requested": requested_count}


func erase_at(world_position: Vector3, brush_radius_m: float) -> Dictionary:
	if brush_radius_m <= 0.0:
		return {"ok": false, "error": "Erase brush radius must be positive"}
	var removed_count: int = 0
	for child: Node in get_children():
		if not child.has_meta(GENERATED_META) or not child is MultiMeshInstance3D:
			continue
		var instance: MultiMeshInstance3D = child as MultiMeshInstance3D
		if instance.multimesh == null:
			continue
		var retained: Array[Transform3D] = []
		var stored_transforms: Array = instance.get_meta(TRANSFORMS_META, []) as Array
		for transform_value: Variant in stored_transforms:
			var instance_transform: Transform3D = transform_value as Transform3D
			var instance_world_position: Vector3 = global_transform * instance_transform.origin
			var horizontal_distance: float = Vector2(
				instance_world_position.x - world_position.x,
				instance_world_position.z - world_position.z
			).length()
			if horizontal_distance <= brush_radius_m:
				removed_count += 1
			else:
				retained.append(instance_transform)
		if retained.is_empty():
			remove_child(instance)
			instance.queue_free()
		else:
			_replace_transforms(instance, retained)
	return {"ok": true, "removed": removed_count}


func capture_generated_state() -> Dictionary:
	var groups: Array[Dictionary] = []
	for child: Node in get_children():
		if not child.has_meta(GENERATED_META) or not child is MultiMeshInstance3D:
			continue
		var instance: MultiMeshInstance3D = child as MultiMeshInstance3D
		if instance.multimesh == null or instance.multimesh.mesh == null:
			continue
		var transforms: Array = (instance.get_meta(TRANSFORMS_META, []) as Array).duplicate()
		groups.append({
			"name": instance.name,
			"mesh": instance.multimesh.mesh,
			"material": instance.material_override,
			"source_path": str(instance.get_meta(&"source_scene", "")),
			"transforms": transforms,
		})
	return {"paint_stroke_index": paint_stroke_index, "groups": groups}


func restore_generated_state(state: Dictionary) -> void:
	clear_generated()
	paint_stroke_index = int(state.get("paint_stroke_index", 0))
	var groups: Array = state.get("groups", []) as Array
	for group_value: Variant in groups:
		if not group_value is Dictionary:
			continue
		var group: Dictionary = group_value as Dictionary
		_create_multimesh_group(
			str(group.get("name", "Scatter")),
			group.get("mesh") as Mesh,
			group.get("material") as Material,
			group.get("transforms", []) as Array,
			str(group.get("source_path", ""))
		)


func _validate_configuration() -> String:
	if prop_scenes.is_empty():
		return "Assign at least one prop scene"
	if bounds_size_m.x <= 0.0 or bounds_size_m.y <= 0.0:
		return "Scatter bounds must be positive"
	if minimum_slope_degrees > maximum_slope_degrees:
		return "Minimum slope cannot exceed maximum slope"
	if minimum_altitude_m > maximum_altitude_m:
		return "Minimum altitude cannot exceed maximum altitude"
	if minimum_scale > maximum_scale:
		return "Minimum scale cannot exceed maximum scale"
	return ""


func _extract_source_mesh(prop_scene: PackedScene) -> Dictionary:
	if prop_scene == null:
		return {"ok": false}
	var instance: Node = prop_scene.instantiate()
	var mesh_instance: MeshInstance3D = _find_mesh_instance(instance)
	if mesh_instance == null or mesh_instance.mesh == null:
		instance.free()
		return {"ok": false}
	var material: Material = mesh_instance.material_override
	if material == null and mesh_instance.mesh.get_surface_count() > 0:
		material = mesh_instance.get_active_material(0)
	var result: Dictionary = {
		"ok": true,
		"mesh": mesh_instance.mesh,
		"material": material,
		"source_path": prop_scene.resource_path,
		"mesh_transform": _relative_transform(instance, mesh_instance),
	}
	instance.free()
	return result


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var found: MeshInstance3D = _find_mesh_instance(child)
		if found != null:
			return found
	return null


func _relative_transform(root_node: Node, mesh_instance: MeshInstance3D) -> Transform3D:
	if not root_node is Node3D:
		return mesh_instance.transform
	var transform: Transform3D = Transform3D.IDENTITY
	var current: Node = mesh_instance
	while current != root_node and current is Node3D:
		transform = (current as Node3D).transform * transform
		current = current.get_parent()
	return transform


func _basis_for_surface(normal: Vector3, yaw: float) -> Basis:
	if not align_to_surface_normal:
		return Basis(Vector3.UP, yaw)
	var tangent: Vector3 = Vector3.FORWARD.cross(normal)
	if tangent.length_squared() < 0.0001:
		tangent = Vector3.RIGHT
	else:
		tangent = tangent.normalized()
	var bitangent: Vector3 = tangent.cross(normal).normalized()
	var aligned_basis: Basis = Basis(tangent, normal, bitangent)
	return Basis(normal, yaw) * aligned_basis


func _sample_surface(
	world_sample: Vector3,
	space_state: PhysicsDirectSpaceState3D
) -> Dictionary:
	var ray_start: Vector3 = Vector3(world_sample.x, maximum_altitude_m + raycast_margin_m, world_sample.z)
	var ray_end: Vector3 = Vector3(world_sample.x, minimum_altitude_m - raycast_margin_m, world_sample.z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ray_start, ray_end, surface_collision_mask
	)
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var position: Vector3 = hit.get("position", Vector3.ZERO) as Vector3
	var normal: Vector3 = (hit.get("normal", Vector3.UP) as Vector3).normalized()
	if position.y < minimum_altitude_m or position.y > maximum_altitude_m:
		return {}
	var slope_degrees: float = rad_to_deg(acos(clampf(normal.dot(Vector3.UP), -1.0, 1.0)))
	if slope_degrees < minimum_slope_degrees or slope_degrees > maximum_slope_degrees:
		return {}
	return {"position": position, "normal": normal}


func _create_multimesh(source: Dictionary, transforms: Array, source_index: int) -> void:
	var mesh_transform: Transform3D = source.get("mesh_transform", Transform3D.IDENTITY) as Transform3D
	var transformed_instances: Array[Transform3D] = []
	for value: Variant in transforms:
		transformed_instances.append((value as Transform3D) * mesh_transform)
	_create_multimesh_group(
		"Scatter_%02d" % source_index,
		source.get("mesh") as Mesh,
		source.get("material") as Material,
		transformed_instances,
		str(source.get("source_path", ""))
	)


func _append_multimesh(source: Dictionary, transforms: Array, source_index: int) -> void:
	var source_path: String = str(source.get("source_path", ""))
	var target: MultiMeshInstance3D
	for child: Node in get_children():
		if child is MultiMeshInstance3D and child.has_meta(GENERATED_META):
			if str(child.get_meta(&"source_scene", "")) == source_path:
				target = child as MultiMeshInstance3D
				break
	if target == null:
		_create_multimesh(source, transforms, source_index)
		return
	var combined: Array[Transform3D] = []
	for transform_value: Variant in target.get_meta(TRANSFORMS_META, []) as Array:
		combined.append(transform_value as Transform3D)
	var mesh_transform: Transform3D = source.get("mesh_transform", Transform3D.IDENTITY) as Transform3D
	for value: Variant in transforms:
		combined.append((value as Transform3D) * mesh_transform)
	_replace_transforms(target, combined)


func _create_multimesh_group(
	group_name: String,
	mesh_resource: Mesh,
	material: Material,
	transforms: Array,
	source_path: String
) -> void:
	if mesh_resource == null or transforms.is_empty():
		return
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh_resource
	multimesh.instance_count = transforms.size()
	for instance_index: int in transforms.size():
		multimesh.set_instance_transform(instance_index, transforms[instance_index] as Transform3D)
	var generated: MultiMeshInstance3D = MultiMeshInstance3D.new()
	generated.name = group_name
	generated.multimesh = multimesh
	generated.material_override = material
	generated.set_meta(GENERATED_META, true)
	generated.set_meta(&"source_scene", source_path)
	generated.set_meta(TRANSFORMS_META, transforms.duplicate())
	add_child(generated)
	if owner != null:
		generated.owner = owner


func _replace_transforms(instance: MultiMeshInstance3D, transforms: Array) -> void:
	instance.multimesh.instance_count = 0
	instance.multimesh.instance_count = transforms.size()
	for instance_index: int in transforms.size():
		instance.multimesh.set_instance_transform(instance_index, transforms[instance_index] as Transform3D)
	instance.set_meta(TRANSFORMS_META, transforms.duplicate())


func _current_instance_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is MultiMeshInstance3D and child.has_meta(GENERATED_META):
			var instance: MultiMeshInstance3D = child as MultiMeshInstance3D
			if instance.multimesh != null:
				count += instance.multimesh.instance_count
	return count
