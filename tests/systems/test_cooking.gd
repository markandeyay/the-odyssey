extends GutTest
## M10 cooking: the cook state machine and timing windows, the §7 food
## table (exactly four ingredients, raw weak / cooked strong), eating,
## the charwood heat-resistance buff (90s, never stacking), the campfire
## (cooks AND autosaves), blind fish needing real flame, and the
## brand/campfire fire exchange.

const CAMPFIRE_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/campfire.tscn")
const BRAND_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/brand.tscn")
const GRID_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/fire_grid.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")


func before_each() -> void:
	SaveSystem.save_path = "user://test_autosave_cooking.json"
	SaveSystem.delete_save()
	Inventory.clear()


func after_each() -> void:
	SaveSystem.delete_save()
	SaveSystem.save_path = "user://autosave.json"


func _make_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


func _make_campfire(flame: Campfire.FlameState = Campfire.FlameState.LIT) -> Campfire:
	var campfire: Campfire = CAMPFIRE_SCENE.instantiate()
	add_child_autofree(campfire)
	campfire.set_flame(flame)
	return campfire


func _interact(campfire: Campfire, player: Player) -> void:
	(campfire.get_node("Interactable") as Interactable).interact(player)


func test_cook_state_machine() -> void:
	var cooker: Cooker = autofree(Cooker.new())
	assert_eq(cooker.state(), Cooker.CookState.IDLE)
	cooker.start(&"ashroot")
	assert_eq(cooker.state(), Cooker.CookState.RAW)
	cooker.step(4.0)
	assert_eq(cooker.state(), Cooker.CookState.RAW)
	assert_eq(cooker.result_id(), &"ashroot", "taken off early, it comes back raw")
	cooker.step(4.5)
	assert_eq(cooker.state(), Cooker.CookState.COOKED)
	assert_eq(cooker.result_id(), &"ashroot_cooked")
	cooker.step(6.0)
	assert_eq(cooker.state(), Cooker.CookState.BURNT)
	assert_eq(cooker.result_id(), &"charcoal", "burnt is charcoal and is wasted")


func test_cook_window_edges() -> void:
	var cooker: Cooker = autofree(Cooker.new())
	cooker.start(&"tidepool_shellfish")
	cooker.step(cooker.cook_time)
	assert_eq(cooker.state(), Cooker.CookState.COOKED, "done exactly at cook_time")
	cooker.step(cooker.cook_window)
	assert_eq(cooker.state(), Cooker.CookState.BURNT, "the window closes exactly at cook_window")


func test_food_table_matches_architecture() -> void:
	var table: Dictionary = {
		&"tidepool_shellfish": [0.5, &"tidepool_shellfish_cooked", 2.0],
		&"ashroot": [0.25, &"ashroot_cooked", 1.5],
		&"charwood_fruit": [0.5, &"charwood_fruit_cooked", 1.0],
		&"blind_fish": [0.5, &"blind_fish_cooked", 2.0],
	}
	for raw_id: StringName in table:
		var raw: FoodDef = ItemRegistry.get_def(raw_id) as FoodDef
		var cooked: FoodDef = ItemRegistry.get_def(table[raw_id][1]) as FoodDef
		assert_not_null(raw, "%s exists" % raw_id)
		assert_not_null(cooked, "%s cooks into something" % raw_id)
		assert_almost_eq(raw.heal_hearts, float(table[raw_id][0]), 0.001)
		assert_almost_eq(cooked.heal_hearts, float(table[raw_id][2]), 0.001)
		assert_eq(raw.grants_heat_resistance, 0.0, "no raw buffs")
		assert_lt(raw.heal_hearts, cooked.heal_hearts, "raw is weak, cooked is strong")
	assert_true((ItemRegistry.get_def(&"blind_fish") as FoodDef).requires_real_flame)
	assert_almost_eq(
		(ItemRegistry.get_def(&"charwood_fruit_cooked") as FoodDef).grants_heat_resistance,
		90.0, 0.001, "heat resistance, 90s — the only non-heal effect on Lanka"
	)


func test_eating_heals_and_consumes() -> void:
	var player: Player = _make_player()
	player.apply_damage(2.5, &"fall")
	Inventory.add_item(&"ashroot_cooked", 2)
	assert_true(player.try_eat_selected())
	assert_almost_eq(player.health.current_hearts, 2.0, 0.001, "baked ashroot heals 1.5")
	assert_eq(Inventory.count_of(&"ashroot_cooked"), 1, "eating consumes one")


func test_eating_junk_fails() -> void:
	var player: Player = _make_player()
	assert_false(player.try_eat_selected(), "empty hand: nothing to eat")
	Inventory.add_item(&"timber", 1)
	assert_false(player.try_eat_selected(), "salvage is not food")
	Inventory.clear()
	Inventory.add_item(&"charcoal", 1)
	assert_false(player.try_eat_selected(), "charcoal is wasted, not eaten")
	assert_eq(Inventory.count_of(&"charcoal"), 1)


func test_charwood_buff_90s_and_never_stacks() -> void:
	var player: Player = _make_player()
	Inventory.add_item(&"charwood_fruit_cooked", 2)
	assert_true(player.try_eat_selected())
	assert_true(player.is_heat_resistant())
	assert_almost_eq(player.heat_resistance_left(), 90.0, 0.5, "buff duration is 90s (§7)")
	assert_true(player.try_eat_selected())
	assert_almost_eq(player.heat_resistance_left(), 90.0, 0.5, "no buff stacking (§7)")
	Inventory.clear()
	Inventory.add_item(&"charwood_fruit", 1)
	var fresh: Player = _make_player()
	assert_true(fresh.try_eat_selected())
	assert_false(fresh.is_heat_resistant(), "raw charwood does not grant resistance")


func test_campfire_cooks_selected_raw_food() -> void:
	var player: Player = _make_player()
	var campfire: Campfire = _make_campfire()
	Inventory.add_item(&"tidepool_shellfish", 1)
	_interact(campfire, player)
	assert_eq(Inventory.count_of(&"tidepool_shellfish"), 0, "the thing went on the fire")
	assert_true(campfire.cooker.active)
	campfire.cooker.step(8.5)
	assert_eq(campfire.cooker.state(), Cooker.CookState.COOKED)
	_interact(campfire, player)
	assert_eq(Inventory.count_of(&"tidepool_shellfish_cooked"), 1, "and came off cooked")
	assert_false(campfire.cooker.active)


func test_campfire_overcooks_to_charcoal() -> void:
	var player: Player = _make_player()
	var campfire: Campfire = _make_campfire()
	Inventory.add_item(&"ashroot", 1)
	_interact(campfire, player)
	campfire.cooker.step(30.0)
	_interact(campfire, player)
	assert_eq(Inventory.count_of(&"charcoal"), 1, "left too long: charcoal")
	assert_eq(Inventory.count_of(&"ashroot_cooked"), 0)


func test_blind_fish_needs_real_flame() -> void:
	var player: Player = _make_player()
	var campfire: Campfire = _make_campfire(Campfire.FlameState.EMBERS)
	Inventory.add_item(&"blind_fish", 1)
	_interact(campfire, player)
	assert_eq(Inventory.count_of(&"blind_fish"), 1, "embers refuse blind fish (§7)")
	assert_false(campfire.cooker.active)
	Inventory.add_item(&"tidepool_shellfish", 1)
	Inventory.select_hotbar(1)
	_interact(campfire, player)
	assert_true(campfire.cooker.active, "embers cook everything else")


func test_unlit_campfire_cooks_nothing() -> void:
	var player: Player = _make_player()
	var campfire: Campfire = _make_campfire(Campfire.FlameState.UNLIT)
	Inventory.add_item(&"ashroot", 1)
	_interact(campfire, player)
	assert_false(campfire.cooker.active)
	assert_eq(Inventory.count_of(&"ashroot"), 1)


func test_campfire_use_autosaves() -> void:
	var player: Player = _make_player()
	var campfire: Campfire = _make_campfire()
	watch_signals(EventBus)
	_interact(campfire, player)
	assert_signal_emitted_with_parameters(EventBus, "autosave_requested", [&"campfire"])
	assert_true(SaveSystem.has_save(), "cooks AND autosaves; same object, two jobs")


func test_brand_and_campfire_exchange_fire() -> void:
	add_child_autofree(GRID_SCENE.instantiate())
	var player: Player = _make_player()
	var carry: CarryController = player.get_node("CarryController") as CarryController
	var brand: Brand = BRAND_SCENE.instantiate()
	add_child_autofree(brand)
	await get_tree().process_frame
	assert_true(carry.pick_up(brand))
	var lit_fire: Campfire = _make_campfire(Campfire.FlameState.LIT)
	_interact(lit_fire, player)
	assert_true(brand.is_lit(), "a lit campfire lights a carried brand")
	var cold_fire: Campfire = _make_campfire(Campfire.FlameState.UNLIT)
	_interact(cold_fire, player)
	assert_true(cold_fire.is_real_flame(), "a lit brand lights a cold campfire")


func test_eat_via_interact_key_with_no_target() -> void:
	var player: Player = _make_player()
	player.global_position = Vector3(500, 0, 500)  # nothing around to target
	player.apply_damage(2.0, &"fall")
	Inventory.add_item(&"tidepool_shellfish_cooked", 1)
	await wait_physics_frames(2)
	Input.action_press(&"interact")
	await wait_physics_frames(2)
	Input.action_release(&"interact")
	await wait_physics_frames(2)
	assert_eq(Inventory.count_of(&"tidepool_shellfish_cooked"), 0, "interact with food selected eats it")
	assert_almost_eq(player.health.current_hearts, 3.0, 0.001, "and it healed")
