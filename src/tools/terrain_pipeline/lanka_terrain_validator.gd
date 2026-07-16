extends RefCounted

const TerrainScript: Script = preload("res://addons/odyssey_world_tools/terrain_3d.gd")
const LankaTerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")
const LANKA_SCENE_PATH: String = "res://scenes/levels/lanka/lanka.tscn"
const SPINE_SCENE_PATH: String = "res://scenes/levels/lanka/landmarks/spine_blockout.tscn"


func validate_repository() -> Array[String]:
	var issues: Array[String] = []
	_validate_chunks(issues)
	_validate_spine(issues)
	_validate_streaming_root(issues)
	return issues


func _validate_chunks(issues: Array[String]) -> void:
	for coordinate: Vector2i in LankaTerrainContract.all_chunk_coordinates():
		var path: String = LankaTerrainContract.chunk_path(coordinate)
		var root: Node3D = _instantiate_node_3d(path, issues)
		if root == null:
			continue
		var expected_center: Vector2 = LankaTerrainContract.chunk_center(coordinate)
		if not root.position.is_equal_approx(Vector3(expected_center.x, 0.0, expected_center.y)):
			issues.append("%s: chunk root is not at its contract center" % path)
		if root.get_meta(&"chunk_grid_coordinate", Vector2i(-1, -1)) != coordinate:
			issues.append("%s: chunk coordinate metadata is incorrect" % path)
		if not bool(root.get_meta(&"streamed_terrain_chunk", false)):
			issues.append("%s: chunk is not marked for streaming" % path)
		var terrain: OdysseyTerrain3D = root.get_node_or_null("Terrain3D") as OdysseyTerrain3D
		if terrain == null or terrain.get_script() != TerrainScript:
			issues.append("%s: missing OdysseyTerrain3D" % path)
			root.free()
			continue
		if terrain.grid_resolution != LankaTerrainContract.GRID_RESOLUTION:
			issues.append("%s: terrain grid resolution differs from the contract" % path)
		if terrain.size_m != Vector2.ONE * LankaTerrainContract.CHUNK_SIZE_M:
			issues.append("%s: terrain size differs from the contract" % path)
		if terrain.height_data.size() != LankaTerrainContract.GRID_RESOLUTION ** 2:
			issues.append("%s: terrain height sample count is incorrect" % path)
		if not terrain.generate_lods or terrain.lod_level_count < 2:
			issues.append("%s: terrain LOD generation is disabled" % path)
		if not terrain.mesh is ArrayMesh:
			issues.append("%s: terrain mesh is not an ArrayMesh" % path)
		else:
			var array_mesh: ArrayMesh = terrain.mesh as ArrayMesh
			if array_mesh.get_surface_count() != 1:
				issues.append("%s: terrain must use one batched mesh surface" % path)
			else:
				var surface: Dictionary = RenderingServer.mesh_get_surface(array_mesh.get_rid(), 0)
				var lods: Array = surface.get("lods", []) as Array
				if lods.size() < 2:
					issues.append("%s: terrain mesh does not contain two distance LODs" % path)
			if array_mesh.surface_get_name(0) != "mat_lanka_terrain_grip_solid":
				issues.append("%s: terrain surface breaks the grip-class naming contract" % path)
		var collision_body: StaticBody3D = terrain.get_node_or_null("TerrainCollisionBody") as StaticBody3D
		if collision_body == null or collision_body.collision_layer != 1:
			issues.append("%s: terrain collision is not on the world layer" % path)
		var expected_occluders: int = int(coordinate.x == 0)
		expected_occluders += int(coordinate.x == LankaTerrainContract.CHUNK_COUNT.x - 1)
		expected_occluders += int(coordinate.y == LankaTerrainContract.CHUNK_COUNT.y - 1)
		if _count_nodes_of_type(root, "OccluderInstance3D") < expected_occluders:
			issues.append("%s: cliff-edge occluder coverage is incomplete" % path)
		root.free()


func _validate_spine(issues: Array[String]) -> void:
	var spine: Node3D = _instantiate_node_3d(SPINE_SCENE_PATH, issues)
	if spine == null:
		return
	if not spine.position.is_equal_approx(LankaTerrainContract.SPINE_BASE):
		issues.append("%s: Spine base differs from the terrain contract" % SPINE_SCENE_PATH)
	if not bool(spine.get_meta(&"persistent_landmark", false)):
		issues.append("%s: Spine is not marked persistent" % SPINE_SCENE_PATH)
	if _count_nodes_of_type(spine, "VisibleOnScreenNotifier3D") < 1:
		issues.append("%s: expensive landmark lacks a visibility notifier" % SPINE_SCENE_PATH)
	if _count_nodes_of_type(spine, "OccluderInstance3D") < 1:
		issues.append("%s: Spine lacks an occluder" % SPINE_SCENE_PATH)
	var body: StaticBody3D = spine.get_node_or_null("SpineCollision") as StaticBody3D
	if body == null or body.collision_layer != 1:
		issues.append("%s: Spine collision is not on the world layer" % SPINE_SCENE_PATH)
	spine.free()


func _validate_streaming_root(issues: Array[String]) -> void:
	var root: Node3D = _instantiate_node_3d(LANKA_SCENE_PATH, issues)
	if root == null:
		return
	if root.get_meta(&"playable_size_m", Vector2.ZERO) != LankaTerrainContract.ISLAND_SIZE_M:
		issues.append("%s: playable footprint metadata is incorrect" % LANKA_SCENE_PATH)
	if not bool(root.get_meta(&"streaming_required", false)):
		issues.append("%s: streaming is not mandatory" % LANKA_SCENE_PATH)
	var chunks: Node = root.get_node_or_null("StreamedChunks")
	if chunks == null or chunks.get_child_count() != 0:
		issues.append("%s: runtime root must not preload terrain chunks" % LANKA_SCENE_PATH)
	var spine: Node = root.get_node_or_null("PersistentLandmarks/SpineBlockout")
	if spine == null or spine.scene_file_path != SPINE_SCENE_PATH:
		issues.append("%s: persistent Spine must remain an external scene instance" % LANKA_SCENE_PATH)
	if LankaTerrainContract.UNLOAD_RADIUS_M <= LankaTerrainContract.LOAD_RADIUS_M:
		issues.append("Lanka stream radii do not provide unload hysteresis")
	var center_paths: PackedStringArray = root.call("desired_chunk_paths", Vector3.ZERO) as PackedStringArray
	if center_paths.size() != 9:
		issues.append("%s: island center should request exactly nine chunks" % LANKA_SCENE_PATH)
	var arrival_paths: PackedStringArray = root.call(
		"desired_chunk_paths", LankaTerrainContract.DISTRICT_ANCHORS[&"shallows"]
	) as PackedStringArray
	if arrival_paths.is_empty() or arrival_paths.size() > 6:
		issues.append("%s: south arrival stream set is outside its resident budget" % LANKA_SCENE_PATH)
	var largest_set: int = 0
	for z: int in range(-550, 551, 55):
		for x: int in range(-550, 551, 55):
			var paths: PackedStringArray = root.call(
				"desired_chunk_paths", Vector3(float(x), 0.0, float(z))
			) as PackedStringArray
			largest_set = maxi(largest_set, paths.size())
			for path: String in paths:
				if not FileAccess.file_exists(path):
					issues.append("%s: stream selection references a missing chunk" % path)
	if largest_set > 12:
		issues.append("%s: stream selection can request %d chunks at once" % [LANKA_SCENE_PATH, largest_set])
	root.free()


func _instantiate_node_3d(path: String, issues: Array[String]) -> Node3D:
	var resource: Resource = ResourceLoader.load(path, "PackedScene")
	if not resource is PackedScene:
		issues.append("%s: unable to load PackedScene" % path)
		return null
	var root: Node3D = (resource as PackedScene).instantiate() as Node3D
	if root == null:
		issues.append("%s: scene root must be Node3D" % path)
	return root


func _count_nodes_of_type(root: Node, type_name: String) -> int:
	var count: int = int(root.is_class(type_name))
	for child: Node in root.get_children():
		count += _count_nodes_of_type(child, type_name)
	return count
