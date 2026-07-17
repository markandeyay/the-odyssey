extends GutTest
## The district trigger volume (WORLD's M5 prefab request): the thing
## that finally emits `district_entered` outside a test. Entry fires the
## signal, GameState tracks the current district, and the first entry —
## and only the first — requests an autosave (M6).

const TRIGGER_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/district_trigger.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _player: Player


func before_each() -> void:
	GameState.reset()
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(200, 1, 200)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child_autofree(floor_body)
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.position = Vector3(60, 0.1, 0)  # outside every trigger box


func after_all() -> void:
	GameState.reset()


func _make_trigger(district_id: StringName, at: Vector3 = Vector3.ZERO) -> DistrictTrigger:
	var trigger: DistrictTrigger = TRIGGER_SCENE.instantiate()
	trigger.district_id = district_id
	add_child_autofree(trigger)
	trigger.position = at
	return trigger


func test_player_entry_emits_district_entered() -> void:
	_make_trigger(&"the_shallows")
	await wait_physics_frames(2)
	watch_signals(EventBus)
	_player.global_position = Vector3(0, 0.1, 0)
	await wait_physics_frames(3)
	assert_signal_emitted_with_parameters(
		EventBus, "district_entered", [&"the_shallows"]
	)
	assert_eq(GameState.current_district, &"the_shallows", "GameState tracks the district")
	assert_true(GameState.visited_districts.has(&"the_shallows"))


## Each test parks its trigger somewhere no earlier test's player ever
## stood: a freed body can linger a physics frame, and an overlap during
## setup would consume the first-entry autosave unwatched.
func test_first_entry_autosaves_reentry_does_not() -> void:
	_make_trigger(&"the_terraces", Vector3(0, 0, 80))
	await wait_physics_frames(2)
	watch_signals(EventBus)
	_player.global_position = Vector3(0, 0.1, 80)
	await wait_physics_frames(3)
	assert_signal_emit_count(EventBus, "autosave_requested", 1, "first entry autosaves")
	_player.global_position = Vector3(60, 0.1, 0)
	await wait_physics_frames(3)
	_player.global_position = Vector3(0, 0.1, 80)
	await wait_physics_frames(3)
	assert_signal_emit_count(EventBus, "autosave_requested", 1, "re-entry does not")
	assert_signal_emit_count(EventBus, "district_entered", 2, "but entry still announces")


func test_crossing_between_districts_switches_current() -> void:
	_make_trigger(&"the_shallows", Vector3(-80, 0, 0))
	_make_trigger(&"the_terraces", Vector3(80, 0, 0))
	await wait_physics_frames(2)
	_player.global_position = Vector3(-80, 0.1, 0)
	await wait_physics_frames(3)
	assert_eq(GameState.current_district, &"the_shallows")
	_player.global_position = Vector3(80, 0.1, 0)
	await wait_physics_frames(3)
	assert_eq(GameState.current_district, &"the_terraces", "the newest entry wins")


func test_non_player_bodies_do_not_trigger() -> void:
	_make_trigger(&"the_shallows", Vector3(0, 0, -80))
	await wait_physics_frames(2)
	watch_signals(EventBus)
	var crate: RigidBody3D = RigidBody3D.new()
	crate.collision_layer = 8
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	crate.add_child(shape)
	add_child_autofree(crate)
	crate.position = Vector3(0, 2, -80)
	await wait_physics_frames(5)
	assert_signal_not_emitted(EventBus, "district_entered", "only Nau enters districts")