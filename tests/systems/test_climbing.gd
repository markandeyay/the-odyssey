extends GutTest
## M3 climbing integration: attach to SOLID, refuse SLICK, CRUMBLING fails
## after its hold window, HOT grips and damages, carrying blocks climbing.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _player: Player
var _climb: ClimbController


func before_each() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(20, 1, 20)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child_autofree(floor_body)

	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.position = Vector3.ZERO
	_climb = _player.get_node("ClimbController") as ClimbController


func _add_wall(material_name: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 4  # climbable
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4, 4, 0.4)
	shape.shape = box
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = material_name
	mesh_instance.material_override = material
	body.add_child(shape)
	body.add_child(mesh_instance)
	body.position = Vector3(0, 2, -0.8)
	add_child_autofree(body)
	return body


func test_attaches_to_solid_wall_and_holds() -> void:
	_add_wall("mat_stone_grip_solid")
	await wait_physics_frames(3)
	assert_true(_climb.try_attach(Vector3.FORWARD), "attaches to a solid wall")
	assert_true(_climb.active)
	await wait_physics_frames(30)
	assert_true(_climb.active, "SOLID holds indefinitely — no stamina")


func test_slick_wall_refuses_grip() -> void:
	_add_wall("mat_soot_grip_slick")
	await wait_physics_frames(3)
	assert_false(_climb.try_attach(Vector3.FORWARD), "SLICK cannot be gripped at all")
	assert_false(_climb.active)


func test_crumbling_handhold_fails_after_hold_window() -> void:
	_add_wall("mat_char_grip_crumbling")
	_climb.crumble_hold_time = 0.3
	await wait_physics_frames(3)
	watch_signals(_climb)
	assert_true(_climb.try_attach(Vector3.FORWARD), "CRUMBLING grips at first")
	await wait_physics_frames(40)
	assert_false(_climb.active, "the handhold fails and Nau falls")
	assert_signal_emitted_with_parameters(_climb, "detached", [&"handhold_failed"])
	assert_signal_emitted(_climb, "handhold_failing")


func test_hot_wall_grips_and_damages() -> void:
	_add_wall("mat_ember_grip_hot")
	await wait_physics_frames(3)
	assert_true(_climb.try_attach(Vector3.FORWARD), "HOT grips fine")
	await wait_physics_frames(30)
	assert_true(_climb.active, "HOT never drops you by itself")
	assert_lt(_player.health.current_hearts, float(_player.health.containers),
			"HOT deals contact damage per second")


func test_burning_group_makes_solid_wall_hot() -> void:
	var wall: StaticBody3D = _add_wall("mat_stone_grip_solid")
	wall.add_to_group(Grip.BURNING_GROUP)
	await wait_physics_frames(3)
	assert_true(_climb.try_attach(Vector3.FORWARD))
	await wait_physics_frames(30)
	assert_lt(_player.health.current_hearts, float(_player.health.containers),
			"a burning surface reports HOT and burns")


func test_cannot_climb_while_carrying() -> void:
	_add_wall("mat_stone_grip_solid")
	await wait_physics_frames(3)
	_player.is_carrying = true
	assert_false(_climb.try_attach(Vector3.FORWARD), "no climbing while carrying (M4 rule)")


func test_pressing_away_from_wall_does_not_attach() -> void:
	_add_wall("mat_stone_grip_solid")
	await wait_physics_frames(3)
	assert_false(_climb.try_attach(Vector3.BACK), "must press toward the wall")
