extends SceneTree
## Native-1080p streaming-transition profile for the real shipped Lanka scene.
## Unlike the M8 steady-state profile, this keeps the production streaming root
## and its real Nau target live so scene-instantiation hitches are measured.

const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")
const LANKA_PATH: String = "res://scenes/levels/lanka/lanka.tscn"
const PLAYER_PATH: NodePath = ^"DistrictAnchors/Shallows/Player"
const REPORT_PATH: String = "res://.godot/review/m9/lanka_streaming_native.json"
const MAX_TRANSITION_FRAMES: int = 1200


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.scaling_3d_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var packed: PackedScene = load(LANKA_PATH) as PackedScene
	if packed == null:
		_fail("Unable to load the shipped Lanka scene")
		return
	var lanka: Node3D = packed.instantiate() as Node3D
	if lanka == null:
		_fail("The shipped Lanka scene root is not Node3D")
		return
	root.add_child(lanka)
	var player: Node3D = lanka.get_node_or_null(PLAYER_PATH) as Node3D
	if player == null or lanka.get("streaming_target") != player:
		_fail("The shipped Nau instance is not Lanka's streaming target")
		return
	if not await _wait_until_settled(lanka):
		_fail("Initial shipped-scene streaming did not settle")
		return
	player.set_physics_process(false)

	var transitions: Array[Dictionary] = []
	transitions.append(await _profile_transition(lanka, player, &"ember_quarter"))
	transitions.append(await _profile_transition(lanka, player, &"cistern"))
	var all_settled: bool = true
	var max_frame_ms: float = 0.0
	var max_instances_per_frame: int = 0
	for transition: Dictionary in transitions:
		all_settled = all_settled and bool(transition["settled"])
		max_frame_ms = maxf(max_frame_ms, float(transition["max_frame_ms"]))
		max_instances_per_frame = maxi(
			max_instances_per_frame, int(transition["max_scene_instances_added_in_frame"])
		)

	var report: Dictionary = {
		"schema": 1,
		"scene": LANKA_PATH,
		"resolution": Vector2i(1920, 1080),
		"scaling_3d_scale": root.scaling_3d_scale,
		"renderer": RenderingServer.get_current_rendering_method(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"development_max_frame_ms": 33.0,
		"max_transition_frame_ms": snappedf(max_frame_ms, 0.001),
		"max_scene_instances_added_in_frame": max_instances_per_frame,
		"transitions": transitions,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		_fail("Unable to write %s" % REPORT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t", true, true))
	file.close()
	print(
		"STREAMING PROFILE: max=%.3fms additions/frame=%d transitions=%s"
		% [max_frame_ms, max_instances_per_frame, str(transitions)]
	)
	if not all_settled or max_instances_per_frame > 1:
		quit(1)
		return
	quit(0)


func _profile_transition(
	lanka: Node3D, player: Node3D, district_id: StringName
) -> Dictionary:
	var scene_path: String = DistrictContract.district_path(district_id)
	var previously_seen: Dictionary = _streamed_instance_ids(lanka)
	player.global_position = DistrictContract.district_center(district_id)
	# The profile teleports only to select a transition. Present that camera move
	# before sampling so its transform/visibility discontinuity is not mislabeled
	# as a streaming hitch; every subsequent retirement/addition frame is sampled.
	await process_frame
	await RenderingServer.frame_post_draw
	var frame_times: Array[float] = []
	var max_instances_added: int = 0
	var settled_frames: int = 0
	var settled: bool = false
	var max_frame_context: Dictionary = {}
	for frame: int in MAX_TRANSITION_FRAMES:
		var start_usec: int = Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		var frame_time_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
		frame_times.append(frame_time_ms)
		if max_frame_context.is_empty() or frame_time_ms > float(max_frame_context["frame_ms"]):
			max_frame_context = _streaming_context(lanka, frame, frame_time_ms)
		var currently_seen: Dictionary = _streamed_instance_ids(lanka)
		var additions: int = 0
		for id_value: Variant in currently_seen:
			if not previously_seen.has(id_value):
				additions += 1
		max_instances_added = maxi(max_instances_added, additions)
		previously_seen = currently_seen
		if _is_settled_on_district(lanka, scene_path):
			settled_frames += 1
			if settled_frames >= 12:
				settled = true
				break
		else:
			settled_frames = 0
	frame_times.sort()
	var frame_count: int = frame_times.size()
	var p95_index: int = clampi(ceili(float(frame_count) * 0.95) - 1, 0, frame_count - 1)
	var average_ms: float = 0.0
	for frame_time: float in frame_times:
		average_ms += frame_time
	average_ms /= float(maxi(frame_count, 1))
	return {
		"district_id": str(district_id),
		"settled": settled,
		"frames": frame_count,
		"average_frame_ms": snappedf(average_ms, 0.001),
		"p95_frame_ms": snappedf(frame_times[p95_index], 0.001),
		"max_frame_ms": snappedf(frame_times.back(), 0.001),
		"max_scene_instances_added_in_frame": max_instances_added,
		"max_frame_context": max_frame_context,
		"loaded_chunks": int(lanka.call("loaded_chunk_count")),
		"loaded_districts": int(lanka.call("loaded_district_count")),
	}


func _wait_until_settled(lanka: Node3D) -> bool:
	for frame: int in MAX_TRANSITION_FRAMES:
		await process_frame
		await RenderingServer.frame_post_draw
		if (
			int(lanka.call("pending_chunk_count")) == 0
			and int(lanka.call("pending_district_count")) == 0
			and int(lanka.call("loaded_chunk_count")) > 0
			and int(lanka.call("loaded_district_count")) > 0
		):
			return true
	return false


func _is_settled_on_district(lanka: Node3D, scene_path: String) -> bool:
	if int(lanka.call("pending_chunk_count")) > 0 or int(lanka.call("pending_district_count")) > 0:
		return false
	for child: Node in lanka.get_node("StreamedDistricts").get_children():
		if (
			child.scene_file_path == scene_path
			and bool(child.get_meta(&"district_streaming_ready", true))
		):
			return true
	return false


func _streamed_instance_ids(lanka: Node3D) -> Dictionary:
	var ids: Dictionary = {}
	for container_path: NodePath in [^"StreamedChunks", ^"StreamedDistricts"]:
		for child: Node in lanka.get_node(container_path).get_children():
			ids[child.get_instance_id()] = true
	return ids


func _streaming_context(lanka: Node3D, frame: int, frame_time_ms: float) -> Dictionary:
	var context: Dictionary = {
		"frame": frame,
		"frame_ms": snappedf(frame_time_ms, 0.001),
		"retiring_districts": int(lanka.call("retiring_district_count")),
		"last_retired_branch": str(lanka.call("last_retired_branch")),
		"loaded_districts": int(lanka.call("loaded_district_count")),
	}
	for district: Node in lanka.get_node("StreamedDistricts").get_children():
		if district.is_queued_for_deletion():
			continue
		context["district_scene"] = district.scene_file_path
		var loader: Node = district.get_node_or_null("DistrictSegmentLoader")
		if loader != null:
			context["loaded_segments"] = int(loader.call("loaded_segment_count"))
			context["last_segment_path"] = str(loader.call("last_loaded_segment_path"))
		break
	return context


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
