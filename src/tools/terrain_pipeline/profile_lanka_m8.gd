extends SceneTree

const TerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")
const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")
const LOOK_PATH: String = "res://scenes/levels/lanka/look/lanka_look.tscn"
const REPORT_ROOT: String = "res://.godot/review/m8"
const TARGET_FRAME_MS: float = 1000.0 / 60.0
const TEXTURE_MEMORY_BUDGET_BYTES: int = 192 * 1024 * 1024
const VIDEO_MEMORY_BUDGET_BYTES: int = 384 * 1024 * 1024

var _warmup_frames: int = 45
var _sample_frames: int = 120

var _profiles: Array[Dictionary] = [
	{
		"id": "shallows",
		"center": Vector3(0.0, 3.0, -410.0),
		"camera": Vector3(145.0, 62.0, -670.0),
		"target": Vector3(0.0, 8.0, -430.0),
		"districts": PackedStringArray(["shallows"]),
		"terrain": true,
	},
	{
		"id": "terraces",
		"center": Vector3(-330.0, 50.0, 0.0),
		"camera": Vector3(-565.0, 130.0, -175.0),
		"target": Vector3(-330.0, 53.0, 0.0),
		"districts": PackedStringArray(["terraces"]),
		"terrain": true,
	},
	{
		"id": "ember_quarter",
		"center": Vector3(250.0, 54.0, 80.0),
		"camera": Vector3(445.0, 120.0, -105.0),
		"target": Vector3(250.0, 63.0, 80.0),
		"districts": PackedStringArray(["ember_quarter", "cistern"]),
		"terrain": true,
	},
	{
		"id": "cistern",
		"center": Vector3(250.0, 8.0, 80.0),
		"camera": Vector3(205.0, -2.0, 24.0),
		"target": Vector3(324.0, 12.0, 134.0),
		"districts": PackedStringArray(["ember_quarter", "cistern"]),
		"terrain": true,
	},
	{
		"id": "spine",
		"center": Vector3(0.0, 68.0, 430.0),
		"camera": Vector3(260.0, 205.0, 175.0),
		"target": Vector3(0.0, 190.0, 430.0),
		"districts": PackedStringArray(),
		"terrain": true,
	},
	{
		"id": "dark",
		"center": Vector3(0.0, -34.0, 430.0),
		"camera": Vector3(12.0, -31.0, 370.0),
		"target": Vector3(0.0, -32.0, 410.0),
		"districts": PackedStringArray(["dark"]),
		"terrain": false,
	},
]


func _initialize() -> void:
	_profile.call_deferred()


func _profile() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.has("sustained"):
		_warmup_frames = 1200
		_sample_frames = 240
	root.size = Vector2i(1920, 1080)
	if user_args.has("occlusion"):
		root.use_occlusion_culling = true
	elif user_args.has("no_occlusion"):
		root.use_occlusion_culling = false
	if user_args.has("fsr"):
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	if user_args.has("scale_85"):
		root.scaling_3d_scale = 0.85
	elif user_args.has("scale_75"):
		root.scaling_3d_scale = 0.75
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var stage: Node3D = Node3D.new()
	stage.name = "M8ProfileStage"
	root.add_child(stage)
	var look_packed: PackedScene = load(LOOK_PATH) as PackedScene
	if look_packed == null:
		printerr("Unable to load M8 production look")
		quit(1)
		return
	var look: Node3D = look_packed.instantiate() as Node3D
	stage.add_child(look)
	if user_args.has("no_volumetric"):
		var environment_node: WorldEnvironment = look.get_node("SmokeEnvironment") as WorldEnvironment
		environment_node.environment.volumetric_fog_enabled = false
	if user_args.has("no_shadows"):
		_set_shadows_enabled(look, false)
	var camera: Camera3D = Camera3D.new()
	camera.name = "ProfileCamera"
	camera.fov = 54.0
	camera.far = 3500.0
	camera.current = true
	stage.add_child(camera)
	var content: Node3D = Node3D.new()
	content.name = "ProfileContent"
	stage.add_child(content)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_ROOT))
	var report: Dictionary = {
		"schema": 1,
		"resolution": Vector2i(1920, 1080),
		"warmup_frames": _warmup_frames,
		"sample_frames": _sample_frames,
		"renderer": RenderingServer.get_current_rendering_method(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"video_vendor": RenderingServer.get_video_adapter_vendor(),
		"scaling_3d_scale": root.scaling_3d_scale,
		"scaling_3d_mode": int(root.scaling_3d_mode),
		"occlusion_culling": root.use_occlusion_culling,
		"target_frame_ms": TARGET_FRAME_MS,
		"texture_memory_budget_bytes": TEXTURE_MEMORY_BUDGET_BYTES,
		"video_memory_budget_bytes": VIDEO_MEMORY_BUDGET_BYTES,
		"profiles": [],
	}
	var selected_profiles: Array[Dictionary] = _selected_profiles()
	for profile: Dictionary in selected_profiles:
		await _clear_content(content)
		var load_error: String = _load_profile_content(content, profile)
		if not load_error.is_empty():
			printerr(load_error)
			quit(1)
			return
		if user_args.has("no_vfx"):
			_set_profile_vfx_visible(content, false)
		if user_args.has("no_shadows"):
			_set_shadows_enabled(content, false)
		camera.global_position = profile["camera"] as Vector3
		camera.look_at(profile["target"] as Vector3, Vector3.UP)
		for frame: int in _warmup_frames:
			await process_frame
			await RenderingServer.frame_post_draw
		var result: Dictionary = await _sample_profile(str(profile["id"]))
		(report["profiles"] as Array).append(result)
		print(
			"PROFILE %s: avg %.2f ms, p95 %.2f ms, %.1f FPS, max %d draws"
			% [
				result["id"], result["average_frame_ms"], result["p95_frame_ms"],
				result["derived_fps"], result["max_draw_calls"],
			]
		)
	var phase: String = "optimized" if "optimized" in OS.get_cmdline_user_args() else "baseline"
	if selected_profiles.size() == 1:
		phase += "_" + str(selected_profiles[0]["id"]) + "_isolated"
	for diagnostic: String in ["sustained", "no_volumetric", "no_vfx", "no_shadows", "occlusion", "no_occlusion", "scale_85", "scale_75", "fsr"]:
		if user_args.has(diagnostic):
			phase += "_" + diagnostic
	var output_path: String = REPORT_ROOT + "/lanka_m8_%s.json" % phase
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("Unable to write M8 profile report: %s" % output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t", true, true))
	file.close()
	print("Saved Lanka M8 1080p Forward+ profile to %s" % output_path)
	_finish.call_deferred(0)


func _selected_profiles() -> Array[Dictionary]:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var selected: Array[Dictionary] = []
	for profile: Dictionary in _profiles:
		if user_args.has(str(profile["id"])):
			selected.append(profile)
	if selected.is_empty():
		selected.assign(_profiles)
	if user_args.has("reverse"):
		selected.reverse()
	return selected


func _load_profile_content(content: Node3D, profile: Dictionary) -> String:
	var center: Vector3 = profile["center"] as Vector3
	if bool(profile["terrain"]):
		for coordinate: Vector2i in TerrainContract.all_chunk_coordinates():
			if center.distance_to(Vector3(TerrainContract.chunk_center(coordinate).x, center.y, TerrainContract.chunk_center(coordinate).y)) > TerrainContract.LOAD_RADIUS_M:
				continue
			var chunk_error: String = _instantiate_path(content, TerrainContract.chunk_path(coordinate))
			if not chunk_error.is_empty():
				return chunk_error
	if str(profile["id"]) != "dark":
		var spine_error: String = _instantiate_path(content, DistrictContract.SPINE_PATH)
		if not spine_error.is_empty():
			return spine_error
	for district_id: String in profile["districts"] as PackedStringArray:
		var path: String = DistrictContract.DARK_PATH if district_id == "dark" else DistrictContract.district_path(StringName(district_id))
		var district_error: String = _instantiate_path(content, path)
		if not district_error.is_empty():
			return district_error
	return ""


func _instantiate_path(parent: Node3D, path: String) -> String:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return "Unable to load M8 profile scene: %s" % path
	var instance: Node3D = packed.instantiate() as Node3D
	if instance == null:
		return "M8 profile scene root is not Node3D: %s" % path
	parent.add_child(instance)
	return ""


func _sample_profile(profile_id: String) -> Dictionary:
	var frame_times: Array[float] = []
	var max_draw_calls: int = 0
	var max_primitives: int = 0
	var max_objects: int = 0
	var max_video_memory: int = 0
	var max_texture_memory: int = 0
	var max_buffer_memory: int = 0
	for frame: int in _sample_frames:
		var start_usec: int = Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		frame_times.append(float(Time.get_ticks_usec() - start_usec) / 1000.0)
		max_draw_calls = maxi(max_draw_calls, roundi(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		max_primitives = maxi(max_primitives, roundi(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		max_objects = maxi(max_objects, roundi(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
		max_video_memory = maxi(max_video_memory, roundi(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
		max_texture_memory = maxi(max_texture_memory, roundi(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)))
		max_buffer_memory = maxi(max_buffer_memory, roundi(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)))
	var total_ms: float = 0.0
	for frame_time: float in frame_times:
		total_ms += frame_time
	var average_ms: float = total_ms / float(maxi(frame_times.size(), 1))
	var sorted_times: Array[float] = frame_times.duplicate()
	sorted_times.sort()
	var p95_index: int = clampi(ceili(float(sorted_times.size()) * 0.95) - 1, 0, sorted_times.size() - 1)
	return {
		"id": profile_id,
		"average_frame_ms": snappedf(average_ms, 0.001),
		"p95_frame_ms": snappedf(sorted_times[p95_index], 0.001),
		"max_frame_ms": snappedf(sorted_times.back(), 0.001),
		"derived_fps": snappedf(1000.0 / maxf(average_ms, 0.001), 0.1),
		"max_draw_calls": max_draw_calls,
		"max_primitives": max_primitives,
		"max_objects": max_objects,
		"video_memory_bytes": max_video_memory,
		"texture_memory_bytes": max_texture_memory,
		"buffer_memory_bytes": max_buffer_memory,
		"meets_60_fps_target": average_ms <= TARGET_FRAME_MS,
		"meets_texture_memory_budget": max_texture_memory <= TEXTURE_MEMORY_BUDGET_BYTES,
		"meets_video_memory_budget": max_video_memory <= VIDEO_MEMORY_BUDGET_BYTES,
	}


func _clear_content(content: Node3D) -> void:
	for child: Node in content.get_children():
		child.queue_free()
	for frame: int in 6:
		await process_frame


func _set_profile_vfx_visible(node: Node, is_visible: bool) -> void:
	if str(node.get_meta(&"vfx_profile", "")) == "fire_smoke_heat":
		_set_visual_tree_visible(node, is_visible)
		return
	for child: Node in node.get_children():
		_set_profile_vfx_visible(child, is_visible)


func _set_visual_tree_visible(node: Node, is_visible: bool) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = is_visible
	for child: Node in node.get_children():
		_set_visual_tree_visible(child, is_visible)


func _set_shadows_enabled(node: Node, is_enabled: bool) -> void:
	if node is Light3D:
		(node as Light3D).shadow_enabled = is_enabled
	for child: Node in node.get_children():
		_set_shadows_enabled(child, is_enabled)


func _finish(exit_code: int) -> void:
	quit(exit_code)
