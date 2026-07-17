extends SceneTree

const LankaTerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")
const SPINE_SCENE_PATH: String = "res://scenes/levels/lanka/landmarks/spine_blockout.tscn"
const CAPTURE_PATH: String = "res://.godot/review/lanka_m4_blockout.png"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var review_root: Node3D = Node3D.new()
	review_root.name = "LankaM4BlockoutReview"
	root.add_child(review_root)
	for coordinate: Vector2i in LankaTerrainContract.all_chunk_coordinates():
		var packed: PackedScene = load(LankaTerrainContract.chunk_path(coordinate)) as PackedScene
		if packed == null:
			printerr("Unable to load review chunk %s" % coordinate)
			quit(1)
			return
		var chunk: Node3D = packed.instantiate() as Node3D
		review_root.add_child(chunk)
		var terrain: GeometryInstance3D = chunk.get_node("Terrain3D") as GeometryInstance3D
		terrain.visibility_range_end = 0.0
	var spine_packed: PackedScene = load(SPINE_SCENE_PATH) as PackedScene
	var spine: Node3D = spine_packed.instantiate() as Node3D
	review_root.add_child(spine)

	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.47, 0.62, 0.68)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.76)
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment
	review_root.add_child(environment_node)
	var sunlight: DirectionalLight3D = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sunlight.light_color = Color(1.0, 0.91, 0.76)
	sunlight.light_energy = 1.25
	sunlight.shadow_enabled = true
	review_root.add_child(sunlight)

	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(760.0, 700.0, -980.0)
	camera.fov = 48.0
	camera.far = 3000.0
	review_root.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0.0, 35.0, 20.0), Vector3.UP)
	camera.current = true
	root.size = Vector2i(1440, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_PATH.get_base_dir()))
	for frame: int in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var save_error: Error = image.save_png(CAPTURE_PATH)
	if save_error != OK:
		printerr("Unable to save Lanka M4 capture: %s" % error_string(save_error))
		quit(1)
		return
	print("Saved Lanka M4 blockout review to %s" % CAPTURE_PATH)
	quit(0)
