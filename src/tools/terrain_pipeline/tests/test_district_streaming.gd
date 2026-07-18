extends SceneTree

const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")
const LANKA_SCENE_PATH: String = "res://scenes/levels/lanka/lanka.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load(LANKA_SCENE_PATH) as PackedScene
	_expect(packed != null, "Lanka streaming root loads")
	if packed == null:
		_finish.call_deferred(_failures)
		return
	var lanka: Node3D = packed.instantiate() as Node3D
	root.add_child(lanka)
	var target: Node3D = Node3D.new()
	root.add_child(target)
	lanka.call("set_streaming_target", target)
	await _move_and_expect(lanka, target, DistrictContract.district_center(&"shallows"), 1, "Shallows")
	await _move_and_expect(lanka, target, DistrictContract.district_center(&"ember_quarter"), 1, "Ember")
	_expect(
		not _loaded_district_paths(lanka).has(DistrictContract.district_path(&"cistern")),
		"Cistern is not resident in the Ember vertical district"
	)
	await _move_and_expect(lanka, target, DistrictContract.district_center(&"cistern"), 1, "Cistern")
	_expect(
		not _loaded_district_paths(lanka).has(DistrictContract.district_path(&"ember_quarter")),
		"Ember is not resident in the Cistern vertical district"
	)
	await _move_and_expect(lanka, target, DistrictContract.district_center(&"terraces"), 1, "Terraces")
	var loaded_paths: PackedStringArray = _loaded_district_paths(lanka)
	_expect(not loaded_paths.has(DistrictContract.DARK_PATH), "The Dark never joins open-world streaming")
	var landmarks: Node = lanka.get_node("PersistentLandmarks")
	_expect(landmarks.get_child_count() == 1, "exactly one persistent landmark is resident")
	if landmarks.get_child_count() == 1:
		_expect(landmarks.get_child(0).scene_file_path == DistrictContract.SPINE_PATH, "full Spine remains persistent")
	for frame: int in 1200:
		await process_frame
		if int(lanka.call("pending_chunk_count")) == 0 and int(lanka.call("pending_district_count")) == 0:
			break
	lanka.queue_free()
	target.queue_free()
	# Let the render/resource servers retire threaded-load references before the
	# SceneTree exits; quitting on the first free tick produces false leak noise.
	for frame: int in 120:
		await process_frame
	if _failures == 0:
		print("PASS: Odyssey M5 threaded district streaming")
	else:
		printerr("FAIL: %d Odyssey M5 district streaming assertion(s)" % _failures)
	_finish.call_deferred(_failures)


func _finish(exit_code: int) -> void:
	quit(exit_code)


func _move_and_expect(
	lanka: Node3D, target: Node3D, position: Vector3, expected_count: int, label: String
) -> void:
	target.global_position = position
	var desired: PackedStringArray = lanka.call("desired_district_paths", position) as PackedStringArray
	_expect(desired.size() == expected_count, "%s desired district count is bounded" % label)
	for frame: int in 600:
		await process_frame
		if (
			int(lanka.call("pending_district_count")) == 0
			and int(lanka.call("loaded_district_count")) == expected_count
			and _includes_all(_loaded_district_paths(lanka), desired)
			and _desired_districts_ready(lanka, desired)
		):
			return
	_expect(
		false,
		"%s transition timed out: desired=%s loaded=%s pending=%d retiring=%d"
		% [
			label,
			desired,
			_loaded_district_paths(lanka),
			int(lanka.call("pending_district_count")),
			int(lanka.call("retiring_district_count")),
		]
	)


func _loaded_district_paths(lanka: Node3D) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for child: Node in lanka.get_node("StreamedDistricts").get_children():
		paths.append(child.scene_file_path)
	paths.sort()
	return paths


func _includes_all(actual: PackedStringArray, expected: PackedStringArray) -> bool:
	for path: String in expected:
		if not actual.has(path):
			return false
	return true


func _desired_districts_ready(lanka: Node3D, desired: PackedStringArray) -> bool:
	for path: String in desired:
		var found: bool = false
		for child: Node in lanka.get_node("StreamedDistricts").get_children():
			if child.scene_file_path != path:
				continue
			found = true
			if not bool(child.get_meta(&"district_streaming_ready", true)):
				return false
			break
		if not found:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("ASSERTION FAILED: %s" % message)
