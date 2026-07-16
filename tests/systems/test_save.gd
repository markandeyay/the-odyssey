extends GutTest
## M6 save: full round-trip through the one autosave slot, the reserved
## element unlock table (M9), autosave triggers (trial, Cairn, first
## district entry — campfires arrive in M10), and death as a hard reset
## to the last autosave. Nothing lost, nothing dropped.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")


func before_each() -> void:
	SaveSystem.save_path = "user://test_autosave_save.json"
	SaveSystem.delete_save()
	GameState.reset()
	Inventory.clear()


func after_each() -> void:
	SaveSystem.delete_save()
	SaveSystem.save_path = "user://autosave.json"


func _add_player(at: Vector3) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = at
	return player


func _add_floor() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -0.5, 0)
	add_child_autofree(body)


func test_load_without_save_returns_false() -> void:
	assert_false(SaveSystem.has_save())
	assert_false(SaveSystem.load_game())


func test_full_round_trip() -> void:
	var player: Player = _add_player(Vector3(3, 1, -2))
	EventBus.district_entered.emit(&"the_shallows")
	GameState.set_flag(&"met_keffer")
	EventBus.fragment_found.emit(&"frag_helmsman")
	EventBus.cairn_completed.emit(&"cairn_shallows_1")
	EventBus.component_acquired.emit(&"hull")
	EventBus.trial_completed.emit(&"the_hold")
	Inventory.add_item(&"timber", 12)
	Inventory.add_item(&"figurehead")
	player.apply_damage(1.25, &"fire")
	SaveSystem.save_game(&"test")

	# Wreck everything the save is supposed to restore.
	GameState.reset()
	Inventory.clear()
	player.global_position = Vector3.ZERO
	player.health.apply_save_data({})

	assert_true(SaveSystem.load_game())
	assert_eq(GameState.current_district, &"the_shallows")
	assert_true(GameState.get_flag(&"met_keffer"))
	assert_eq(GameState.fragment_count(), 1, "fragment count survives (ARCHITECTURE §12)")
	assert_true(GameState.cairns_completed.has(&"cairn_shallows_1"), "Cairn completion survives")
	assert_true(GameState.components_acquired.has(&"hull"), "component acquisition survives")
	assert_true(GameState.trials_completed.has(&"the_hold"))
	assert_true(GameState.visited_districts.has(&"the_shallows"))
	assert_eq(Inventory.count_of(&"timber"), 12)
	assert_true(Inventory.has_key_item(&"figurehead"))
	assert_almost_eq(player.global_position.x, 3.0, 0.001)
	assert_almost_eq(player.global_position.y, 1.0, 0.001)
	assert_almost_eq(player.global_position.z, -2.0, 0.001)
	assert_eq(player.health.containers, 3)
	assert_eq(player.health.pieces, 1, "the Cairn's heart piece survives")
	assert_almost_eq(player.health.current_hearts, 1.75, 0.001)


func test_save_file_reserves_element_table() -> void:
	SaveSystem.save_game(&"test")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveSystem.save_path))
	assert_true(parsed is Dictionary)
	var data: Dictionary = parsed as Dictionary
	assert_eq(int(data.get("version", 0)), SaveSystem.SAVE_VERSION)
	assert_true(data.has("elements"), "element unlock table reserved from day one (M9)")
	assert_true(data.has("game_state"))
	assert_true(data.has("inventory"))


func test_autosave_on_trial_and_cairn_completion() -> void:
	watch_signals(EventBus)
	EventBus.trial_completed.emit(&"the_hold")
	assert_signal_emitted_with_parameters(EventBus, "autosave_requested", [&"trial_completed"])
	assert_true(SaveSystem.has_save(), "trial completion autosaves")
	SaveSystem.delete_save()
	EventBus.cairn_completed.emit(&"cairn_terraces_2")
	assert_true(SaveSystem.has_save(), "Cairn completion autosaves")


func test_autosave_on_first_district_entry_only() -> void:
	watch_signals(EventBus)
	EventBus.district_entered.emit(&"the_terraces")
	assert_signal_emit_count(EventBus, "autosave_requested", 1, "first entry autosaves")
	EventBus.district_entered.emit(&"the_terraces")
	assert_signal_emit_count(EventBus, "autosave_requested", 1, "re-entry does not")
	EventBus.district_entered.emit(&"the_cistern")
	assert_signal_emit_count(EventBus, "autosave_requested", 2, "a new district does")


func test_death_hard_resets_to_last_autosave() -> void:
	_add_floor()
	var player: Player = _add_player(Vector3(2, 0, 5))
	Inventory.add_item(&"timber", 5)
	SaveSystem.save_game(&"campfire")

	player.global_position = Vector3(15, 3, 15)
	Inventory.remove_item(&"timber", 5)
	player.apply_damage(99.0, &"drowning")
	assert_true(player.health.is_dead, "lethal damage kills")

	await wait_physics_frames(3)
	assert_false(player.health.is_dead, "death is a hard reset, not an end")
	assert_almost_eq(player.health.current_hearts, 3.0, 0.001, "hearts restored")
	assert_almost_eq(player.global_position.x, 2.0, 0.1, "back at the last autosave")
	assert_almost_eq(player.global_position.z, 5.0, 0.1)
	assert_eq(Inventory.count_of(&"timber"), 5, "nothing lost, nothing dropped")


func test_death_without_save_refills_in_place() -> void:
	var player: Player = _add_player(Vector3(1, 2, 3))
	player.apply_damage(99.0, &"fall")
	assert_true(player.health.is_dead)
	await wait_physics_frames(3)
	assert_false(player.health.is_dead)
	assert_almost_eq(player.health.current_hearts, 3.0, 0.001,
			"no autosave yet: Nau gets back up where he stands")
