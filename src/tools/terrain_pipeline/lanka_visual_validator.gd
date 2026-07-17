extends RefCounted

const TerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")
const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")
const ContentContract: Script = preload("res://scenes/levels/lanka/lanka_content_contract.gd")
const LOOK_PATH: String = "res://scenes/levels/lanka/look/lanka_look.tscn"
const ROOT_PATH: String = "res://scenes/levels/lanka/lanka.tscn"
const SURFACE_SHADER_PATH: String = "res://addons/odyssey_world_tools/shaders/lanka_stylized_surface.gdshader"
const TERRAIN_SHADER_PATH: String = "res://addons/odyssey_world_tools/shaders/lanka_terrain_triplanar.gdshader"
const OCEAN_SHADER_PATH: String = "res://addons/odyssey_world_tools/shaders/lanka_ocean_scenery.gdshader"
const FIRE_SHADER_PATH: String = "res://addons/odyssey_world_tools/shaders/lanka_fire.gdshader"
const SMOKE_SHADER_PATH: String = "res://addons/odyssey_world_tools/shaders/lanka_smoke.gdshader"
const HEAT_SHADER_PATH: String = "res://addons/odyssey_world_tools/shaders/lanka_heat_haze.gdshader"
const CLIMBABLE_LAYER_BIT: int = 1 << 2


func validate_repository() -> Array[String]:
	var issues: Array[String] = []
	for shader_path: String in [
		SURFACE_SHADER_PATH, TERRAIN_SHADER_PATH, OCEAN_SHADER_PATH,
		FIRE_SHADER_PATH, SMOKE_SHADER_PATH, HEAT_SHADER_PATH,
	]:
		if not FileAccess.file_exists(shader_path):
			issues.append("Missing M7 shader: %s" % shader_path)
	_validate_look(issues)
	_validate_root(issues)
	_validate_terrain_materials(issues)
	_validate_district_visuals(issues)
	_validate_cairn_visuals(issues)
	return issues


func _validate_look(issues: Array[String]) -> void:
	var root_node: Node = _instantiate_scene(LOOK_PATH, issues)
	if root_node == null:
		return
	if not bool(root_node.get_meta(&"m7_visual_system", false)):
		issues.append("Lanka look is missing m7_visual_system metadata")
	var palette: PackedStringArray = root_node.get_meta(&"palette", PackedStringArray()) as PackedStringArray
	var expected_palette: PackedStringArray = PackedStringArray([
		"ash_grey", "wet_black", "bone_white", "ember_orange", "sea_green",
	])
	if palette != expected_palette:
		issues.append("Lanka look palette contract does not match the M7 five-color palette")
	var environment_node: WorldEnvironment = root_node.get_node_or_null("SmokeEnvironment") as WorldEnvironment
	if environment_node == null or environment_node.environment == null:
		issues.append("Lanka look must contain SmokeEnvironment with an Environment resource")
	else:
		var environment: Environment = environment_node.environment
		if not environment.fog_enabled:
			issues.append("Lanka M7 depth fog must be enabled")
		if not environment.volumetric_fog_enabled:
			issues.append("Lanka M7 volumetric fog must be enabled")
		if environment.volumetric_fog_density < 0.003:
			issues.append("Lanka M7 volumetric fog is below the heavy-smoke density floor")
		if environment.tonemap_mode != Environment.TONE_MAPPER_FILMIC:
			issues.append("Lanka M7 environment must use filmic tonemapping")
	var sun: DirectionalLight3D = root_node.get_node_or_null("LowSmokeSun") as DirectionalLight3D
	if sun == null:
		issues.append("Lanka look is missing LowSmokeSun")
	else:
		if sun.rotation_degrees.x > -6.0 or sun.rotation_degrees.x < -20.0:
			issues.append("LowSmokeSun must remain at a low 6-20 degree elevation")
		if sun.light_volumetric_fog_energy < 1.5:
			issues.append("LowSmokeSun must inject enough energy for smoke god rays")
	var ocean: MeshInstance3D = root_node.get_node_or_null("PatientOceanScenery") as MeshInstance3D
	if ocean == null:
		issues.append("Lanka look is missing PatientOceanScenery")
	else:
		if not bool(ocean.get_meta(&"scenery_only", false)) or bool(ocean.get_meta(&"simulation", true)):
			issues.append("Lanka ocean must declare scenery_only=true and simulation=false")
		_validate_mesh_shader(ocean, OCEAN_SHADER_PATH, "Lanka ocean", issues)
		if ocean.get_node_or_null("OceanVisibilityNotifier") == null:
			issues.append("Lanka ocean requires an OceanVisibilityNotifier")
	root_node.free()


func _validate_root(issues: Array[String]) -> void:
	var root_node: Node = _instantiate_scene(ROOT_PATH, issues)
	if root_node == null:
		return
	if not bool(root_node.get_meta(&"m7_visual_system", false)):
		issues.append("Lanka streaming root is missing m7_visual_system metadata")
	if root_node.get_node_or_null("PersistentLook") == null:
		issues.append("Lanka streaming root must instance the persistent M7 look")
	root_node.free()


func _validate_fire_visual(fire: Node, source: String, issues: Array[String]) -> void:
	if not bool(fire.get_meta(&"visual_only", false)):
		issues.append("%s fire visual must remain visual-only" % source)
	if str(fire.get_meta(&"gameplay_behavior", "")) != "SYSTEMS_owned":
		issues.append("%s fire visual must declare SYSTEMS-owned gameplay behavior" % source)
	_validate_named_shader(fire, "FlamePlane00", FIRE_SHADER_PATH, source, issues)
	_validate_named_shader(fire, "FlamePlane01", FIRE_SHADER_PATH, source, issues)
	_validate_named_shader(fire, "SmokePlane00", SMOKE_SHADER_PATH, source, issues)
	_validate_named_shader(fire, "SmokePlane01", SMOKE_SHADER_PATH, source, issues)
	_validate_named_shader(fire, "HeatHaze", HEAT_SHADER_PATH, source, issues)
	if fire.get_node_or_null("FireLight") == null:
		issues.append("%s fire visual is missing its bounded FireLight" % source)
	if fire.get_node_or_null("VisibilityNotifier") == null:
		issues.append("%s fire visual is missing its VisibilityNotifier" % source)


func _validate_terrain_materials(issues: Array[String]) -> void:
	var chunk_count: int = 0
	for coordinate: Vector2i in TerrainContract.all_chunk_coordinates():
		var path: String = TerrainContract.chunk_path(coordinate)
		var root_node: Node = _instantiate_scene(path, issues)
		if root_node == null:
			continue
		chunk_count += 1
		var terrain: MeshInstance3D = root_node.get_node_or_null("Terrain3D") as MeshInstance3D
		if terrain == null:
			issues.append("%s is missing Terrain3D" % path)
		else:
			var material: ShaderMaterial = terrain.material_override as ShaderMaterial
			if material == null or material.shader == null or material.shader.resource_path != TERRAIN_SHADER_PATH:
				issues.append("%s terrain must use the M7 triplanar terrain shader" % path)
			else:
				for parameter: StringName in [&"low_tint", &"high_tint", &"steep_tint", &"ash_amount", &"wetness"]:
					if material.get_shader_parameter(parameter) == null:
						issues.append("%s terrain is missing M7 parameter %s" % [path, parameter])
		root_node.free()
	if chunk_count != 25:
		issues.append("M7 must validate exactly 25 terrain chunks, found %d" % chunk_count)


func _validate_district_visuals(issues: Array[String]) -> void:
	var district_paths: PackedStringArray = PackedStringArray()
	for district_value: Variant in DistrictContract.OPEN_WORLD_DISTRICTS:
		district_paths.append(DistrictContract.district_path(district_value as StringName))
	district_paths.append(DistrictContract.SPINE_PATH)
	district_paths.append(DistrictContract.DARK_PATH)
	var ember_fire_count: int = 0
	var campfire_visual_count: int = 0
	for path: String in district_paths:
		var district: Node = _instantiate_scene(path, issues)
		if district == null:
			continue
		_validate_stylized_climbables(district, path, issues)
		if path == DistrictContract.district_path(&"cistern"):
			_validate_cistern_look(district, path, issues)
		var fire_visuals: Array[Node] = []
		_collect_vfx_nodes(district, "fire_smoke_heat", fire_visuals)
		for fire_visual: Node in fire_visuals:
			_validate_fire_visual(fire_visual, "%s:%s" % [path, fire_visual.name], issues)
		ember_fire_count += _count_named_prefix(district, "EmberFireVisual")
		campfire_visual_count += _count_named_exact(district, "FireVisual")
		district.free()
	if ember_fire_count != 7:
		issues.append("Ember Quarter must contain exactly 7 visual fire cracks, found %d" % ember_fire_count)
	if campfire_visual_count != ContentContract.CAMPFIRES.size():
		issues.append(
			"Every contracted campfire needs one visual fire: expected %d, found %d"
			% [ContentContract.CAMPFIRES.size(), campfire_visual_count]
		)


func _validate_cistern_look(district: Node, source: String, issues: Array[String]) -> void:
	var water: MeshInstance3D = district.get_node_or_null("Dressing/ReservoirWaterScenery") as MeshInstance3D
	if water == null:
		issues.append("%s is missing ReservoirWaterScenery" % source)
	else:
		if not bool(water.get_meta(&"scenery_only", false)) or bool(water.get_meta(&"simulation", true)):
			issues.append("%s reservoir water must remain non-simulated scenery" % source)
		_validate_mesh_shader(water, OCEAN_SHADER_PATH, "Cistern reservoir water", issues)
	var shaft_light: SpotLight3D = district.get_node_or_null("Dressing/EntranceShaftGodRay") as SpotLight3D
	if shaft_light == null:
		issues.append("%s is missing the bounded EntranceShaftGodRay" % source)
	elif shaft_light.light_volumetric_fog_energy < 1.5:
		issues.append("%s EntranceShaftGodRay is below its volumetric energy floor" % source)


func _validate_cairn_visuals(issues: Array[String]) -> void:
	for cairn: Dictionary in ContentContract.CAIRNS:
		var path: String = str(cairn["path"])
		var room: Node = _instantiate_scene(path, issues)
		if room == null:
			continue
		_validate_stylized_climbables(room, path, issues)
		var expected_fire_count: int = 0
		var mechanic: StringName = cairn["mechanic"] as StringName
		if mechanic == &"fire_fuel":
			expected_fire_count = 2
		elif mechanic == &"carry_flame":
			expected_fire_count = 1
		var actual_fire_count: int = _count_vfx_profile(room, "fire_smoke_heat")
		var fire_visuals: Array[Node] = []
		_collect_vfx_nodes(room, "fire_smoke_heat", fire_visuals)
		for fire_visual: Node in fire_visuals:
			_validate_fire_visual(fire_visual, "%s:%s" % [path, fire_visual.name], issues)
		if actual_fire_count != expected_fire_count:
			issues.append(
				"%s expected %d visual-only fires, found %d"
				% [path, expected_fire_count, actual_fire_count]
			)
		room.free()


func _validate_stylized_climbables(node: Node, source: String, issues: Array[String]) -> void:
	if node is CollisionObject3D and (node as CollisionObject3D).collision_layer & CLIMBABLE_LAYER_BIT != 0:
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(node, meshes)
		for mesh: MeshInstance3D in meshes:
			for surface_index: int in mesh.mesh.get_surface_count():
				var material: ShaderMaterial = mesh.get_active_material(surface_index) as ShaderMaterial
				if material == null or material.shader == null or material.shader.resource_path != SURFACE_SHADER_PATH:
					issues.append("%s:%s climbable surface does not use the M7 stylized PBR shader" % [source, mesh.name])
	for child: Node in node.get_children():
		_validate_stylized_climbables(child, source, issues)


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			output.append(child as MeshInstance3D)
		if not child is CollisionObject3D:
			_collect_meshes(child, output)


func _validate_named_shader(
	root_node: Node,
	node_name: String,
	shader_path: String,
	source: String,
	issues: Array[String]
) -> void:
	var node: MeshInstance3D = root_node.get_node_or_null(node_name) as MeshInstance3D
	if node == null:
		issues.append("%s fire visual is missing %s" % [source, node_name])
		return
	_validate_mesh_shader(node, shader_path, "%s fire %s" % [source, node_name], issues)


func _validate_mesh_shader(mesh: MeshInstance3D, shader_path: String, label: String, issues: Array[String]) -> void:
	if mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
		issues.append("%s has no renderable mesh surface" % label)
		return
	var material: ShaderMaterial = mesh.get_active_material(0) as ShaderMaterial
	if material == null or material.shader == null or material.shader.resource_path != shader_path:
		issues.append("%s must use %s" % [label, shader_path])


func _count_named_prefix(node: Node, prefix: String) -> int:
	var count: int = 1 if str(node.name).begins_with(prefix) else 0
	for child: Node in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count


func _count_named_exact(node: Node, exact_name: String) -> int:
	var count: int = 1 if str(node.name) == exact_name else 0
	for child: Node in node.get_children():
		count += _count_named_exact(child, exact_name)
	return count


func _count_vfx_profile(node: Node, profile: String) -> int:
	var count: int = 1 if str(node.get_meta(&"vfx_profile", "")) == profile else 0
	for child: Node in node.get_children():
		count += _count_vfx_profile(child, profile)
	return count


func _collect_vfx_nodes(node: Node, profile: String, output: Array[Node]) -> void:
	if str(node.get_meta(&"vfx_profile", "")) == profile:
		output.append(node)
	for child: Node in node.get_children():
		_collect_vfx_nodes(child, profile, output)


func _instantiate_scene(path: String, issues: Array[String]) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		issues.append("Unable to load M7 scene: %s" % path)
		return null
	return packed.instantiate()
