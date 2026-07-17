extends SceneTree

const LANKA_SCENE_PATH: String = "res://scenes/levels/lanka/lanka.tscn"
const PLAYER_PATH: NodePath = ^"DistrictAnchors/Shallows/Player"

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load(LANKA_SCENE_PATH) as PackedScene
	_expect(packed != null, "Lanka runnable scene loads")
	if packed == null:
		quit(_failures)
		return

	var lanka: Node3D = packed.instantiate() as Node3D
	_expect(lanka != null, "Lanka runnable scene instantiates")
	if lanka == null:
		quit(_failures)
		return

	var shallows: Node3D = lanka.get_node_or_null("DistrictAnchors/Shallows") as Node3D
	var player: Node3D = lanka.get_node_or_null(PLAYER_PATH) as Node3D
	_expect(shallows != null, "Shallows spawn anchor exists")
	_expect(player != null, "SYSTEMS player scene is instanced at the Shallows anchor")
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED

	root.add_child(lanka)
	await process_frame

	_expect(lanka.get("streaming_target") == player, "live player drives Lanka streaming")
	if shallows != null and player != null:
		_expect(
			player.global_position.is_equal_approx(shallows.global_position),
			"player starts exactly at the Shallows anchor"
		)

	var camera: Camera3D = _find_descendant_of_type(player, &"Camera3D") as Camera3D
	_expect(camera != null, "instanced player contributes a Camera3D")
	if camera != null:
		_expect(camera.is_current(), "player camera is current in the runnable scene")

	var environment_node: WorldEnvironment = lanka.get_node_or_null(
		"PersistentLook/SmokeEnvironment"
	) as WorldEnvironment
	_expect(
		environment_node != null and environment_node.environment != null,
		"persistent M7 WorldEnvironment is active before streaming completes"
	)
	var sun: DirectionalLight3D = lanka.get_node_or_null(
		"PersistentLook/LowSmokeSun"
	) as DirectionalLight3D
	_expect(sun != null, "persistent low smoke sun is active before streaming completes")

	await _wait_for_initial_streaming(lanka)
	var chunk_count: int = lanka.get_node("StreamedChunks").get_child_count()
	var district_count: int = lanka.get_node("StreamedDistricts").get_child_count()
	_expect(chunk_count > 0, "StreamedChunks populates around the Shallows player")
	_expect(district_count > 0, "StreamedDistricts populates around the Shallows player")

	print(
		"RUNTIME: player=%s camera=%s environment=%s sun=%s chunks=%d districts=%d"
		% [
			player != null,
			camera != null and camera.is_current(),
			environment_node != null and environment_node.environment != null,
			sun != null,
			chunk_count,
			district_count,
		]
	)

	lanka.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: Lanka runnable-scene integration")
	else:
		printerr("FAIL: %d Lanka runnable-scene assertion(s)" % _failures)
	quit(_failures)


func _wait_for_initial_streaming(lanka: Node3D) -> void:
	for frame: int in 600:
		await process_frame
		if (
			int(lanka.call("pending_chunk_count")) == 0
			and int(lanka.call("pending_district_count")) == 0
			and int(lanka.call("loaded_chunk_count")) > 0
			and int(lanka.call("loaded_district_count")) > 0
		):
			return
	_expect(false, "initial player-driven streaming completes before timeout")


func _find_descendant_of_type(parent: Node, type_name: StringName) -> Node:
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child.is_class(type_name):
			return child
		var nested: Node = _find_descendant_of_type(child, type_name)
		if nested != null:
			return nested
	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("ASSERTION FAILED: %s" % message)
