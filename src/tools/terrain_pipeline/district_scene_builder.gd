extends RefCounted

const WORLD_LAYER: int = 1
const CLIMBABLE_LAYER: int = 1 << 2
const STYLIZED_SURFACE_SHADER: Shader = preload("res://addons/odyssey_world_tools/shaders/lanka_stylized_surface.gdshader")
const ROCK_DETAIL_TEXTURE: Texture2D = preload("res://assets/materials/library/ambient_cg/rock064/rock064_albedo.png")
const FIRE_SHADER: Shader = preload("res://addons/odyssey_world_tools/shaders/lanka_fire.gdshader")
const SMOKE_SHADER: Shader = preload("res://addons/odyssey_world_tools/shaders/lanka_smoke.gdshader")
const HEAT_SHADER: Shader = preload("res://addons/odyssey_world_tools/shaders/lanka_heat_haze.gdshader")
const OCEAN_SHADER: Shader = preload("res://addons/odyssey_world_tools/shaders/lanka_ocean_scenery.gdshader")
const FIRE_VISIBILITY_RANGE_M: float = 90.0
const SMOKE_VISIBILITY_RANGE_M: float = 130.0
const HEAT_VISIBILITY_RANGE_M: float = 65.0


func make_material(name: String, color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func make_stylized_material(
	name: String,
	base_tint: Color,
	roughness: float = 0.9,
	metallic: float = 0.0,
	wetness: float = 0.0,
	soot_amount: float = 0.0,
	ash_amount: float = 0.0,
	emission_energy: float = 0.0,
	emission_tint: Color = Color(1.0, 0.20, 0.02),
	detail_strength: float = 0.32,
	accent_tint: Color = Color.TRANSPARENT
) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_name = name
	material.shader = STYLIZED_SURFACE_SHADER
	material.set_shader_parameter(&"detail_albedo", ROCK_DETAIL_TEXTURE)
	material.set_shader_parameter(&"base_tint", base_tint)
	material.set_shader_parameter(
		&"accent_tint", base_tint.darkened(0.56) if accent_tint == Color.TRANSPARENT else accent_tint
	)
	material.set_shader_parameter(&"ash_tint", Color(0.59, 0.60, 0.56))
	material.set_shader_parameter(&"surface_roughness", roughness)
	material.set_shader_parameter(&"surface_metallic", metallic)
	material.set_shader_parameter(&"wetness", wetness)
	material.set_shader_parameter(&"soot_amount", soot_amount)
	material.set_shader_parameter(&"ash_amount", ash_amount)
	material.set_shader_parameter(&"emission_energy", emission_energy)
	material.set_shader_parameter(&"emission_tint", emission_tint)
	material.set_shader_parameter(&"detail_strength", detail_strength)
	return material


func make_water_scenery_material(name: String, wave_height: float = 0.25) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.resource_name = name
	material.shader = OCEAN_SHADER
	material.set_shader_parameter(&"deep_color", Color(0.012, 0.055, 0.052))
	material.set_shader_parameter(&"shallow_color", Color(0.055, 0.18, 0.16))
	material.set_shader_parameter(&"foam_color", Color(0.42, 0.48, 0.43))
	material.set_shader_parameter(&"wave_height", wave_height)
	material.set_shader_parameter(&"wave_scale", 0.055)
	material.set_shader_parameter(&"wave_speed", 0.08)
	material.set_shader_parameter(&"mask_island", false)
	return material


func add_fire_visual(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	scale_value: float = 1.0
) -> Node3D:
	var visual: Node3D = Node3D.new()
	visual.name = node_name
	visual.position = position
	visual.scale = Vector3.ONE * scale_value
	visual.set_meta(&"visual_only", true)
	visual.set_meta(&"gameplay_behavior", "SYSTEMS_owned")
	visual.set_meta(&"vfx_profile", "fire_smoke_heat")
	parent.add_child(visual)
	for plane_index: int in 2:
		var flame: MeshInstance3D = MeshInstance3D.new()
		flame.name = "FlamePlane%02d" % plane_index
		flame.position.y = 2.1
		flame.rotation_degrees.y = float(plane_index) * 90.0
		var flame_mesh: QuadMesh = QuadMesh.new()
		flame_mesh.size = Vector2(2.7, 4.5)
		var flame_material: ShaderMaterial = ShaderMaterial.new()
		flame_material.resource_name = "mat_lanka_fire_visual_grip_hot"
		flame_material.shader = FIRE_SHADER
		flame_material.set_shader_parameter(&"motion_offset", float(plane_index) * 1.7)
		flame_mesh.material = flame_material
		flame.mesh = flame_mesh
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.visibility_range_end = FIRE_VISIBILITY_RANGE_M
		flame.visibility_range_end_margin = 8.0
		visual.add_child(flame)
	for smoke_index: int in 2:
		var smoke: MeshInstance3D = MeshInstance3D.new()
		smoke.name = "SmokePlane%02d" % smoke_index
		smoke.position = Vector3(0.0, 5.0 + float(smoke_index) * 1.6, 0.0)
		smoke.rotation_degrees.y = float(smoke_index) * 90.0 + 24.0
		var smoke_mesh: QuadMesh = QuadMesh.new()
		smoke_mesh.size = Vector2(5.6, 8.5)
		var smoke_material: ShaderMaterial = ShaderMaterial.new()
		smoke_material.resource_name = "mat_lanka_smoke_visual_grip_solid"
		smoke_material.shader = SMOKE_SHADER
		smoke_material.set_shader_parameter(&"motion_offset", float(smoke_index) * 0.43)
		smoke_mesh.material = smoke_material
		smoke.mesh = smoke_mesh
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke.visibility_range_end = SMOKE_VISIBILITY_RANGE_M
		smoke.visibility_range_end_margin = 12.0
		visual.add_child(smoke)
	var heat: MeshInstance3D = MeshInstance3D.new()
	heat.name = "HeatHaze"
	heat.position.y = 2.6
	var heat_mesh: QuadMesh = QuadMesh.new()
	heat_mesh.size = Vector2(5.0, 5.2)
	var heat_material: ShaderMaterial = ShaderMaterial.new()
	heat_material.resource_name = "mat_lanka_heat_haze_visual_grip_hot"
	heat_material.shader = HEAT_SHADER
	heat_mesh.material = heat_material
	heat.mesh = heat_mesh
	heat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	heat.visibility_range_end = HEAT_VISIBILITY_RANGE_M
	heat.visibility_range_end_margin = 6.0
	visual.add_child(heat)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "FireLight"
	light.position.y = 2.0
	light.light_color = Color(1.0, 0.28, 0.045)
	light.light_energy = 4.2
	light.light_volumetric_fog_energy = 1.45
	light.omni_range = 15.0
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 36.0
	light.distance_fade_shadow = 28.0
	light.distance_fade_length = 18.0
	visual.add_child(light)
	var notifier: VisibleOnScreenNotifier3D = VisibleOnScreenNotifier3D.new()
	notifier.name = "VisibilityNotifier"
	notifier.aabb = AABB(Vector3(-4.0, 0.0, -4.0), Vector3(8.0, 13.0, 8.0))
	visual.add_child(notifier)
	return visual


func add_static_box(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector3,
	material: Material,
	climbable: bool = false,
	rotation_degrees_value: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation_degrees = rotation_degrees_value
	body.collision_layer = WORLD_LAYER | (CLIMBABLE_LAYER if climbable else 0)
	body.collision_mask = 0
	parent.add_child(body)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	body.add_child(mesh_instance)
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	body.add_child(collision_shape)
	return body


func add_static_cylinder(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	radius: float,
	height: float,
	material: Material,
	climbable: bool = false,
	rotation_degrees_value: Vector3 = Vector3.ZERO,
	radial_segments: int = 16
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation_degrees = rotation_degrees_value
	body.collision_layer = WORLD_LAYER | (CLIMBABLE_LAYER if climbable else 0)
	body.collision_mask = 0
	parent.add_child(body)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var cylinder_mesh: CylinderMesh = CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius * 1.08
	cylinder_mesh.height = height
	cylinder_mesh.radial_segments = radial_segments
	cylinder_mesh.rings = 3
	cylinder_mesh.material = material
	mesh_instance.mesh = cylinder_mesh
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	body.add_child(mesh_instance)
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	var cylinder_shape: CylinderShape3D = CylinderShape3D.new()
	cylinder_shape.radius = radius
	cylinder_shape.height = height
	collision_shape.shape = cylinder_shape
	body.add_child(collision_shape)
	return body


func add_visual_box(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector3,
	material: Material,
	rotation_degrees_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_degrees_value
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	parent.add_child(mesh_instance)
	return mesh_instance


func add_visual_plane(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector2,
	material: Material,
	subdivisions: Vector2i = Vector2i(24, 18)
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = size
	plane_mesh.subdivide_width = subdivisions.x
	plane_mesh.subdivide_depth = subdivisions.y
	plane_mesh.material = material
	mesh_instance.mesh = plane_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return mesh_instance


func add_marker(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	socket_type: StringName,
	metadata: Dictionary = {}
) -> Marker3D:
	var marker: Marker3D = Marker3D.new()
	marker.name = node_name
	marker.position = position
	marker.set_meta(&"socket_type", socket_type)
	for key_value: Variant in metadata:
		marker.set_meta(key_value as StringName, metadata[key_value])
	parent.add_child(marker)
	return marker


func add_box_occluder(parent: Node3D, node_name: String, position: Vector3, size: Vector3) -> OccluderInstance3D:
	var resource: BoxOccluder3D = BoxOccluder3D.new()
	resource.size = size
	var occluder: OccluderInstance3D = OccluderInstance3D.new()
	occluder.name = node_name
	occluder.position = position
	occluder.occluder = resource
	parent.add_child(occluder)
	return occluder


func add_visibility_notifier(parent: Node3D, aabb: AABB) -> VisibleOnScreenNotifier3D:
	var notifier: VisibleOnScreenNotifier3D = VisibleOnScreenNotifier3D.new()
	notifier.name = "VisibilityNotifier"
	notifier.aabb = aabb
	parent.add_child(notifier)
	return notifier


func finish_scene(root: Node3D, path: String) -> Error:
	prepare_scene(root)
	return save_prepared_scene(root, path)


func prepare_scene(root: Node3D) -> void:
	_batch_repeatable_geometry(root)
	_set_owner_recursive(root, root)


func save_prepared_scene(root: Node3D, path: String) -> Error:
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(root)
	if pack_error != OK:
		return pack_error
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	return ResourceSaver.save(packed, path)


func _batch_repeatable_geometry(root: Node3D) -> void:
	var candidates_by_key: Dictionary = {}
	_collect_batch_candidates(root, root, candidates_by_key)
	var batches: Node3D = Node3D.new()
	batches.name = "M8RenderBatches"
	batches.set_meta(&"m8_material_batching", true)
	root.add_child(batches)
	var batch_index: int = 0
	for key_value: Variant in candidates_by_key:
		var candidates: Array = candidates_by_key[key_value] as Array
		if candidates.size() < 2:
			continue
		var first: Dictionary = candidates[0] as Dictionary
		var unit_mesh: PrimitiveMesh = _make_unit_batch_mesh(first)
		if unit_mesh == null:
			continue
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = unit_mesh
		multimesh.instance_count = candidates.size()
		for instance_index: int in candidates.size():
			var candidate: Dictionary = candidates[instance_index] as Dictionary
			multimesh.set_instance_transform(instance_index, candidate[&"transform"] as Transform3D)
			(candidate[&"node"] as MeshInstance3D).visible = false
		var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
		batch.name = "GeometryBatch%02d_%s" % [batch_index, _safe_node_suffix(str(first[&"material_name"]))]
		batch.multimesh = multimesh
		batch.cast_shadow = first[&"cast_shadow"] as GeometryInstance3D.ShadowCastingSetting
		batch.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		batch.set_meta(&"m8_batch_instance_count", candidates.size())
		batch.set_meta(&"m8_batch_shape", first[&"shape"] as StringName)
		batch.set_meta(&"m8_batch_material", first[&"material_name"] as String)
		batches.add_child(batch)
		batch_index += 1
	batches.set_meta(&"m8_batch_count", batch_index)


func _collect_batch_candidates(node: Node, root: Node3D, candidates_by_key: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var candidate: Dictionary = _make_batch_candidate(mesh_instance, root)
		if not candidate.is_empty():
			var key: String = str(candidate[&"key"])
			if not candidates_by_key.has(key):
				candidates_by_key[key] = []
			(candidates_by_key[key] as Array).append(candidate)
	for child: Node in node.get_children():
		_collect_batch_candidates(child, root, candidates_by_key)


func _make_batch_candidate(mesh_instance: MeshInstance3D, root: Node3D) -> Dictionary:
	var primitive: PrimitiveMesh = mesh_instance.mesh as PrimitiveMesh
	if primitive == null or not (primitive is BoxMesh or primitive is CylinderMesh):
		return {}
	var material: Material = primitive.material
	if material == null or material.resource_name.is_empty():
		return {}
	var shape: StringName = &"box"
	var local_scale: Vector3 = Vector3.ONE
	var topology: String = "unit"
	if primitive is BoxMesh:
		local_scale = (primitive as BoxMesh).size
	else:
		var cylinder: CylinderMesh = primitive as CylinderMesh
		if not is_equal_approx(cylinder.bottom_radius, cylinder.top_radius * 1.08):
			return {}
		shape = &"cylinder"
		local_scale = Vector3(cylinder.top_radius * 2.0, cylinder.height, cylinder.top_radius * 2.0)
		topology = "%d_%d" % [cylinder.radial_segments, cylinder.rings]
	var relative_transform: Transform3D = _relative_transform_to_root(mesh_instance, root)
	relative_transform *= Transform3D(Basis.from_scale(local_scale), Vector3.ZERO)
	var cast_shadow: GeometryInstance3D.ShadowCastingSetting = mesh_instance.cast_shadow
	var key: String = "%s_%s_%d_%d" % [shape, topology, material.get_instance_id(), int(cast_shadow)]
	return {
		&"key": key,
		&"node": mesh_instance,
		&"shape": shape,
		&"topology": topology,
		&"transform": relative_transform,
		&"material": material,
		&"material_name": material.resource_name,
		&"cast_shadow": cast_shadow,
	}


func _relative_transform_to_root(node: Node3D, root: Node3D) -> Transform3D:
	var relative_transform: Transform3D = node.transform
	var ancestor: Node = node.get_parent()
	while ancestor != null and ancestor != root:
		if ancestor is Node3D:
			relative_transform = (ancestor as Node3D).transform * relative_transform
		ancestor = ancestor.get_parent()
	return relative_transform


func _make_unit_batch_mesh(candidate: Dictionary) -> PrimitiveMesh:
	var material: Material = candidate[&"material"] as Material
	if candidate[&"shape"] as StringName == &"box":
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3.ONE
		box.material = material
		return box
	var topology: PackedStringArray = str(candidate[&"topology"]).split("_")
	if topology.size() != 2:
		return null
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.54
	cylinder.height = 1.0
	cylinder.radial_segments = int(topology[0])
	cylinder.rings = int(topology[1])
	cylinder.material = material
	return cylinder


func _safe_node_suffix(value: String) -> String:
	var suffix: String = value.trim_prefix("mat_")
	for character: String in ["-", ".", " ", "/"]:
		suffix = suffix.replace(character, "_")
	return suffix.to_pascal_case()


func _set_owner_recursive(node: Node, scene_owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_owner
		if not child.scene_file_path.is_empty():
			continue
		_set_owner_recursive(child, scene_owner)
