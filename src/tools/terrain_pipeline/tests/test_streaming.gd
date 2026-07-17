extends SceneTree

const LankaTerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")
const LANKA_SCENE_PATH: String = "res://scenes/levels/lanka/lanka.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load(LANKA_SCENE_PATH) as PackedScene
	_expect(packed != null, "Lanka streaming root loads")
	if packed == null:
		quit(_failures)
		return
	var lanka: Node3D = packed.instantiate() as Node3D
	root.add_child(lanka)
	var target: Node3D = Node3D.new()
	target.name = "StreamingTestTarget"
	root.add_child(target)
	lanka.call("set_streaming_target", target)
	var center_paths: PackedStringArray = lanka.call("desired_chunk_paths", Vector3.ZERO) as PackedStringArray
	await _wait_for_streaming(lanka, center_paths, center_paths.size())
	_expect(lanka.call("pending_chunk_count") == 0, "center chunk requests finish")
	_expect(lanka.call("loaded_chunk_count") == center_paths.size(), "center stream set becomes resident")
	_expect(_loaded_paths_include(lanka, center_paths), "center desired chunks are instantiated")

	target.global_position = Vector3(500.0, 0.0, 500.0)
	var corner_paths: PackedStringArray = lanka.call(
		"desired_chunk_paths", target.global_position
	) as PackedStringArray
	await _wait_for_streaming(lanka, corner_paths, 6)
	_expect(lanka.call("pending_chunk_count") == 0, "corner chunk requests finish")
	_expect(_loaded_paths_include(lanka, corner_paths), "corner desired chunks are instantiated")
	_expect(lanka.call("loaded_chunk_count") <= 6, "stream hysteresis keeps the corner resident set bounded")
	_expect(lanka.call("loaded_chunk_count") < center_paths.size(), "distant center chunks unload")

	lanka.queue_free()
	target.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: Odyssey M4 threaded Lanka terrain streaming")
	else:
		printerr("FAIL: %d Odyssey M4 streaming assertion(s)" % _failures)
	quit(_failures)


func _wait_for_streaming(
	lanka: Node3D, desired_paths: PackedStringArray, maximum_loaded: int
) -> void:
	for frame: int in 600:
		await process_frame
		var loaded: int = int(lanka.call("loaded_chunk_count"))
		var pending: int = int(lanka.call("pending_chunk_count"))
		if (
			pending == 0
			and loaded >= desired_paths.size()
			and loaded <= maximum_loaded
			and _loaded_paths_include(lanka, desired_paths)
		):
			return
	_expect(false, "threaded stream operation completes before timeout")


func _loaded_paths_include(lanka: Node3D, desired_paths: PackedStringArray) -> bool:
	var loaded_paths: Dictionary = {}
	var container: Node = lanka.get_node("StreamedChunks")
	for child: Node in container.get_children():
		loaded_paths[child.scene_file_path] = true
	for path: String in desired_paths:
		if not loaded_paths.has(path):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("ASSERTION FAILED: %s" % message)
