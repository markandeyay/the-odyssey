class_name LankaDistrictSegmentLoader
extends Node
## Adds generated district batches over consecutive frames. The host district
## stays a normal PackedScene; only its heavy authored branches are deferred.

@export var segment_paths: PackedStringArray = PackedStringArray()
@export var segment_parent_paths: Array[NodePath] = []

var _next_segment: int = 0
var _failed: bool = false
var _last_loaded_segment_path: String = ""
var _request_active: bool = false


func _ready() -> void:
	get_parent().set_meta(&"district_streaming_ready", segment_paths.is_empty())
	if segment_paths.size() != segment_parent_paths.size():
		_fail("District segment path/parent counts differ")
		return
	if not segment_paths.is_empty():
		_request_current_segment()
	set_process(_request_active)


func _process(_delta: float) -> void:
	if _failed or _next_segment >= segment_paths.size():
		set_process(false)
		return
	var path: String = segment_paths[_next_segment]
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		_fail("Threaded loading failed for district segment %s" % path)
		return
	var packed: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
	_request_active = false
	if packed == null or not _append_segment(packed, segment_parent_paths[_next_segment]):
		_fail("Unable to instantiate district segment %s" % path)
		return
	_last_loaded_segment_path = path
	_next_segment += 1
	if _next_segment == segment_paths.size():
		get_parent().set_meta(&"district_streaming_ready", true)
		set_process(false)
	else:
		_request_current_segment()


func load_all_immediately() -> bool:
	if segment_paths.size() != segment_parent_paths.size():
		return false
	for segment_index: int in range(_next_segment, segment_paths.size()):
		var packed: PackedScene
		if segment_index == _next_segment and _request_active:
			packed = ResourceLoader.load_threaded_get(segment_paths[segment_index]) as PackedScene
			_request_active = false
		else:
			packed = load(segment_paths[segment_index]) as PackedScene
		if packed == null or not _append_segment(packed, segment_parent_paths[segment_index]):
			return false
	_next_segment = segment_paths.size()
	get_parent().set_meta(&"district_streaming_ready", true)
	set_process(false)
	return true


func loaded_segment_count() -> int:
	return _next_segment


func last_loaded_segment_path() -> String:
	return _last_loaded_segment_path


func _request_current_segment() -> void:
	var path: String = segment_paths[_next_segment]
	# Each segment is intentionally small. Keeping one non-subthreaded request in
	# flight bounds resource work as well as scene-tree mutation to one segment.
	var request_error: Error = ResourceLoader.load_threaded_request(path, "PackedScene", false)
	if request_error != OK:
		_fail("Unable to request district segment %s: %s" % [path, error_string(request_error)])
		return
	_request_active = true
	set_process(true)


func _append_segment(packed: PackedScene, parent_path: NodePath) -> bool:
	var segment: Node = packed.instantiate()
	var target: Node = get_node_or_null(parent_path)
	if segment == null or target == null:
		if segment != null:
			segment.free()
		return false
	while segment.get_child_count() > 0:
		var child: Node = segment.get_child(0)
		child.owner = null
		segment.remove_child(child)
		target.add_child(child)
	segment.free()
	return true


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	get_parent().set_meta(&"district_streaming_failed", true)
	set_process(false)
