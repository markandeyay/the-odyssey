extends Node3D

const LankaTerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")
const LankaDistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")
const MAX_STREAM_INSTANTIATIONS_PER_FRAME: int = 1

@export var streaming_target: Node3D
@export_range(220.0, 600.0, 10.0, "suffix:m") var load_radius_m: float = LankaTerrainContract.LOAD_RADIUS_M
@export_range(300.0, 800.0, 10.0, "suffix:m") var unload_radius_m: float = LankaTerrainContract.UNLOAD_RADIUS_M
@export_range(0.05, 2.0, 0.05, "suffix:s") var refresh_interval_s: float = 0.25

var _refresh_elapsed_s: float = 0.0
var _desired_paths: Dictionary = {}
var _loaded_chunks: Dictionary = {}
var _pending_chunks: Dictionary = {}
var _retiring_chunks: Array[Node3D] = []
var _desired_district_paths: Dictionary = {}
var _loaded_districts: Dictionary = {}
var _pending_districts: Dictionary = {}
var _retiring_districts: Array[Node3D] = []
var _last_retired_branch: String = ""
var _last_stream_position: Vector3 = Vector3.INF
var _initial_stream_guard_active: bool = false
var _initial_target_physics_enabled: bool = false
var _initial_target_transform: Transform3D = Transform3D.IDENTITY
var _district_first_next_frame: bool = false

@onready var _chunk_container: Node3D = $StreamedChunks
@onready var _district_container: Node3D = $StreamedDistricts


func _ready() -> void:
	if unload_radius_m <= load_radius_m:
		push_error("Lanka unload radius must be greater than its load radius")
	if streaming_target != null:
		_face_initial_target_toward_spine()
		_begin_initial_stream_guard()
		_refresh_streaming(streaming_target.global_position)
	if OS.get_cmdline_user_args().has("m9_route_walk"):
		_start_route_playtest.call_deferred()


func _face_initial_target_toward_spine() -> void:
	var camera_rig: Node3D = streaming_target.get_node_or_null("CameraRig") as Node3D
	var spine_anchor: Node3D = get_node_or_null("DistrictAnchors/Spine") as Node3D
	if camera_rig == null or spine_anchor == null:
		return
	var direction: Vector3 = spine_anchor.global_position - streaming_target.global_position
	camera_rig.rotation.y = atan2(-direction.x, -direction.z)


func _start_route_playtest() -> void:
	var probe_script: Script = load(
		"res://src/tools/terrain_pipeline/lanka_route_playtest.gd"
	) as Script
	if probe_script == null or streaming_target == null:
		push_error("Unable to start the Lanka route playtest")
		return
	var probe: Node = Node.new()
	probe.set_script(probe_script)
	probe.call("configure", self, streaming_target)
	# Keep the verifier outside Lanka so it can free the production scene and
	# observe clean teardown before exiting the process.
	get_tree().root.add_child(probe)


func _process(delta: float) -> void:
	var instantiate_budget: int = MAX_STREAM_INSTANTIATIONS_PER_FRAME
	if _drain_one_retiring_chunk():
		instantiate_budget -= 1
	elif _drain_one_retiring_district_branch():
		instantiate_budget -= 1
	if _district_first_next_frame:
		instantiate_budget = _poll_pending_districts(instantiate_budget)
		instantiate_budget = _poll_pending_chunks(instantiate_budget)
	else:
		instantiate_budget = _poll_pending_chunks(instantiate_budget)
		instantiate_budget = _poll_pending_districts(instantiate_budget)
	_district_first_next_frame = not _district_first_next_frame
	_release_initial_stream_guard_if_ready()
	if streaming_target == null:
		return
	_refresh_elapsed_s += delta
	if _refresh_elapsed_s < refresh_interval_s:
		return
	_refresh_elapsed_s = 0.0
	_refresh_streaming(streaming_target.global_position)


func set_streaming_target(target: Node3D) -> void:
	if _initial_stream_guard_active and streaming_target != null and streaming_target != target:
		streaming_target.global_transform = _initial_target_transform
		streaming_target.set_physics_process(_initial_target_physics_enabled)
		_initial_stream_guard_active = false
	streaming_target = target
	if is_inside_tree() and streaming_target != null:
		_refresh_streaming(streaming_target.global_position)


func _begin_initial_stream_guard() -> void:
	_initial_target_physics_enabled = streaming_target.is_physics_processing()
	_initial_target_transform = streaming_target.global_transform
	streaming_target.set_physics_process(false)
	_initial_stream_guard_active = true


func _release_initial_stream_guard_if_ready() -> void:
	if not _initial_stream_guard_active:
		return
	if streaming_target == null:
		_initial_stream_guard_active = false
		return
	if (
		_pending_chunks.size() > 0
		or _pending_districts.size() > 0
		or _loaded_chunks.is_empty()
		or _loaded_districts.is_empty()
	):
		return
	# The streamed collision is now in the tree. Restore the authored spawn in
	# case a child controller enabled itself during _ready(), then release Nau for
	# the next physics tick.
	streaming_target.global_transform = _initial_target_transform
	streaming_target.set_physics_process(_initial_target_physics_enabled)
	_initial_stream_guard_active = false


func desired_chunk_paths(world_position: Vector3) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	var horizontal_position: Vector2 = Vector2(world_position.x, world_position.z)
	for coordinate: Vector2i in LankaTerrainContract.all_chunk_coordinates():
		if horizontal_position.distance_to(LankaTerrainContract.chunk_center(coordinate)) <= load_radius_m:
			paths.append(LankaTerrainContract.chunk_path(coordinate))
	paths.sort()
	return paths


func desired_district_paths(world_position: Vector3) -> PackedStringArray:
	return LankaDistrictContract.desired_open_world_paths(world_position)


func loaded_chunk_count() -> int:
	return _loaded_chunks.size()


func pending_chunk_count() -> int:
	return _pending_chunks.size()


func loaded_district_count() -> int:
	return _loaded_districts.size()


func pending_district_count() -> int:
	return _pending_districts.size()


func retiring_district_count() -> int:
	return _retiring_districts.size()


func last_retired_branch() -> String:
	return _last_retired_branch


func _refresh_streaming(world_position: Vector3) -> void:
	_last_stream_position = world_position
	_desired_paths.clear()
	for path: String in desired_chunk_paths(world_position):
		_desired_paths[path] = true
		if not _loaded_chunks.has(path) and not _pending_chunks.has(path):
			_request_chunk(path)

	var horizontal_position: Vector2 = Vector2(world_position.x, world_position.z)
	for path_value: Variant in _loaded_chunks.keys():
		var path: String = str(path_value)
		var chunk: Node3D = _loaded_chunks[path] as Node3D
		var chunk_position: Vector2 = Vector2(chunk.position.x, chunk.position.z)
		if horizontal_position.distance_to(chunk_position) <= unload_radius_m:
			continue
		_loaded_chunks.erase(path)
		chunk.process_mode = Node.PROCESS_MODE_DISABLED
		_retiring_chunks.append(chunk)
	_refresh_district_streaming(world_position)


func _refresh_district_streaming(world_position: Vector3) -> void:
	_desired_district_paths.clear()
	for path: String in desired_district_paths(world_position):
		_desired_district_paths[path] = true
	for path_value: Variant in _loaded_districts.keys():
		var path: String = str(path_value)
		if LankaDistrictContract.should_keep_path_loaded(path, world_position):
			continue
		var district: Node3D = _loaded_districts[path] as Node3D
		_loaded_districts.erase(path)
		_begin_district_retirement(district)
	# Finish removing the old district in small branches before starting its
	# replacement. This avoids simultaneous retirement and registration spikes.
	if not _retiring_districts.is_empty():
		return
	for path_value: Variant in _desired_district_paths:
		var path: String = str(path_value)
		if not _loaded_districts.has(path) and not _pending_districts.has(path):
			_request_district(path)


func _begin_district_retirement(district: Node3D) -> void:
	var segment_loader: Node = district.get_node_or_null("DistrictSegmentLoader")
	if segment_loader != null:
		segment_loader.set_process(false)
	district.process_mode = Node.PROCESS_MODE_DISABLED
	_retiring_districts.append(district)


func _drain_one_retiring_chunk() -> bool:
	while not _retiring_chunks.is_empty() and not is_instance_valid(_retiring_chunks[0]):
		_retiring_chunks.pop_front()
	if _retiring_chunks.is_empty():
		return false
	var chunk: Node3D = _retiring_chunks.pop_front()
	chunk.queue_free()
	return true


func _drain_one_retiring_district_branch() -> bool:
	while not _retiring_districts.is_empty() and not is_instance_valid(_retiring_districts[0]):
		_retiring_districts.pop_front()
	if _retiring_districts.is_empty():
		return false
	var district: Node3D = _retiring_districts[0]
	for container_name: String in [
		"GameplaySockets", "WorldGeometry", "Dressing", "RouteMarkers", "M8RenderBatches",
	]:
		var container: Node = district.get_node_or_null(container_name)
		if container == null:
			continue
		for child: Node in container.get_children():
			if child.is_queued_for_deletion():
				continue
			var branch: Node = _retirement_branch(child)
			_last_retired_branch = str(district.get_path_to(branch))
			branch.queue_free()
			return true
	district.queue_free()
	_retiring_districts.pop_front()
	if streaming_target != null:
		_refresh_streaming(streaming_target.global_position)
	return true


func _retirement_branch(node: Node) -> Node:
	if not node.scene_file_path.is_empty():
		return node
	var live_children: Array[Node] = []
	for child: Node in node.get_children():
		if not child.is_queued_for_deletion():
			live_children.append(child)
	if live_children.size() > 3:
		return _retirement_branch(live_children[0])
	return node


func _request_chunk(path: String) -> void:
	var request_error: Error = ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if request_error != OK:
		push_error("Unable to request Lanka chunk %s: %s" % [path, error_string(request_error)])
		return
	_pending_chunks[path] = true


func _request_district(path: String) -> void:
	var request_error: Error = ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if request_error != OK:
		push_error("Unable to request Lanka district %s: %s" % [path, error_string(request_error)])
		return
	_pending_districts[path] = true


func _poll_pending_chunks(instantiate_budget: int) -> int:
	if instantiate_budget <= 0:
		return 0
	var pending_paths: Array = _pending_chunks.keys()
	pending_paths.sort()
	for path_value: Variant in pending_paths:
		var path: String = str(path_value)
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_pending_chunks.erase(path)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			push_error("Threaded loading failed for Lanka chunk: %s" % path)
			continue
		var resource: Resource = ResourceLoader.load_threaded_get(path)
		if not _desired_paths.has(path) or not resource is PackedScene:
			continue
		var chunk: Node3D = (resource as PackedScene).instantiate() as Node3D
		if chunk == null:
			push_error("Lanka chunk root must be Node3D: %s" % path)
			continue
		_chunk_container.add_child(chunk)
		_loaded_chunks[path] = chunk
		instantiate_budget -= 1
		if instantiate_budget <= 0:
			return 0
	return instantiate_budget


func _poll_pending_districts(instantiate_budget: int) -> int:
	if instantiate_budget <= 0:
		return 0
	var pending_paths: Array = _pending_districts.keys()
	pending_paths.sort()
	for path_value: Variant in pending_paths:
		var path: String = str(path_value)
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_pending_districts.erase(path)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			push_error("Threaded loading failed for Lanka district: %s" % path)
			continue
		var resource: Resource = ResourceLoader.load_threaded_get(path)
		if not _desired_district_paths.has(path) or not resource is PackedScene:
			continue
		var district: Node3D = (resource as PackedScene).instantiate() as Node3D
		if district == null:
			push_error("Lanka district root must be Node3D: %s" % path)
			continue
		_district_container.add_child(district)
		_loaded_districts[path] = district
		instantiate_budget -= 1
		if instantiate_budget <= 0:
			return 0
	return instantiate_budget
