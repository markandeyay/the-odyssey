extends SceneTree

const TerrainScript: Script = preload("res://addons/odyssey_world_tools/terrain_3d.gd")
const LankaTerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")
const LankaHeightGenerator: Script = preload("res://src/tools/terrain_pipeline/lanka_height_generator.gd")
const StreamingScript: Script = preload("res://scenes/levels/lanka/lanka_streaming_root.gd")
const LankaDistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")

const CHUNK_ROOT: String = "res://scenes/levels/lanka/chunks"
const LANDMARK_ROOT: String = "res://scenes/levels/lanka/landmarks"
const SPINE_BLOCKOUT_PATH: String = "res://scenes/levels/lanka/landmarks/spine_blockout.tscn"
const LANKA_SCENE_PATH: String = "res://scenes/levels/lanka/lanka.tscn"
const LANKA_LOOK_PATH: String = "res://scenes/levels/lanka/look/lanka_look.tscn"
const LOW_TEXTURE_PATH: String = "res://assets/materials/library/ambient_cg/rock064/rock064_albedo.png"
const HIGH_TEXTURE_PATH: String = "res://assets/materials/library/poly_haven/aerial_rocks_04/aerial_rocks_04_albedo.png"

var _height_generator: RefCounted


func _initialize() -> void:
	_height_generator = LankaHeightGenerator.new() as RefCounted
	if "root_only" in OS.get_cmdline_user_args():
		var root_only_error: Error = _build_lanka_root()
		if root_only_error != OK:
			_fail("Unable to rebuild Lanka streaming root: %s" % error_string(root_only_error))
			return
		print("Wrote Lanka streaming root")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHUNK_ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LANDMARK_ROOT))
	for coordinate: Vector2i in LankaTerrainContract.all_chunk_coordinates():
		var chunk_error: Error = _build_chunk(coordinate)
		if chunk_error != OK:
			_fail("Unable to build chunk %s: %s" % [coordinate, error_string(chunk_error)])
			return
	var spine_error: Error = _build_spine_landmark()
	if spine_error != OK:
		_fail("Unable to build Spine blockout: %s" % error_string(spine_error))
		return
	var root_error: Error = _build_lanka_root()
	if root_error != OK:
		_fail("Unable to build Lanka streaming root: %s" % error_string(root_error))
		return
	print("Wrote 25 Lanka terrain chunks, the Spine proxy, and streaming root")
	quit(0)


func _build_chunk(coordinate: Vector2i) -> Error:
	var center: Vector2 = LankaTerrainContract.chunk_center(coordinate)
	var root: Node3D = Node3D.new()
	root.name = "Chunk%d%d" % [coordinate.x, coordinate.y]
	root.position = Vector3(center.x, 0.0, center.y)
	root.set_meta(&"budget_profile", LankaTerrainContract.budget_profile_for_center(center))
	root.set_meta(&"chunk_grid_coordinate", coordinate)
	root.set_meta(&"chunk_center_m", center)
	root.set_meta(&"streamed_terrain_chunk", true)

	var terrain: OdysseyTerrain3D = TerrainScript.new() as OdysseyTerrain3D
	terrain.name = "Terrain3D"
	terrain.grid_resolution = LankaTerrainContract.GRID_RESOLUTION
	terrain.size_m = Vector2.ONE * LankaTerrainContract.CHUNK_SIZE_M
	terrain.minimum_height_m = LankaTerrainContract.MINIMUM_HEIGHT_M
	terrain.maximum_height_m = LankaTerrainContract.MAXIMUM_HEIGHT_M
	terrain.height_data = _height_generator.sample_chunk(coordinate)
	terrain.low_albedo = load(LOW_TEXTURE_PATH) as Texture2D
	terrain.high_albedo = load(HIGH_TEXTURE_PATH) as Texture2D
	terrain.steep_albedo = load(LOW_TEXTURE_PATH) as Texture2D
	terrain.altitude_blend_start_m = 8.0
	terrain.altitude_blend_end_m = 58.0
	terrain.slope_blend_start = 0.22
	terrain.slope_blend_end = 0.62
	terrain.low_tint = Color(0.095, 0.145, 0.132)
	terrain.high_tint = Color(0.43, 0.44, 0.41)
	terrain.steep_tint = Color(0.068, 0.078, 0.075)
	terrain.ash_tint = Color(0.60, 0.61, 0.57)
	terrain.detail_strength = 0.30
	terrain.macro_variation = 0.17
	terrain.ash_amount = 0.38
	terrain.wetness = 0.42
	terrain.wet_height_m = 12.0
	terrain.generate_lods = true
	terrain.lod_level_count = 2
	terrain.lod_distance_multiplier = 0.65
	terrain.visibility_range_end = 650.0
	terrain.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	root.add_child(terrain)
	terrain.owner = root
	var result: Dictionary = terrain.rebuild()
	if not bool(result.get("ok", false)):
		root.free()
		return ERR_CANT_CREATE
	_add_cliff_occluders(root, coordinate)
	_set_owner_recursive(root, root)
	var save_error: Error = _save_scene(root, LankaTerrainContract.chunk_path(coordinate))
	root.free()
	return save_error


func _add_cliff_occluders(root: Node3D, coordinate: Vector2i) -> void:
	if coordinate.x == 0:
		_add_box_occluder(root, "WestCliffOccluder", Vector3(-106.0, 27.0, 0.0), Vector3(10.0, 70.0, 220.0))
	if coordinate.x == LankaTerrainContract.CHUNK_COUNT.x - 1:
		_add_box_occluder(root, "EastCliffOccluder", Vector3(106.0, 27.0, 0.0), Vector3(10.0, 70.0, 220.0))
	if coordinate.y == LankaTerrainContract.CHUNK_COUNT.y - 1:
		_add_box_occluder(root, "NorthCliffOccluder", Vector3(0.0, 27.0, 106.0), Vector3(220.0, 70.0, 10.0))


func _add_box_occluder(root: Node3D, node_name: String, position: Vector3, size: Vector3) -> void:
	var occluder_resource: BoxOccluder3D = BoxOccluder3D.new()
	occluder_resource.size = size
	var occluder: OccluderInstance3D = OccluderInstance3D.new()
	occluder.name = node_name
	occluder.position = position
	occluder.occluder = occluder_resource
	root.add_child(occluder)


func _build_spine_landmark() -> Error:
	var root: Node3D = Node3D.new()
	root.name = "SpineBlockout"
	root.position = LankaTerrainContract.SPINE_BASE
	root.set_meta(&"budget_profile", "spine")
	root.set_meta(&"persistent_landmark", true)
	var stone_material: StandardMaterial3D = StandardMaterial3D.new()
	stone_material.resource_name = "mat_spine_blockout_grip_solid"
	stone_material.albedo_color = Color(0.105, 0.115, 0.115)
	stone_material.roughness = 0.94

	var tower_height: float = LankaTerrainContract.SPINE_TOP.y - LankaTerrainContract.SPINE_BASE.y
	var tower_mesh: CylinderMesh = CylinderMesh.new()
	tower_mesh.top_radius = 12.0
	tower_mesh.bottom_radius = 19.0
	tower_mesh.height = tower_height
	tower_mesh.radial_segments = 16
	tower_mesh.rings = 4
	tower_mesh.material = stone_material
	var tower: MeshInstance3D = MeshInstance3D.new()
	tower.name = "SpineTowerProxy"
	tower.position.y = tower_height * 0.5
	tower.mesh = tower_mesh
	tower.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	root.add_child(tower)

	var crown_mesh: CylinderMesh = CylinderMesh.new()
	crown_mesh.top_radius = 6.0
	crown_mesh.bottom_radius = 13.0
	crown_mesh.height = 24.0
	crown_mesh.radial_segments = 12
	crown_mesh.material = stone_material
	var crown: MeshInstance3D = MeshInstance3D.new()
	crown.name = "SpineCrownProxy"
	crown.position.y = tower_height + 12.0
	crown.mesh = crown_mesh
	root.add_child(crown)

	var collision_body: StaticBody3D = StaticBody3D.new()
	collision_body.name = "SpineCollision"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 0
	root.add_child(collision_body)
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "SpineCollisionShape"
	var cylinder_shape: CylinderShape3D = CylinderShape3D.new()
	cylinder_shape.radius = 19.0
	cylinder_shape.height = tower_height
	collision_shape.position.y = tower_height * 0.5
	collision_shape.shape = cylinder_shape
	collision_body.add_child(collision_shape)

	_add_box_occluder(
		root,
		"SpineOccluder",
		Vector3(0.0, tower_height * 0.5, 0.0),
		Vector3(34.0, tower_height, 34.0)
	)
	var notifier: VisibleOnScreenNotifier3D = VisibleOnScreenNotifier3D.new()
	notifier.name = "SpineVisibilityNotifier"
	notifier.aabb = AABB(Vector3(-24.0, 0.0, -24.0), Vector3(48.0, tower_height + 24.0, 48.0))
	root.add_child(notifier)
	_set_owner_recursive(root, root)
	var save_error: Error = _save_scene(root, SPINE_BLOCKOUT_PATH)
	root.free()
	return save_error


func _build_lanka_root() -> Error:
	var root: Node3D = Node3D.new()
	root.name = "Lanka"
	root.set_script(StreamingScript)
	root.set_meta(&"budget_profile", "default")
	root.set_meta(&"playable_size_m", LankaTerrainContract.ISLAND_SIZE_M)
	root.set_meta(&"streaming_required", true)
	root.set_meta(&"m7_visual_system", true)

	var look_packed: PackedScene = load(LANKA_LOOK_PATH) as PackedScene
	if look_packed == null:
		root.free()
		return ERR_FILE_CANT_READ
	var look: Node3D = look_packed.instantiate() as Node3D
	look.name = "PersistentLook"
	root.add_child(look)
	look.owner = root

	var chunks: Node3D = Node3D.new()
	chunks.name = "StreamedChunks"
	root.add_child(chunks)
	chunks.owner = root
	var districts: Node3D = Node3D.new()
	districts.name = "StreamedDistricts"
	root.add_child(districts)
	districts.owner = root
	var landmarks: Node3D = Node3D.new()
	landmarks.name = "PersistentLandmarks"
	root.add_child(landmarks)
	landmarks.owner = root
	var spine_path: String = (
		LankaDistrictContract.SPINE_PATH
		if FileAccess.file_exists(LankaDistrictContract.SPINE_PATH)
		else SPINE_BLOCKOUT_PATH
	)
	var spine_packed: PackedScene = load(spine_path) as PackedScene
	if spine_packed == null:
		root.free()
		return ERR_FILE_CANT_READ
	var spine: Node = spine_packed.instantiate()
	landmarks.add_child(spine)
	spine.owner = root

	var anchors: Node3D = Node3D.new()
	anchors.name = "DistrictAnchors"
	root.add_child(anchors)
	anchors.owner = root
	for district_value: Variant in LankaTerrainContract.DISTRICT_ANCHORS:
		var district: StringName = district_value as StringName
		var marker: Marker3D = Marker3D.new()
		marker.name = str(district).to_pascal_case()
		marker.position = LankaTerrainContract.DISTRICT_ANCHORS[district] as Vector3
		marker.set_meta(&"district_id", district)
		anchors.add_child(marker)
		marker.owner = root

	var save_error: Error = _save_scene(root, LANKA_SCENE_PATH)
	root.free()
	return save_error


func _save_scene(root: Node, path: String) -> Error:
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(root)
	if pack_error != OK:
		return pack_error
	return ResourceSaver.save(packed, path)


func _set_owner_recursive(node: Node, scene_owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_owner
		_set_owner_recursive(child, scene_owner)


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
