@tool
extends MeshInstance3D
class_name OdysseyTerrain3D

const TERRAIN_SHADER: Shader = preload("res://addons/odyssey_world_tools/shaders/lanka_terrain_triplanar.gdshader")
const COLLISION_BODY_NAME: StringName = &"TerrainCollisionBody"
const COLLISION_SHAPE_NAME: StringName = &"TerrainCollisionShape"

@export_category("Geometry")
@export_range(3, 1025, 2) var grid_resolution: int = 129
@export var size_m: Vector2 = Vector2(256.0, 256.0)
@export var minimum_height_m: float = 0.0
@export var maximum_height_m: float = 80.0
@export_storage var height_data: PackedFloat32Array = PackedFloat32Array()

@export_category("Terrain Layers")
@export var low_albedo: Texture2D
@export var high_albedo: Texture2D
@export var steep_albedo: Texture2D
@export_range(0.001, 2.0, 0.001) var texture_scale: float = 0.08
@export var altitude_blend_start_m: float = 20.0
@export var altitude_blend_end_m: float = 60.0
@export_range(0.0, 1.0, 0.01) var slope_blend_start: float = 0.25
@export_range(0.0, 1.0, 0.01) var slope_blend_end: float = 0.65
@export_range(0.0, 1.0, 0.01) var roughness: float = 0.9


func import_heightmap(texture_path: String) -> Dictionary:
	var resource: Resource = ResourceLoader.load(texture_path, "Texture2D")
	if not resource is Texture2D:
		return {"ok": false, "error": "Unable to load heightmap Texture2D: %s" % texture_path}
	var image: Image = (resource as Texture2D).get_image()
	if image == null or image.is_empty():
		return {"ok": false, "error": "Heightmap contains no image data: %s" % texture_path}
	image.resize(grid_resolution, grid_resolution, Image.INTERPOLATE_BILINEAR)
	var imported_data: PackedFloat32Array = PackedFloat32Array()
	imported_data.resize(grid_resolution * grid_resolution)
	for z: int in grid_resolution:
		for x: int in grid_resolution:
			var normalized_height: float = image.get_pixel(x, z).r
			imported_data[z * grid_resolution + x] = lerpf(
				minimum_height_m, maximum_height_m, normalized_height
			)
	height_data = imported_data
	rebuild()
	return {"ok": true}


func rebuild() -> Dictionary:
	var validation_error: String = _validate_configuration()
	if not validation_error.is_empty():
		return {"ok": false, "error": validation_error}
	_ensure_height_data()
	mesh = _build_mesh()
	material_override = _build_material()
	_update_collision()
	return {
		"ok": true,
		"vertices": grid_resolution * grid_resolution,
		"triangles": (grid_resolution - 1) * (grid_resolution - 1) * 2,
	}


func sculpt(local_position: Vector3, radius_m: float, strength_m: float, mode: String) -> void:
	_ensure_height_data()
	var spacing_x: float = size_m.x / float(grid_resolution - 1)
	var spacing_z: float = size_m.y / float(grid_resolution - 1)
	var center_x: float = (local_position.x + size_m.x * 0.5) / spacing_x
	var center_z: float = (local_position.z + size_m.y * 0.5) / spacing_z
	var radius_x: int = ceili(radius_m / spacing_x)
	var radius_z: int = ceili(radius_m / spacing_z)
	var source_data: PackedFloat32Array = height_data.duplicate()
	for z: int in range(maxi(0, floori(center_z) - radius_z), mini(grid_resolution, ceili(center_z) + radius_z + 1)):
		for x: int in range(maxi(0, floori(center_x) - radius_x), mini(grid_resolution, ceili(center_x) + radius_x + 1)):
			var sample_position: Vector2 = Vector2((x - center_x) * spacing_x, (z - center_z) * spacing_z)
			var distance: float = sample_position.length()
			if distance > radius_m:
				continue
			var falloff: float = 1.0 - smoothstep(0.0, 1.0, distance / maxf(radius_m, 0.001))
			var data_index: int = z * grid_resolution + x
			if mode == "raise":
				height_data[data_index] = minf(maximum_height_m, source_data[data_index] + strength_m * falloff)
			elif mode == "lower":
				height_data[data_index] = maxf(minimum_height_m, source_data[data_index] - strength_m * falloff)
			elif mode == "smooth":
				var neighbor_average: float = _neighbor_average(source_data, x, z)
				height_data[data_index] = lerpf(source_data[data_index], neighbor_average, clampf(strength_m * falloff, 0.0, 1.0))
	rebuild()


func replace_height_data(new_height_data: PackedFloat32Array) -> void:
	height_data = new_height_data.duplicate()
	rebuild()


func sample_height_local(local_x: float, local_z: float) -> float:
	_ensure_height_data()
	var normalized_x: float = clampf((local_x / size_m.x) + 0.5, 0.0, 1.0)
	var normalized_z: float = clampf((local_z / size_m.y) + 0.5, 0.0, 1.0)
	var x: int = clampi(roundi(normalized_x * float(grid_resolution - 1)), 0, grid_resolution - 1)
	var z: int = clampi(roundi(normalized_z * float(grid_resolution - 1)), 0, grid_resolution - 1)
	return height_data[z * grid_resolution + x]


func _validate_configuration() -> String:
	if grid_resolution < 3 or grid_resolution % 2 == 0:
		return "Grid resolution must be an odd number of at least 3"
	if size_m.x <= 0.0 or size_m.y <= 0.0:
		return "Terrain size must be positive"
	if minimum_height_m >= maximum_height_m:
		return "Minimum height must be less than maximum height"
	if altitude_blend_start_m > altitude_blend_end_m:
		return "Altitude blend start cannot exceed its end"
	if slope_blend_start > slope_blend_end:
		return "Slope blend start cannot exceed its end"
	return ""


func _ensure_height_data() -> void:
	var required_size: int = grid_resolution * grid_resolution
	if height_data.size() == required_size:
		return
	height_data = PackedFloat32Array()
	height_data.resize(required_size)
	height_data.fill(minimum_height_m)


func _build_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	vertices.resize(grid_resolution * grid_resolution)
	normals.resize(grid_resolution * grid_resolution)
	uvs.resize(grid_resolution * grid_resolution)
	for z: int in grid_resolution:
		for x: int in grid_resolution:
			var data_index: int = z * grid_resolution + x
			var normalized_x: float = float(x) / float(grid_resolution - 1)
			var normalized_z: float = float(z) / float(grid_resolution - 1)
			vertices[data_index] = Vector3(
				(normalized_x - 0.5) * size_m.x,
				height_data[data_index],
				(normalized_z - 0.5) * size_m.y
			)
			uvs[data_index] = Vector2(normalized_x, normalized_z)
	for z: int in range(grid_resolution - 1):
		for x: int in range(grid_resolution - 1):
			var top_left: int = z * grid_resolution + x
			var top_right: int = top_left + 1
			var bottom_left: int = top_left + grid_resolution
			var bottom_right: int = bottom_left + 1
			indices.append_array(PackedInt32Array([
				top_left, bottom_left, top_right,
				top_right, bottom_left, bottom_right,
			]))
	_calculate_normals(vertices, indices, normals)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var generated_mesh: ArrayMesh = ArrayMesh.new()
	generated_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return generated_mesh


func _calculate_normals(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	normals: PackedVector3Array
) -> void:
	normals.fill(Vector3.ZERO)
	for triangle_index: int in range(0, indices.size(), 3):
		var a_index: int = indices[triangle_index]
		var b_index: int = indices[triangle_index + 1]
		var c_index: int = indices[triangle_index + 2]
		var face_normal: Vector3 = (vertices[b_index] - vertices[a_index]).cross(
			vertices[c_index] - vertices[a_index]
		).normalized()
		normals[a_index] += face_normal
		normals[b_index] += face_normal
		normals[c_index] += face_normal
	for normal_index: int in normals.size():
		normals[normal_index] = normals[normal_index].normalized()


func _build_material() -> ShaderMaterial:
	var terrain_material: ShaderMaterial = ShaderMaterial.new()
	terrain_material.resource_name = "mat_lanka_terrain_grip_solid"
	terrain_material.shader = TERRAIN_SHADER
	terrain_material.set_shader_parameter("albedo_low", low_albedo)
	terrain_material.set_shader_parameter("albedo_high", high_albedo)
	terrain_material.set_shader_parameter("albedo_steep", steep_albedo)
	terrain_material.set_shader_parameter("texture_scale", texture_scale)
	terrain_material.set_shader_parameter("altitude_blend_start", altitude_blend_start_m)
	terrain_material.set_shader_parameter("altitude_blend_end", altitude_blend_end_m)
	terrain_material.set_shader_parameter("slope_blend_start", slope_blend_start)
	terrain_material.set_shader_parameter("slope_blend_end", slope_blend_end)
	terrain_material.set_shader_parameter("terrain_roughness", roughness)
	return terrain_material


func _update_collision() -> void:
	var body: StaticBody3D = get_node_or_null(NodePath(str(COLLISION_BODY_NAME))) as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = COLLISION_BODY_NAME
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
		if owner != null:
			body.owner = owner
	var collision_shape: CollisionShape3D = body.get_node_or_null(NodePath(str(COLLISION_SHAPE_NAME))) as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = COLLISION_SHAPE_NAME
		body.add_child(collision_shape)
		if owner != null:
			collision_shape.owner = owner
	var height_shape: HeightMapShape3D = HeightMapShape3D.new()
	height_shape.map_width = grid_resolution
	height_shape.map_depth = grid_resolution
	height_shape.map_data = height_data
	collision_shape.shape = height_shape
	collision_shape.scale = Vector3(
		size_m.x / float(grid_resolution - 1),
		1.0,
		size_m.y / float(grid_resolution - 1)
	)


func _neighbor_average(source_data: PackedFloat32Array, x: int, z: int) -> float:
	var total: float = 0.0
	var count: int = 0
	for neighbor_z: int in range(maxi(0, z - 1), mini(grid_resolution, z + 2)):
		for neighbor_x: int in range(maxi(0, x - 1), mini(grid_resolution, x + 2)):
			total += source_data[neighbor_z * grid_resolution + neighbor_x]
			count += 1
	return total / float(maxi(count, 1))
