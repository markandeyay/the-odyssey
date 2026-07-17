extends SceneTree

const ContentContract: Script = preload("res://scenes/levels/lanka/lanka_content_contract.gd")
const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")
const CAPTURE_ROOT: String = "res://.godot/review/m6"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var review_root: Node3D = Node3D.new()
	root.add_child(review_root)
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.22, 0.29, 0.30)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.60, 0.64, 0.61)
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment
	review_root.add_child(environment_node)
	var sunlight: DirectionalLight3D = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	sunlight.light_color = Color(1.0, 0.82, 0.64)
	sunlight.light_energy = 1.4
	sunlight.shadow_enabled = true
	review_root.add_child(sunlight)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 58.0
	camera.far = 1000.0
	camera.current = true
	review_root.add_child(camera)
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_ROOT))
	for cairn: Dictionary in ContentContract.CAIRNS:
		var packed: PackedScene = load(str(cairn["path"])) as PackedScene
		var room: Node3D = packed.instantiate() as Node3D
		review_root.add_child(room)
		camera.global_position = Vector3(45.0, 34.0, 48.0)
		camera.look_at(Vector3(0.0, 5.0, 0.0), Vector3.UP)
		await _save_frame("cairn_%s" % str(cairn["id"]))
		room.queue_free()
		await process_frame
	var shallows_packed: PackedScene = load(DistrictContract.district_path(&"shallows")) as PackedScene
	var shallows: Node3D = shallows_packed.instantiate() as Node3D
	review_root.add_child(shallows)
	_set_visuals_visible(shallows.get_node("Dressing/KefferOverturnedHull"), false)
	camera.fov = 45.0
	camera.global_position = Vector3(-130.0, 9.5, -338.0)
	camera.look_at(Vector3(-135.0, 9.0, -342.0), Vector3.UP)
	await _save_frame("keffer")
	print("Saved eight Cairn reviews and Keffer review to %s" % CAPTURE_ROOT)
	quit(0)


func _save_frame(filename: String) -> void:
	for frame: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var output_path: String = CAPTURE_ROOT + "/%s.png" % filename
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		printerr("Unable to save %s: %s" % [output_path, error_string(save_error)])
		quit(1)


func _set_visuals_visible(node: Node, is_visible: bool) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = is_visible
	for child: Node in node.get_children():
		_set_visuals_visible(child, is_visible)
