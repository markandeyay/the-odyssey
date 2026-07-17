extends GutTest
## M14 Setu and the stub ending: five component slots, visible mounting,
## salvage stores that display and do nothing (ARCHITECTURE §9), the
## Figurehead carried home and mounted at the boat (M14 rework), and Vela
## speaking exactly once before TO BE CONTINUED (§0/§4).

const SETU_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/setu.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/component_pickup.tscn")
const FIGUREHEAD_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/figurehead_carryable.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")


func before_each() -> void:
	GameState.reset()
	Inventory.clear()


func after_all() -> void:
	GameState.reset()
	Inventory.clear()
	get_tree().paused = false


func _make_setu() -> Setu:
	var setu: Setu = SETU_SCENE.instantiate()
	add_child_autofree(setu)
	return setu


func _make_pickup(component_id: StringName) -> ComponentPickup:
	var pickup: ComponentPickup = PICKUP_SCENE.instantiate()
	pickup.component_id = component_id
	add_child_autofree(pickup)
	return pickup


func _make_ending() -> EndingSequence:
	var ending: EndingSequence = EndingSequence.new()
	ending.beat_delay = 0.02
	ending.line_hold = 0.02
	ending.fade_duration = 0.02
	ending.pause_on_card = false
	add_child_autofree(ending)
	return ending


func _acquire_all_but_figurehead() -> void:
	for id: StringName in [&"hull", &"mast", &"sail", &"keel"]:
		EventBus.component_acquired.emit(id)


func _make_player_carrying_figurehead() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var figurehead: FigureheadCarryable = FIGUREHEAD_SCENE.instantiate()
	figurehead.position = Vector3(0, 0.6, -1.2)
	add_child_autofree(figurehead)
	var carry: CarryController = player.get_node("CarryController") as CarryController
	assert_true(carry.pick_up(figurehead), "precondition: the Figurehead is carryable")
	return player


func test_component_acquisition_records_and_files_the_key_item() -> void:
	EventBus.component_acquired.emit(&"hull")
	assert_true(GameState.components_acquired.has(&"hull"), "GameState records it")
	assert_true(Inventory.has_key_item(&"hull"), "the key item area stays in sync")
	assert_eq(Inventory.count_of(&"hull"), 0, "never in the 40 slots")


func test_component_pickup_acquires_and_removes_itself() -> void:
	var pickup: ComponentPickup = _make_pickup(&"keel")
	await wait_physics_frames(1)
	var interactable: Interactable = pickup.get_node("Interactable") as Interactable
	assert_eq(interactable.prompt, "Take the Keel", "prompt names the component")
	interactable.interact(null)
	assert_true(GameState.components_acquired.has(&"keel"))
	assert_true(pickup.is_queued_for_deletion(), "taken once, gone forever")


func test_already_acquired_pickup_removes_itself_on_ready() -> void:
	EventBus.component_acquired.emit(&"mast")
	var pickup: ComponentPickup = _make_pickup(&"mast")
	await wait_physics_frames(2)
	assert_false(is_instance_valid(pickup), "a loaded save never shows a duplicate")


func test_setu_has_exactly_five_component_slots() -> void:
	assert_eq(Setu.COMPONENT_IDS.size(), 5, "five components, no more (ARCHITECTURE §4)")
	var setu: Setu = _make_setu()
	await wait_physics_frames(1)
	for id: StringName in Setu.COMPONENT_IDS:
		var mount: Node3D = setu.get_node_or_null("Mounts/%s" % String(id).capitalize()) as Node3D
		assert_not_null(mount, "mount exists for %s" % id)
		assert_false(mount.visible, "nothing is mounted on a fresh boat")


func test_components_mount_visibly_as_acquired() -> void:
	var setu: Setu = _make_setu()
	await wait_physics_frames(1)
	EventBus.component_acquired.emit(&"hull")
	assert_true(setu.is_mounted(&"hull"), "the hull mounts the moment it is acquired")
	assert_false(setu.is_mounted(&"mast"), "the rest of the boat is still missing")


func test_mounts_restore_from_game_state_on_ready() -> void:
	EventBus.component_acquired.emit(&"hull")
	EventBus.component_acquired.emit(&"sail")
	var setu: Setu = _make_setu()
	await wait_physics_frames(1)
	assert_true(setu.is_mounted(&"hull"), "a loaded save renders the same boat")
	assert_true(setu.is_mounted(&"sail"))
	assert_false(setu.is_mounted(&"keel"))


func test_stowing_salvage_moves_it_from_inventory_to_the_boat() -> void:
	Inventory.add_item(&"timber", 25)
	Inventory.add_item(&"iron", 3)
	var setu: Setu = _make_setu()
	await wait_physics_frames(1)
	var interactable: Interactable = setu.get_node("Interactable") as Interactable
	assert_eq(interactable.prompt, "Stow salvage", "the boat offers to take the salvage")
	interactable.interact(null)
	assert_eq(Inventory.count_of(&"timber"), 0, "timber left the inventory")
	assert_eq(Inventory.count_of(&"iron"), 0, "iron left the inventory")
	assert_eq(GameState.setu_salvage_count(&"timber"), 25, "timber is stored on Setu")
	assert_eq(GameState.setu_salvage_count(&"iron"), 3)
	assert_eq(GameState.setu_salvage_count(&"canvas"), 0)
	var tally: Label3D = setu.get_node("SalvageTally") as Label3D
	assert_string_contains(tally.text, "timber  25", "the counter displays")
	assert_eq(interactable.prompt, "Setu", "nothing left to stow")


func test_salvage_stores_survive_a_save_round_trip() -> void:
	GameState.add_setu_salvage(&"canvas", 7)
	GameState.add_setu_salvage(&"timber", 12)
	var data: Dictionary = GameState.get_save_data()
	GameState.reset()
	assert_eq(GameState.setu_salvage_count(&"canvas"), 0, "precondition: reset cleared it")
	GameState.apply_save_data(data)
	assert_eq(GameState.setu_salvage_count(&"canvas"), 7)
	assert_eq(GameState.setu_salvage_count(&"timber"), 12)


func test_figurehead_is_a_carryable_not_a_pickup() -> void:
	var pickup: ComponentPickup = _make_pickup(&"figurehead")
	await wait_physics_frames(2)
	assert_false(is_instance_valid(pickup),
			"a figurehead component pickup refuses to exist (M14 rework)")
	assert_false(GameState.components_acquired.has(&"figurehead"))


func test_carried_figurehead_mounts_at_the_boat() -> void:
	var setu: Setu = _make_setu()
	var player: Player = _make_player_carrying_figurehead()
	await wait_physics_frames(1)
	var interactable: Interactable = setu.get_node("Interactable") as Interactable
	assert_true(interactable.usable_while_carrying,
			"the boat accepts interaction with full hands")
	assert_eq(interactable.prompt, "Mount the Figurehead",
			"the boat offers to take its Figurehead")
	interactable.interact(player)
	assert_true(GameState.components_acquired.has(&"figurehead"),
			"mounting acquires the component")
	assert_true(setu.is_mounted(&"figurehead"), "the Figurehead is on the boat")
	assert_false(player.is_carrying, "Nau's hands are empty again")


func test_interacting_without_the_figurehead_still_stows_salvage() -> void:
	Inventory.add_item(&"timber", 4)
	var setu: Setu = _make_setu()
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	await wait_physics_frames(1)
	var interactable: Interactable = setu.get_node("Interactable") as Interactable
	interactable.interact(player)
	assert_eq(GameState.setu_salvage_count(&"timber"), 4, "salvage stows as before")
	assert_false(GameState.components_acquired.has(&"figurehead"))


func test_acquired_figurehead_carryable_removes_itself_on_ready() -> void:
	EventBus.component_acquired.emit(&"figurehead")
	var figurehead: FigureheadCarryable = FIGUREHEAD_SCENE.instantiate()
	add_child_autofree(figurehead)
	await wait_physics_frames(2)
	assert_false(is_instance_valid(figurehead), "a loaded save never shows a duplicate")


func test_no_ending_before_the_fifth_component() -> void:
	var ending: EndingSequence = _make_ending()
	_acquire_all_but_figurehead()
	assert_false(ending.playing, "four components is not a boat")
	assert_eq(ending.times_played, 0)


func test_fifth_component_plays_the_ending() -> void:
	var ending: EndingSequence = _make_ending()
	_acquire_all_but_figurehead()
	EventBus.component_acquired.emit(&"figurehead")
	assert_true(ending.playing, "the Figurehead ends the build")
	assert_true(GameState.get_flag(EndingSequence.ENDING_FLAG),
			"the flag is set immediately so the trial autosave records it")
	await get_tree().create_timer(0.4).timeout
	assert_true(ending.get_child(2).visible, "TO BE CONTINUED is on screen")


func test_the_figurehead_speaks_exactly_once() -> void:
	var ending: EndingSequence = _make_ending()
	_acquire_all_but_figurehead()
	EventBus.component_acquired.emit(&"figurehead")
	await get_tree().create_timer(0.4).timeout
	EventBus.component_acquired.emit(&"figurehead")
	await get_tree().create_timer(0.2).timeout
	assert_eq(ending.times_played, 1, "she speaks exactly once (ARCHITECTURE §4)")


func test_ending_does_not_replay_on_a_loaded_save() -> void:
	GameState.set_flag(EndingSequence.ENDING_FLAG)
	var ending: EndingSequence = _make_ending()
	_acquire_all_but_figurehead()
	EventBus.component_acquired.emit(&"figurehead")
	assert_eq(ending.times_played, 0, "a save made after she spoke stays silent")


func test_the_real_ending_freezes_the_game() -> void:
	var ending: EndingSequence = EndingSequence.new()
	assert_true(ending.pause_on_card, "the final card is terminal by default")
	ending.free()
