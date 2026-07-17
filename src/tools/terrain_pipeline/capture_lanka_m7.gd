extends SceneTree

const TerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")
const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")
const LOOK_PATH: String = "res://scenes/levels/lanka/look/lanka_look.tscn"
const CAPTURE_ROOT: String = "res://.godot/review/m7"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var capture_root: String = CAPTURE_ROOT
	if OS.get_cmdline_user_args().has("scale_85"):
		root.scaling_3d_scale = 0.85
		capture_root = "res://.godot/review/m8/captures_scale_85"
	var review_root: Node3D = Node3D.new()
	review_root.name = "M7Review"
	root.add_child(review_root)
	for coordinate: Vector2i in TerrainContract.all_chunk_coordinates():
		var packed: PackedScene = load(TerrainContract.chunk_path(coordinate)) as PackedScene
		var chunk: Node3D = packed.instantiate() as Node3D
		review_root.add_child(chunk)
		var terrain: GeometryInstance3D = chunk.get_node("Terrain3D") as GeometryInstance3D
		terrain.visibility_range_end = 0.0
	for district_value: Variant in DistrictContract.OPEN_WORLD_DISTRICTS:
		var district_id: StringName = district_value as StringName
		var packed: PackedScene = load(DistrictContract.district_path(district_id)) as PackedScene
		review_root.add_child(packed.instantiate())
	for path: String in [DistrictContract.SPINE_PATH, DistrictContract.DARK_PATH]:
		var packed: PackedScene = load(path) as PackedScene
		review_root.add_child(packed.instantiate())
	var look_packed: PackedScene = load(LOOK_PATH) as PackedScene
	var look: Node3D = look_packed.instantiate() as Node3D
	review_root.add_child(look)
	var ocean: MeshInstance3D = look.get_node("PatientOceanScenery") as MeshInstance3D

	var camera: Camera3D = Camera3D.new()
	camera.name = "ReviewCamera"
	camera.fov = 54.0
	camera.far = 3500.0
	camera.current = true
	review_root.add_child(camera)
	var inspection_light: OmniLight3D = OmniLight3D.new()
	inspection_light.name = "InteriorInspectionLight"
	inspection_light.light_color = Color(0.72, 0.86, 0.80)
	inspection_light.light_energy = 5.0
	inspection_light.omni_range = 95.0
	inspection_light.shadow_enabled = true
	inspection_light.visible = false
	camera.add_child(inspection_light)
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_root))
	var views: Array[Dictionary] = [
		{"id": "island_ocean", "camera": Vector3(650.0, 420.0, -780.0), "target": Vector3(0.0, 42.0, 0.0), "interior": false},
		{"id": "ocean_horizon", "camera": Vector3(0.0, 18.0, -760.0), "target": Vector3(0.0, -1.0, -465.0), "interior": false},
		{"id": "shallows", "camera": Vector3(145.0, 62.0, -670.0), "target": Vector3(0.0, 8.0, -430.0), "interior": false},
		{"id": "terraces", "camera": Vector3(-565.0, 130.0, -175.0), "target": Vector3(-330.0, 53.0, 0.0), "interior": false},
		{"id": "ember_quarter", "camera": Vector3(445.0, 120.0, -105.0), "target": Vector3(250.0, 63.0, 80.0), "interior": false},
		{"id": "ember_fire", "camera": Vector3(165.0, 62.0, 30.0), "target": Vector3(132.0, 56.0, 68.0), "interior": false},
		{"id": "cistern", "camera": Vector3(205.0, -2.0, 24.0), "target": Vector3(324.0, 12.0, 134.0), "interior": true},
		{"id": "spine", "camera": Vector3(260.0, 205.0, 175.0), "target": Vector3(0.0, 190.0, 430.0), "interior": false},
		{"id": "dark", "camera": Vector3(12.0, -31.0, 370.0), "target": Vector3(0.0, -32.0, 410.0), "interior": true},
	]
	for view: Dictionary in views:
		camera.global_position = view["camera"] as Vector3
		camera.look_at(view["target"] as Vector3, Vector3.UP)
		var interior: bool = bool(view["interior"])
		inspection_light.visible = interior
		ocean.visible = not interior
		for frame: int in 8:
			await process_frame
			await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var output_path: String = capture_root + "/%s.png" % str(view["id"])
		var save_error: Error = image.save_png(output_path)
		if save_error != OK:
			printerr("Unable to save %s: %s" % [output_path, error_string(save_error)])
			quit(1)
			return
	print("Saved nine Lanka M7 production-look captures to %s" % capture_root)
	quit(0)
