extends Node3D

const LankaTerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")
const LankaDistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")

@export var streaming_target: Node3D
@export_range(220.0, 600.0, 10.0, "suffix:m") var load_radius_m: float = LankaTerrainContract.LOAD_RADIUS_M
@export_range(300.0, 800.0, 10.0, "suffix:m") var unload_radius_m: float = LankaTerrainContract.UNLOAD_RADIUS_M
@export_range(0.05, 2.0, 0.05, "suffix:s") var refresh_interval_s: float = 0.25

var _refresh_elapsed_s: float = 0.0
var _desired_paths: Dictionary = {}
var _loaded_chunks: Dictionary = {}
var _pending_chunks: Dictionary = {}
var _desired_district_paths: Dictionary = {}
var _loaded_districts: Dictionary = {}
var _pending_districts: Dictionary = {}
var _last_stream_position: Vector3 = Vector3.INF
var _initial_stream_guard_active: bool = false
var _initial_target_physics_enabled: bool = false
var _initial_target_transform: Transform3D = Transform3D.IDENTITY

@onready var _chunk_container: Node3D = $StreamedChunks
@onready var _district_container: Node3D = $StreamedDistricts


func _ready() -> void:
	if unload_radius_m <= load_radius_m:
		push_error("Lanka unload radius must be greater than its load radius")
	if streaming_target != null:
		_begin_initial_stream_guard()
		_refresh_streaming(streaming_target.global_position)


func _process(delta: float) -> void:
	_poll_pending_chunks()
	_poll_pending_districts()
	_release_initial_stream_guard_if_ready()
	if streaming_target == null:
		return
	_refresh_elapsed_s += delta
	if _refresh_elapsed_s < refresh_interval_s:
		return
	_refresh_elapsed_s = 0.0
	_refresh_streaming(streaming_target.global_position)


func set_streaming_target(target: Node3D) -> void:
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
		chunk.queue_free()
	_refresh_district_streaming(world_position)


func _refresh_district_streaming(world_position: Vector3) -> void:
	_desired_district_paths.clear()
	for path: String in desired_district_paths(world_position):
		_desired_district_paths[path] = true
		if not _loaded_districts.has(path) and not _pending_districts.has(path):
			_request_district(path)
	var horizontal_position: Vector2 = Vector2(world_position.x, world_position.z)
	for path_value: Variant in _loaded_districts.keys():
		var path: String = str(path_value)
		var data: Dictionary = LankaDistrictContract.data_for_path(path)
		var center: Vector3 = data.get("center", Vector3.ZERO) as Vector3
		if horizontal_position.distance_to(Vector2(center.x, center.z)) <= float(data.get("unload_radius_m", 0.0)):
			continue
		var district: Node3D = _loaded_districts[path] as Node3D
		_loaded_districts.erase(path)
		district.queue_free()


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


func _poll_pending_chunks() -> void:
	for path_value: Variant in _pending_chunks.keys():
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


func _poll_pending_districts() -> void:
	for path_value: Variant in _pending_districts.keys():
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
