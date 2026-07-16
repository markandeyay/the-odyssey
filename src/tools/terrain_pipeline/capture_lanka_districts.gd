extends SceneTree

const TerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")
const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")
const CAPTURE_ROOT: String = "res://.godot/review/m5"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var review_root: Node3D = Node3D.new()
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

	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.40, 0.54, 0.58)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.67, 0.64)
	environment.ambient_light_energy = 0.68
	environment_node.environment = environment
	review_root.add_child(environment_node)
	var sunlight: DirectionalLight3D = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sunlight.light_color = Color(1.0, 0.86, 0.68)
	sunlight.light_energy = 1.35
	sunlight.shadow_enabled = true
	review_root.add_child(sunlight)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 54.0
	camera.far = 3000.0
	review_root.add_child(camera)
	camera.current = true
	var inspection_light: OmniLight3D = OmniLight3D.new()
	inspection_light.light_color = Color(1.0, 0.54, 0.25)
	inspection_light.light_energy = 5.0
	inspection_light.omni_range = 90.0
	inspection_light.shadow_enabled = true
	inspection_light.visible = false
	camera.add_child(inspection_light)
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_ROOT))
	var views: Array[Dictionary] = [
		{"id": "shallows", "camera": Vector3(320.0, 190.0, -790.0), "target": Vector3(0.0, 8.0, -420.0), "interior": false},
		{"id": "terraces", "camera": Vector3(-690.0, 230.0, -260.0), "target": Vector3(-330.0, 53.0, 0.0), "interior": false},
		{"id": "ember_quarter", "camera": Vector3(560.0, 270.0, -230.0), "target": Vector3(250.0, 65.0, 80.0), "interior": false},
		{"id": "cistern", "camera": Vector3(250.0, 3.0, 20.0), "target": Vector3(250.0, -8.0, 80.0), "interior": true},
		{"id": "spine", "camera": Vector3(360.0, 280.0, 80.0), "target": Vector3(0.0, 190.0, 430.0), "interior": false},
		{"id": "dark", "camera": Vector3(0.0, -20.0, 345.0), "target": Vector3(0.0, -24.0, 430.0), "interior": true},
	]
	for view: Dictionary in views:
		camera.global_position = view["camera"] as Vector3
		camera.look_at(view["target"] as Vector3, Vector3.UP)
		inspection_light.visible = bool(view["interior"])
		for frame: int in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var output_path: String = CAPTURE_ROOT + "/%s.png" % str(view["id"])
		var save_error: Error = image.save_png(output_path)
		if save_error != OK:
			printerr("Unable to save %s: %s" % [output_path, error_string(save_error)])
			quit(1)
			return
	print("Saved six Lanka M5 district review captures to %s" % CAPTURE_ROOT)
	quit(0)
