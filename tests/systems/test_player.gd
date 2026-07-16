extends GutTest
## M2 player controller: structure, layers, crouch, landing, and the
## character contract's capsule fallback. Feel is the human's to judge;
## these tests pin the contract.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

const CONTRACT_NODES: Array[String] = [
	"Collider", "Visual", "Visual/FallbackCapsule", "Animator", "CeilingCheck",
	"CameraRig", "CameraRig/Pitch", "CameraRig/Pitch/SpringArm3D",
	"CameraRig/Pitch/SpringArm3D/Camera3D", "ClimbController", "GripDust",
]


func _make_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


func test_contract_nodes_exist() -> void:
	var player: Player = _make_player()
	for path: String in CONTRACT_NODES:
		assert_not_null(player.get_node_or_null(path), "missing node: %s" % path)


func test_physics_layers() -> void:
	var player: Player = _make_player()
	assert_eq(player.collision_layer, 2, "player sits on layer 2 (player)")
	assert_eq(player.collision_mask, 13, "player collides with world|climbable|carryable")


func test_fallback_capsule_visible_without_mesh() -> void:
	var player: Player = _make_player()
	assert_null(player.mesh_scene, "no mesh ships yet; WORLD delivers the placeholder")
	var capsule: MeshInstance3D = player.get_node("Visual/FallbackCapsule") as MeshInstance3D
	assert_true(capsule.visible, "capsule fallback shows when no mesh is mounted")


func test_no_stamina_exists() -> void:
	var player: Player = _make_player()
	assert_false("stamina" in player, "no stamina, ever (ARCHITECTURE §2)")


func test_speed_ordering() -> void:
	var player: Player = _make_player()
	assert_lt(player.crouch_speed, player.run_speed, "crouching is slower than running")
	assert_lt(player.run_speed, player.sprint_speed, "sprinting is faster than running")


func test_crouch_resizes_capsule_and_signals() -> void:
	var player: Player = _make_player()
	watch_signals(player)
	assert_true(player.set_crouching(true), "crouching is always allowed")
	var capsule: CapsuleShape3D = (player.get_node("Collider") as CollisionShape3D).shape as CapsuleShape3D
	assert_almost_eq(capsule.height, player.crouch_height, 0.001, "capsule shrinks on crouch")
	assert_signal_emitted(player, "crouch_changed")
	assert_true(player.set_crouching(false), "nothing overhead: standing is allowed")
	assert_almost_eq(capsule.height, player.stand_height, 0.001, "capsule restores on stand")


func test_falls_lands_and_emits_landed() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10, 1, 10)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child_autofree(floor_body)

	var player: Player = _make_player()
	player.position = Vector3(0, 2.0, 0)
	watch_signals(player)
	await wait_physics_frames(90)
	assert_true(player.is_on_floor(), "player fell and landed on the floor")
	assert_signal_emitted(player, "landed")
