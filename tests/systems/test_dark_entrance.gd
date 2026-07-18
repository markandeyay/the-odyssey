extends GutTest
## The Dark doorway (WORLD's M5 sublevel-transition request): entering
## instances the sub-scene at its authored world transform and moves Nau
## to RouteMarkers/Entry; touching RouteMarkers/Exit returns him to the
## doorway and frees the interior. The Dark never joins open-world
## streaming — this prefab is the only way in (ARCHITECTURE §10).

const ENTRANCE_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/dark_entrance.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

## The fake interior is authored in world space like the real Dark.
const INTERIOR_ORIGIN: Vector3 = Vector3(0, -100, 400)
const ENTRY_LOCAL: Vector3 = Vector3(0, 1, -60)
const EXIT_LOCAL: Vector3 = Vector3(0, 1, 40)

var _player: Player


func before_each() -> void:
	GameState.reset()
	_add_floor(Vector3.ZERO)
	_add_floor(INTERIOR_ORIGIN + Vector3(0, -0.5, 0))
	_player = PLAYER_SCENE.instantiate()
	# Parked before entering the tree: a body added at the origin leaves a
	# stale origin overlap in the physics server for a frame, which would
	# trip the doorway before the test walks Nau into it.
	_player.position = Vector3(60, 0.1, 0)
	add_child_autofree(_player)


func after_all() -> void:
	GameState.reset()


func _add_floor(at: Vector3) -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	shape.shape = box
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	floor_body.position = at + Vector3(0, -0.5, 0)


func _make_interior_scene(with_exit: bool, with_carryable: bool = false) -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "FakeDark"
	root.position = INTERIOR_ORIGIN
	var markers: Node3D = Node3D.new()
	markers.name = "RouteMarkers"
	root.add_child(markers)
	markers.owner = root
	var entry: Marker3D = Marker3D.new()
	entry.name = "Entry"
	markers.add_child(entry)
	entry.owner = root
	entry.position = ENTRY_LOCAL
	if with_exit:
		var exit_marker: Marker3D = Marker3D.new()
		exit_marker.name = "Exit"
		markers.add_child(exit_marker)
		exit_marker.owner = root
		exit_marker.position = EXIT_LOCAL
	if with_carryable:
		var carryable: RigidBody3D = RigidBody3D.new()
		carryable.name = "FakeFigurehead"
		carryable.collision_layer = 8
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		carryable.add_child(shape)
		root.add_child(carryable)
		carryable.owner = root
		shape.owner = root
		carryable.position = Vector3(0, 1, 0)
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _make_entrance(interior: PackedScene) -> DarkEntrance:
	var entrance: DarkEntrance = ENTRANCE_SCENE.instantiate()
	entrance.target_scene = interior
	add_child_autofree(entrance)
	return entrance


func _interior_node(entrance: DarkEntrance) -> Node3D:
	return entrance.get_node_or_null(^"FakeDark") as Node3D


func test_entering_doorway_transfers_to_entry() -> void:
	var entrance: DarkEntrance = _make_entrance(_make_interior_scene(true))
	await wait_physics_frames(2)
	_player.global_position = Vector3(0, 0.1, 0)
	await wait_physics_frames(4)
	var interior: Node3D = _interior_node(entrance)
	assert_not_null(interior, "the sub-scene is instanced under the entrance")
	if interior != null:
		assert_almost_eq(
			interior.global_position, INTERIOR_ORIGIN, Vector3.ONE * 0.01,
			"the interior keeps its authored world transform"
		)
	var entry_global: Vector3 = INTERIOR_ORIGIN + ENTRY_LOCAL
	assert_almost_eq(_player.global_position.x, entry_global.x, 1.0, "Nau stands at Entry (x)")
	assert_almost_eq(_player.global_position.z, entry_global.z, 1.0, "Nau stands at Entry (z)")


func test_exit_returns_nau_and_frees_interior() -> void:
	var entrance: DarkEntrance = _make_entrance(_make_interior_scene(true))
	await wait_physics_frames(2)
	_player.global_position = Vector3(0, 0.1, 0)
	await wait_physics_frames(4)
	assert_not_null(_interior_node(entrance), "inside The Dark")
	_player.global_position = INTERIOR_ORIGIN + EXIT_LOCAL
	await wait_physics_frames(4)
	assert_null(_interior_node(entrance), "the interior is freed on exit")
	assert_almost_eq(_player.global_position.x, 0.0, 1.0, "Nau is back at the doorway (x)")
	assert_almost_eq(_player.global_position.z, 0.0, 1.0, "Nau is back at the doorway (z)")


func test_trial_gate_holds_until_complete() -> void:
	var entrance: DarkEntrance = _make_entrance(_make_interior_scene(true))
	entrance.required_trial_id = &"the_spine"
	await wait_physics_frames(2)
	_player.global_position = Vector3(0, 0.1, 0)
	await wait_physics_frames(4)
	assert_null(_interior_node(entrance), "the doorway is inert before the Spine trial")
	_player.global_position = Vector3(60, 0.1, 0)
	await wait_physics_frames(3)
	EventBus.trial_completed.emit(&"the_spine")
	await wait_physics_frames(1)
	_player.global_position = Vector3(0, 0.1, 0)
	await wait_physics_frames(4)
	assert_not_null(_interior_node(entrance), "the trial completion opens The Dark")


func test_carried_body_survives_exit() -> void:
	var entrance: DarkEntrance = _make_entrance(_make_interior_scene(true, true))
	await wait_physics_frames(2)
	_player.global_position = Vector3(0, 0.1, 0)
	await wait_physics_frames(4)
	var interior: Node3D = _interior_node(entrance)
	assert_not_null(interior, "inside The Dark")
	var carryable: RigidBody3D = interior.get_node(^"FakeFigurehead") as RigidBody3D
	var carry: CarryController = _player.get_node(^"CarryController") as CarryController
	assert_true(carry.pick_up(carryable), "Nau picks up the figurehead stand-in")
	_player.global_position = INTERIOR_ORIGIN + EXIT_LOCAL
	await wait_physics_frames(4)
	assert_null(_interior_node(entrance), "the interior is freed")
	assert_true(is_instance_valid(carryable), "the carried body is not freed with it")
	assert_eq(carry.held, carryable, "the carry survives the transition")


func test_entry_doubles_as_exit_only_after_leaving_it() -> void:
	var entrance: DarkEntrance = _make_entrance(_make_interior_scene(false))
	await wait_physics_frames(2)
	_player.global_position = Vector3(0, 0.1, 0)
	await wait_physics_frames(4)
	assert_not_null(_interior_node(entrance), "arrival at Entry does not bounce Nau straight back")
	_player.global_position = INTERIOR_ORIGIN + Vector3(0, 1, 20)
	await wait_physics_frames(4)
	_player.global_position = INTERIOR_ORIGIN + ENTRY_LOCAL
	await wait_physics_frames(4)
	assert_null(_interior_node(entrance), "returning to the mouth leads back out")
	assert_almost_eq(_player.global_position.z, 0.0, 1.0, "Nau is back at the doorway")
