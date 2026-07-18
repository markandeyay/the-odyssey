extends Node
## Optional main-scene playtest driver. It uses the real Nau controller and
## project input actions; no teleport or synthetic streaming target is used.

const SCREENSHOT_PATH: String = "res://.godot/review/m9/lanka_f5_spine_route.png"
const TIME_SCALE: float = 6.0
const WAYPOINT_RADIUS_M: float = 9.0
const ROUTE_TIMEOUT_MS: int = 150000

var _lanka: Node3D
var _player: CharacterBody3D
var _player_died: bool = false
var _failed: bool = false
var _finishing: bool = false


func configure(lanka: Node3D, player: Node3D) -> void:
	_lanka = lanka
	_player = player as CharacterBody3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if _lanka == null or _player == null:
		_finish(false, "missing shipped Lanka or Nau instance")
		return
	EventBus.player_died.connect(_on_player_died)
	if not await _wait_for_spawn():
		_finish(false, "initial player-driven streaming did not settle")
		return
	Engine.time_scale = TIME_SCALE
	var started_ms: int = Time.get_ticks_msec()
	var inland_route: Array[Vector2] = [
		Vector2(0.0, -350.0),
		Vector2(0.0, -130.0),
		Vector2(85.0, -50.0),
		Vector2(85.0, 245.0),
		Vector2(0.0, 330.0),
		Vector2(0.0, 385.0),
	]
	if not await _walk_waypoints(inland_route, started_ms):
		_finish(false, "route to the Spine was blocked at %s" % _player.global_position)
		return
	print("PLAYTEST: reached the Spine on foot at %s" % _player.global_position)
	await _capture_spine()

	var ocean_route: Array[Vector2] = [
		Vector2(0.0, 330.0),
		Vector2(85.0, 245.0),
		Vector2(85.0, -50.0),
		Vector2(0.0, -130.0),
		Vector2(0.0, -350.0),
		Vector2(0.0, -485.0),
		Vector2(0.0, -548.0),
	]
	# The return walk gets its own timeout budget. Streaming-heavy uphill traversal
	# must not consume the shoreline verification window.
	if not await _walk_waypoints(ocean_route, Time.get_ticks_msec(), true):
		_finish(false, "return route to the ocean was blocked at %s" % _player.global_position)
		return
	if not _player_died:
		_finish(false, "Nau reached the ocean without a death event")
		return
	print("PLAYTEST: ocean death confirmed with no invisible wall")
	_finish(true, "Shallows -> Spine -> ocean")


func _wait_for_spawn() -> bool:
	for frame: int in 1200:
		await get_tree().physics_frame
		if (
			_player.is_physics_processing()
			and int(_lanka.call("pending_chunk_count")) == 0
			and int(_lanka.call("pending_district_count")) == 0
			and int(_lanka.call("loaded_chunk_count")) > 0
			and int(_lanka.call("loaded_district_count")) > 0
		):
			return true
	return false


func _walk_waypoints(
	waypoints: Array[Vector2], started_ms: int, death_is_success: bool = false
) -> bool:
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	var last_progress_position: Vector2 = _horizontal_position()
	var stalled_frames: int = 0
	for waypoint: Vector2 in waypoints:
		while _horizontal_position().distance_to(waypoint) > WAYPOINT_RADIUS_M:
			if Time.get_ticks_msec() - started_ms > ROUTE_TIMEOUT_MS:
				_release_input()
				return false
			if _player_died:
				_release_input()
				return death_is_success
			_face_waypoint(waypoint)
			await get_tree().physics_frame
			var current: Vector2 = _horizontal_position()
			if current.distance_to(last_progress_position) < 0.25:
				stalled_frames += 1
			else:
				stalled_frames = 0
				last_progress_position = current
			if stalled_frames >= 45:
				Input.action_press(&"jump")
				await get_tree().physics_frame
				Input.action_release(&"jump")
				stalled_frames = 0
	_release_input()
	return true


func _face_waypoint(waypoint: Vector2) -> void:
	var camera_rig: Node3D = _player.get_node_or_null("CameraRig") as Node3D
	if camera_rig == null:
		_failed = true
		return
	var direction: Vector2 = waypoint - _horizontal_position()
	camera_rig.rotation.y = atan2(-direction.x, -direction.y)


func _horizontal_position() -> Vector2:
	return Vector2(_player.global_position.x, _player.global_position.z)


func _capture_spine() -> void:
	for frame: int in 6:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(SCREENSHOT_PATH.get_base_dir())
	)
	var image: Image = get_viewport().get_texture().get_image()
	var save_error: Error = image.save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH))
	if save_error != OK:
		_failed = true
		push_error("Unable to save route screenshot: %s" % error_string(save_error))


func _on_player_died() -> void:
	_player_died = true


func _release_input() -> void:
	for action: StringName in [&"move_forward", &"sprint", &"jump"]:
		Input.action_release(action)


func _finish(success: bool, detail: String) -> void:
	if _finishing:
		return
	_finishing = true
	_release_input()
	Engine.time_scale = 1.0
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)
	_complete_finish.call_deferred(success, detail)


func _complete_finish(success: bool, detail: String) -> void:
	# The shoreline can change the desired chunk set on the same frame that the
	# death signal fires. Consume those threaded requests before quitting so an
	# F5 pass cannot hide loader errors behind abrupt process teardown.
	for frame: int in 1200:
		await get_tree().process_frame
		if _streaming_is_idle():
			break
	if is_instance_valid(_lanka):
		_lanka.queue_free()
	for frame: int in 120:
		await get_tree().process_frame
	if success and not _failed:
		print("PASS: F5 Lanka route playtest (%s)" % detail)
		get_tree().quit(0)
	else:
		printerr("FAIL: F5 Lanka route playtest: %s" % detail)
		get_tree().quit(1)


func _streaming_is_idle() -> bool:
	if not is_instance_valid(_lanka):
		return true
	if (
		int(_lanka.call("pending_chunk_count")) > 0
		or int(_lanka.call("pending_district_count")) > 0
		or int(_lanka.call("retiring_district_count")) > 0
	):
		return false
	for district: Node in _lanka.get_node("StreamedDistricts").get_children():
		if not bool(district.get_meta(&"district_streaming_ready", true)):
			return false
	return true
