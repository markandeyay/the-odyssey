extends GutTest
## M6 hearts: start at 3, damage clamps at zero and kills exactly once,
## heart-piece math (4 pieces = 1 container, 8 Cairns = exactly 2
## containers, ARCHITECTURE §7), Cairn completion grants one piece, and
## falls hurt only above the threshold speed.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _player: Player
var _health: PlayerHealth


func before_each() -> void:
	SaveSystem.save_path = "user://test_autosave_health.json"
	SaveSystem.delete_save()
	GameState.reset()
	Inventory.clear()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_health = _player.health


func after_each() -> void:
	SaveSystem.delete_save()
	SaveSystem.save_path = "user://autosave.json"


func _add_floor() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -0.5, 0)
	add_child_autofree(body)


func test_starts_with_three_full_hearts() -> void:
	assert_eq(_health.containers, 3, "Nau starts with 3 hearts (ARCHITECTURE §7)")
	assert_eq(_health.pieces, 0)
	assert_almost_eq(_health.current_hearts, 3.0, 0.001)
	assert_false(_health.is_dead)


func test_damage_reduces_and_heal_clamps() -> void:
	_player.apply_damage(1.5, &"fire")
	assert_almost_eq(_health.current_hearts, 1.5, 0.001)
	_health.heal(0.25)
	assert_almost_eq(_health.current_hearts, 1.75, 0.001)
	_health.heal(99.0)
	assert_almost_eq(_health.current_hearts, 3.0, 0.001, "healing clamps at max")


func test_lethal_damage_kills_exactly_once() -> void:
	watch_signals(_health)
	watch_signals(EventBus)
	_player.apply_damage(5.0, &"drowning")
	assert_almost_eq(_health.current_hearts, 0.0, 0.001)
	assert_true(_health.is_dead)
	_player.apply_damage(1.0, &"drowned")
	assert_signal_emit_count(_health, "died", 1, "a dead man dies once")
	assert_signal_emit_count(EventBus, "player_died", 1)


func test_four_pieces_make_a_container_and_refill() -> void:
	_player.apply_damage(2.0, &"heat")
	for i: int in 3:
		_health.add_heart_piece()
	assert_eq(_health.containers, 3, "three pieces are not yet a container")
	assert_eq(_health.pieces, 3)
	_health.add_heart_piece()
	assert_eq(_health.containers, 4, "the fourth piece completes a container")
	assert_eq(_health.pieces, 0)
	assert_almost_eq(_health.current_hearts, 4.0, 0.001, "a new container refills the hearts")


func test_eight_cairn_pieces_are_exactly_two_containers() -> void:
	for i: int in 8:
		_health.add_heart_piece()
	assert_eq(_health.containers, 5, "Nau leaves Lanka with 5 hearts (ARCHITECTURE §7)")
	assert_eq(_health.pieces, 0)


func test_cairn_completion_grants_one_piece_once() -> void:
	EventBus.cairn_completed.emit(&"cairn_shallows_1")
	assert_eq(_health.pieces, 1, "a Cairn yields one heart piece (ARCHITECTURE §13)")
	EventBus.cairn_completed.emit(&"cairn_shallows_1")
	assert_eq(_health.pieces, 1, "repeating a Cairn yields nothing")
	EventBus.cairn_completed.emit(&"cairn_terraces_1")
	assert_eq(_health.pieces, 2)


func test_fall_damage_threshold() -> void:
	assert_almost_eq(_player.fall_damage_hearts(_player.fall_damage_min_speed - 0.1), 0.0, 0.001,
			"below the threshold falls are free")
	assert_almost_eq(_player.fall_damage_hearts(_player.fall_damage_min_speed),
			_player.fall_damage_base, 0.001)
	assert_gt(_player.fall_damage_hearts(_player.fall_damage_min_speed + 4.0),
			_player.fall_damage_base, "harder landings cost more")


func test_hard_landing_hurts() -> void:
	_add_floor()
	_player.global_position = Vector3(0, 12, 0)
	await wait_physics_frames(120)
	assert_true(_player.is_on_floor(), "the drop is over")
	assert_lt(_health.current_hearts, 3.0, "a 12m drop is above the fall damage threshold")
