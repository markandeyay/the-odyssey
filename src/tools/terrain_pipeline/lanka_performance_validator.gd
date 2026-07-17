extends RefCounted

const TerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")
const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")

const LOOK_PATH: String = "res://scenes/levels/lanka/look/lanka_look.tscn"
const DISTRICT_PATHS: Dictionary = {
	&"shallows": "res://scenes/levels/lanka/districts/shallows/shallows_district.tscn",
	&"terraces": "res://scenes/levels/lanka/districts/terraces/terraces_district.tscn",
	&"ember_quarter": "res://scenes/levels/lanka/districts/ember_quarter/ember_quarter_district.tscn",
	&"cistern": "res://scenes/levels/lanka/districts/cistern/cistern_district.tscn",
	&"spine": "res://scenes/levels/lanka/districts/spine/spine_district.tscn",
	&"dark": "res://scenes/levels/lanka/districts/dark/dark_district.tscn",
}
const MAX_FIRE_VISUALS: Dictionary = {
	&"shallows": 2,
	&"terraces": 2,
	&"ember_quarter": 9,
	&"cistern": 1,
	&"spine": 1,
	&"dark": 1,
}
const MAX_LOCAL_LIGHTS: Dictionary = {
	&"shallows": 2,
	&"terraces": 2,
	&"ember_quarter": 9,
	&"cistern": 2,
	&"spine": 1,
	&"dark": 1,
}
const PRODUCTION_TEXTURES: PackedStringArray = [
	"res://assets/materials/library/ambient_cg/rock064/rock064_albedo.png",
	"res://assets/materials/library/poly_haven/aerial_rocks_04/aerial_rocks_04_albedo.png",
]
const MAX_TEXTURE_DIMENSION: int = 2048
const MAX_CORESIDENT_FIRE_VISUALS: int = 12
const MIN_BATCHED_SOURCE_RATIO: float = 0.65
const FIRE_VISIBILITY_RANGE_M: float = 90.0
const SMOKE_VISIBILITY_RANGE_M: float = 130.0
const HEAT_VISIBILITY_RANGE_M: float = 65.0


func validate_repository() -> Array[String]:
	var issues: Array[String] = []
	_validate_look(issues)
	var fire_counts: Dictionary = {}
	for id_value: Variant in DISTRICT_PATHS:
		var district_id: StringName = id_value as StringName
		fire_counts[district_id] = _validate_district(district_id, issues)
	_validate_coresident_fire_cap(fire_counts, issues)
	_validate_terrain_lods(issues)
	_validate_texture_budget(issues)
	return issues


func _validate_look(issues: Array[String]) -> void:
	var root: Node = _instantiate_scene(LOOK_PATH, issues)
	if root == null:
		return
	var sun: DirectionalLight3D = root.get_node_or_null("LowSmokeSun") as DirectionalLight3D
	if sun == null:
		issues.append("%s: missing the budgeted directional light" % LOOK_PATH)
	else:
		if not sun.shadow_enabled:
			issues.append("%s: low sun shadows are disabled" % LOOK_PATH)
		if sun.directional_shadow_mode != DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS:
			issues.append("%s: low sun must use two fog-limited shadow splits" % LOOK_PATH)
		if sun.directional_shadow_max_distance > 500.0:
			issues.append("%s: low sun shadow range exceeds the 500 m M8 cap" % LOOK_PATH)
	root.free()


func _validate_district(district_id: StringName, issues: Array[String]) -> int:
	var path: String = str(DISTRICT_PATHS[district_id])
	var root: Node = _instantiate_scene(path, issues)
	if root == null:
		return 0
	var batches: Node = root.get_node_or_null("M8RenderBatches")
	if batches == null or not bool(batches.get_meta(&"m8_material_batching", false)):
		issues.append("%s: missing M8 material batches" % path)
	var primitive_sources: int = 0
	var batched_sources: int = 0
	var batch_count: int = 0
	var fire_count: int = 0
	var local_light_count: int = 0
	var particle_count: int = 0
	var occluder_count: int = 0
	var notifier_count: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance: MeshInstance3D = node as MeshInstance3D
			if mesh_instance.mesh is BoxMesh or mesh_instance.mesh is CylinderMesh:
				primitive_sources += 1
				if not mesh_instance.visible:
					batched_sources += 1
		if node is MultiMeshInstance3D:
			var batch: MultiMeshInstance3D = node as MultiMeshInstance3D
			if batch.multimesh == null or batch.multimesh.instance_count < 2:
				issues.append("%s: %s is not a useful repeated-geometry batch" % [path, node.name])
			else:
				batch_count += 1
		if str(node.get_meta(&"vfx_profile", "")) == "fire_smoke_heat":
			fire_count += 1
			_validate_fire_visual(node, path, issues)
		if node is Light3D:
			local_light_count += 1
			if (node as Light3D).shadow_enabled:
				issues.append("%s: local light %s exceeds the zero-shadow local-light budget" % [path, node.name])
		if node is GPUParticles3D:
			particle_count += 1
		if node is OccluderInstance3D:
			occluder_count += 1
		if node is VisibleOnScreenNotifier3D:
			notifier_count += 1
		for child: Node in node.get_children():
			stack.append(child)
	if batch_count < 1:
		issues.append("%s: no repeated geometry is rendered through MultiMesh" % path)
	if primitive_sources > 0 and float(batched_sources) / float(primitive_sources) < MIN_BATCHED_SOURCE_RATIO:
		issues.append(
			"%s: only %d/%d repeatable meshes are batched"
			% [path, batched_sources, primitive_sources]
		)
	if fire_count > int(MAX_FIRE_VISUALS[district_id]):
		issues.append("%s: %d authored fire visuals exceed cap %d" % [path, fire_count, MAX_FIRE_VISUALS[district_id]])
	if local_light_count > int(MAX_LOCAL_LIGHTS[district_id]):
		issues.append("%s: %d local lights exceed cap %d" % [path, local_light_count, MAX_LOCAL_LIGHTS[district_id]])
	if particle_count > 0:
		issues.append("%s: WORLD-authored fire must not add particle emitters" % path)
	if occluder_count < 1:
		issues.append("%s: missing district occluder coverage" % path)
	if notifier_count < 1:
		issues.append("%s: missing visibility notifier coverage" % path)
	root.free()
	return fire_count


func _validate_fire_visual(root: Node, path: String, issues: Array[String]) -> void:
	var has_notifier: bool = false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var visual: MeshInstance3D = node as MeshInstance3D
			var range_cap: float = 0.0
			if node.name.begins_with("FlamePlane"):
				range_cap = FIRE_VISIBILITY_RANGE_M
			elif node.name.begins_with("SmokePlane"):
				range_cap = SMOKE_VISIBILITY_RANGE_M
			elif node.name == "HeatHaze":
				range_cap = HEAT_VISIBILITY_RANGE_M
			if range_cap > 0.0 and (visual.visibility_range_end <= 0.0 or visual.visibility_range_end > range_cap):
				issues.append("%s: %s exceeds its %.0f m VFX range" % [path, node.get_path(), range_cap])
		if node is OmniLight3D:
			var light: OmniLight3D = node as OmniLight3D
			if light.shadow_enabled or not light.distance_fade_enabled or light.omni_range > 15.0:
				issues.append("%s: %s breaks the fire light budget" % [path, node.get_path()])
		if node is VisibleOnScreenNotifier3D:
			has_notifier = true
		for child: Node in node.get_children():
			stack.append(child)
	if not has_notifier:
		issues.append("%s: %s lacks a VFX visibility notifier" % [path, root.get_path()])


func _validate_coresident_fire_cap(fire_counts: Dictionary, issues: Array[String]) -> void:
	var peak_count: int = 0
	for z: int in range(-550, 551, 10):
		for x: int in range(-550, 551, 10):
			var position: Vector2 = Vector2(float(x), float(z))
			var resident_count: int = 0
			for id_value: Variant in DistrictContract.OPEN_WORLD_DISTRICTS:
				var district_id: StringName = id_value as StringName
				var data: Dictionary = DistrictContract.OPEN_WORLD_DISTRICTS[district_id] as Dictionary
				var center: Vector3 = data["center"] as Vector3
				if position.distance_to(Vector2(center.x, center.z)) <= float(data["load_radius_m"]):
					resident_count += int(fire_counts.get(district_id, 0))
			peak_count = maxi(peak_count, resident_count)
	if peak_count > MAX_CORESIDENT_FIRE_VISUALS:
		issues.append(
			"Open-world streaming can co-reside %d authored fire visuals; cap is %d"
			% [peak_count, MAX_CORESIDENT_FIRE_VISUALS]
		)


func _validate_terrain_lods(issues: Array[String]) -> void:
	for coordinate: Vector2i in TerrainContract.all_chunk_coordinates():
		var path: String = TerrainContract.chunk_path(coordinate)
		var root: Node = _instantiate_scene(path, issues)
		if root == null:
			continue
		var terrain: OdysseyTerrain3D = root.get_node_or_null("Terrain3D") as OdysseyTerrain3D
		if terrain == null:
			issues.append("%s: missing terrain render node" % path)
		else:
			if not terrain.generate_lods or terrain.lod_level_count < 2:
				issues.append("%s: missing two terrain LOD levels" % path)
			if terrain.visibility_range_end <= 0.0 or terrain.visibility_range_end > 650.0:
				issues.append("%s: terrain visibility range exceeds 650 m" % path)
		root.free()


func _validate_texture_budget(issues: Array[String]) -> void:
	for path: String in PRODUCTION_TEXTURES:
		var texture: Texture2D = ResourceLoader.load(path, "Texture2D") as Texture2D
		if texture == null:
			issues.append("%s: production texture does not load" % path)
			continue
		if maxi(texture.get_width(), texture.get_height()) > MAX_TEXTURE_DIMENSION:
			issues.append("%s: production texture exceeds %d px" % [path, MAX_TEXTURE_DIMENSION])
		var import_config: ConfigFile = ConfigFile.new()
		if import_config.load(path + ".import") != OK:
			issues.append("%s: missing texture import configuration" % path)
			continue
		if int(import_config.get_value("params", "compress/mode", -1)) != 2:
			issues.append("%s: production texture is not VRAM compressed" % path)
		if not bool(import_config.get_value("params", "mipmaps/generate", false)):
			issues.append("%s: production texture has no mipmaps" % path)


func _instantiate_scene(path: String, issues: Array[String]) -> Node:
	var packed: PackedScene = ResourceLoader.load(path, "PackedScene") as PackedScene
	if packed == null:
		issues.append("%s: unable to load scene" % path)
		return null
	return packed.instantiate()
