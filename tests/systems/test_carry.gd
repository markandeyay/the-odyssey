extends GutTest
## M4 carry: freeze on pickup, follow the hold point, unfreeze on drop,
## speed penalty, and the load-bearing requirement — stack crates into a
## stair and stand on it.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/carry_crate.tscn")

var _player: Player
var _carry: CarryController


func before_each() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(30, 1, 30)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child_autofree(floor_body)

	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.position = Vector3.ZERO
	_carry = _player.get_node("CarryController") as CarryController


func _spawn_crate(at: Vector3) -> RigidBody3D:
	var crate: RigidBody3D = CRATE_SCENE.instantiate()
	crate.position = at
	add_child_autofree(crate)
	return crate


func test_pick_up_freezes_and_disables_collision() -> void:
	var crate: RigidBody3D = _spawn_crate(Vector3(0, 0.35, -1.2))
	await wait_physics_frames(5)
	watch_signals(_carry)
	assert_true(_carry.pick_up(crate))
	assert_true(crate.freeze, "held bodies freeze")
	assert_eq(crate.collision_layer, 0, "held bodies collide with nothing")
	assert_true(_player.is_carrying, "player knows it is carrying")
	assert_signal_emitted(_carry, "picked_up")
	assert_false(_carry.pick_up(_spawn_crate(Vector3(2, 0.35, 0))), "one object at a time")


func test_held_crate_follows_hold_point() -> void:
	var crate: RigidBody3D = _spawn_crate(Vector3(0, 0.35, -1.2))
	await wait_physics_frames(5)
	_carry.pick_up(crate)
	await wait_physics_frames(20)
	var chest: Vector3 = _player.global_position + Vector3.UP * 1.0
	assert_lt(crate.global_position.distance_to(chest), 1.2, "crate hovers at the hold point")


func test_drop_restores_physics_and_settles() -> void:
	var crate: RigidBody3D = _spawn_crate(Vector3(0, 0.35, -1.2))
	await wait_physics_frames(5)
	_carry.pick_up(crate)
	await wait_physics_frames(10)
	watch_signals(_carry)
	assert_true(_carry.drop())
	assert_false(crate.freeze, "dropped bodies unfreeze")
	assert_eq(crate.collision_layer, 24, "original layers restored")
	assert_false(_player.is_carrying)
	assert_signal_emitted(_carry, "dropped")
	await wait_physics_frames(80)
	assert_between(crate.global_position.y, 0.2, 0.45, "crate settled back on the floor")


func test_carrying_slows_and_blocks_sprint_speed() -> void:
	var crate: RigidBody3D = _spawn_crate(Vector3(0, 0.35, -1.2))
	await wait_physics_frames(5)
	var free_speed: float = _player._current_speed()
	_carry.pick_up(crate)
	var loaded_speed: float = _player._current_speed()
	assert_lt(loaded_speed, free_speed, "carrying reduces speed")


func test_stack_two_crates_and_stand_on_them() -> void:
	var base: RigidBody3D = _spawn_crate(Vector3(3, 0.35, -3))
	var top: RigidBody3D = _spawn_crate(Vector3(0, 0.35, -1.2))
	await wait_physics_frames(10)
	_carry.pick_up(top)
	# Hold point sits 0.8m in front of the visual (facing -Z by default),
	# so standing at z=-2.2 parks the held crate directly over the base.
	_player.global_position = Vector3(3, 0.05, -2.2)
	await wait_physics_frames(15)
	_carry.drop()
	await wait_physics_frames(80)
	assert_gt(top.global_position.y, base.global_position.y + 0.4, "top crate rests on base crate")
	assert_between(top.global_position.y, 0.75, 1.1, "stack is two crates tall")

	_player.global_position = Vector3(3, 1.7, -3)
	await wait_physics_frames(40)
	assert_true(_player.is_on_floor(), "player stands on the stacked crates")
	assert_gt(_player.global_position.y, 1.0, "player is on top of the stack, not the floor")
