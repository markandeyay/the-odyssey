extends SceneTree
## Shallows dressing review harness. Boots the real shipped lanka.tscn with its
## instanced Nau as the streaming target, waits for the Shallows to stream in,
## then captures framed viewport shots of the arrival beach so dressing work is
## reviewed as images, not test counts. Pass a comma list of view ids, or
## nothing for all. Views marked `interact` press the interact action with the
## player placed in front of the subject, to prove prompts fire in-game.

const LANKA_PATH: String = "res://scenes/levels/lanka/lanka.tscn"
const PLAYER_PATH: NodePath = ^"DistrictAnchors/Shallows/Player"
const CAPTURE_ROOT: String = "res://.godot/review/shallows"
const SETTLE_FRAMES: int = 1200

# Shallows district root sits at (0, 3, -410); these are world-space frames.
const VIEWS: Array[Dictionary] = [
	{"id": "01_spawn_view", "cam": Vector3(0.0, 14.0, -418.0), "target": Vector3(0.0, 2.0, -520.0)},
	{"id": "02_beach_overview", "cam": Vector3(150.0, 42.0, -350.0), "target": Vector3(-20.0, 2.0, -480.0)},
	{"id": "03_keffer_hull", "cam": Vector3(-112.0, 13.0, -368.0), "target": Vector3(-135.0, 8.0, -342.0)},
	{"id": "04_keffer_dialogue", "cam": Vector3(-128.0, 9.0, -352.0), "target": Vector3(-135.0, 7.0, -342.0),
		"player_at": Vector3(-132.0, 6.0, -347.0), "player_face": Vector3(-135.0, 6.0, -342.0), "interact": true},
	{"id": "05_hold_site", "cam": Vector3(52.0, 20.0, -300.0), "target": Vector3(105.0, 6.0, -335.0)},
	{"id": "06_campfire_arrival", "cam": Vector3(-38.0, 10.0, -364.0), "target": Vector3(-38.0, 5.0, -348.0)},
	{"id": "07_cairn_entrance", "cam": Vector3(148.0, 13.0, -446.0), "target": Vector3(148.0, 8.0, -422.0)},
	{"id": "08_tidepools", "cam": Vector3(-34.0, 9.0, -518.0), "target": Vector3(-10.0, 1.0, -552.0)},
	{"id": "09_fragment_baran", "cam": Vector3(88.0, 8.0, -508.0), "target": Vector3(88.0, 5.0, -496.0)},
	{"id": "10_ground_detail", "cam": Vector3(0.0, 4.5, -455.0), "target": Vector3(6.0, 1.0, -478.0)},
]

var _camera: Camera3D


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load(LANKA_PATH) as PackedScene
	if packed == null:
		_fail("Unable to load the shipped Lanka scene")
		return
	var lanka: Node3D = packed.instantiate() as Node3D
	root.add_child(lanka)
	var player: Node3D = lanka.get_node_or_null(PLAYER_PATH) as Node3D
	if player == null:
		_fail("Shipped Nau instance missing")
		return
	if not await _wait_until_settled(lanka):
		_fail("Initial streaming did not settle")
		return
	player.set_physics_process(false)

	_camera = Camera3D.new()
	_camera.name = "ShallowsReviewCamera"
	_camera.fov = 54.0
	_camera.far = 3500.0
	root.add_child(_camera)
	_camera.current = true

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_ROOT))
	var requested: PackedStringArray = OS.get_cmdline_user_args()
	for view: Dictionary in VIEWS:
		if not requested.is_empty() and not requested.has(str(view["id"])):
			continue
		if view.has("player_at"):
			player.global_position = view["player_at"] as Vector3
			if view.has("player_face"):
				var face: Vector3 = view["player_face"] as Vector3
				player.rotation.y = atan2(-(face.x - player.global_position.x), -(face.z - player.global_position.z))
			for frame: int in 12:
				await physics_frame
		_camera.global_position = view["cam"] as Vector3
		_camera.look_at(view["target"] as Vector3, Vector3.UP)
		for frame: int in 8:
			await process_frame
			await RenderingServer.frame_post_draw
		if bool(view.get("interact", false)):
			Input.action_press(&"interact")
			await physics_frame
			await physics_frame
			Input.action_release(&"interact")
			for frame: int in 30:
				await process_frame
				await RenderingServer.frame_post_draw
		await _save(str(view["id"]))
	var game_state: Node = root.get_node_or_null("GameState")
	if game_state != null and bool(game_state.call("get_flag", &"met_keffer")):
		print("KEFFER: met_keffer flag set — dialogue fired in-game")
	else:
		print("KEFFER: met_keffer flag NOT set")
	print("Saved Shallows review captures to %s" % CAPTURE_ROOT)
	quit(0)


func _save(view_id: String) -> void:
	var image: Image = root.get_texture().get_image()
	var save_error: Error = image.save_png(CAPTURE_ROOT + "/%s.png" % view_id)
	if save_error != OK:
		_fail("Unable to save %s: %s" % [view_id, error_string(save_error)])


func _wait_until_settled(lanka: Node3D) -> bool:
	for frame: int in SETTLE_FRAMES:
		await process_frame
		if (
			int(lanka.call("pending_chunk_count")) == 0
			and int(lanka.call("pending_district_count")) == 0
			and int(lanka.call("loaded_chunk_count")) > 0
			and int(lanka.call("loaded_district_count")) > 0
		):
			return true
	return false


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
