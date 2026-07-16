extends Node3D

const LankaTerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")

@export var streaming_target: Node3D
@export_range(220.0, 600.0, 10.0, "suffix:m") var load_radius_m: float = LankaTerrainContract.LOAD_RADIUS_M
@export_range(300.0, 800.0, 10.0, "suffix:m") var unload_radius_m: float = LankaTerrainContract.UNLOAD_RADIUS_M
@export_range(0.05, 2.0, 0.05, "suffix:s") var refresh_interval_s: float = 0.25

var _refresh_elapsed_s: float = 0.0
var _desired_paths: Dictionary = {}
var _loaded_chunks: Dictionary = {}
var _pending_chunks: Dictionary = {}
var _last_stream_position: Vector3 = Vector3.INF

@onready var _chunk_container: Node3D = $StreamedChunks


func _ready() -> void:
	if unload_radius_m <= load_radius_m:
		push_error("Lanka unload radius must be greater than its load radius")
	if streaming_target != null:
		_refresh_streaming(streaming_target.global_position)


func _process(delta: float) -> void:
	_poll_pending_chunks()
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


func desired_chunk_paths(world_position: Vector3) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	var horizontal_position: Vector2 = Vector2(world_position.x, world_position.z)
	for coordinate: Vector2i in LankaTerrainContract.all_chunk_coordinates():
		if horizontal_position.distance_to(LankaTerrainContract.chunk_center(coordinate)) <= load_radius_m:
			paths.append(LankaTerrainContract.chunk_path(coordinate))
	paths.sort()
	return paths


func loaded_chunk_count() -> int:
	return _loaded_chunks.size()


func pending_chunk_count() -> int:
	return _pending_chunks.size()


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


func _request_chunk(path: String) -> void:
	var request_error: Error = ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if request_error != OK:
		push_error("Unable to request Lanka chunk %s: %s" % [path, error_string(request_error)])
		return
	_pending_chunks[path] = true


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
