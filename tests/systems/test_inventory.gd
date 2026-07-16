extends GutTest
## M5 inventory: stacking, splitting, overflow, hotbar/storage transfer,
## key items outside the 40, selection, and the data-driven registry.


func before_each() -> void:
	Inventory.clear()


func test_registry_loads_item_defs() -> void:
	assert_not_null(ItemRegistry.get_def(&"timber"), "timber def loads")
	assert_not_null(ItemRegistry.get_def(&"tidepool_shellfish"), "shellfish def loads")
	assert_eq(ItemRegistry.get_def(&"timber").category, ItemDef.Category.SALVAGE)
	assert_eq(ItemRegistry.get_def(&"charwood_fruit").category, ItemDef.Category.FOOD)
	assert_eq(ItemRegistry.get_def(&"figurehead").category, ItemDef.Category.KEY)
	assert_eq(ItemRegistry.get_def(&"figurehead").stack_max, 1, "key items never stack")


func test_exactly_three_salvage_and_four_foods() -> void:
	var salvage: int = 0
	var food: int = 0
	for def: ItemDef in ItemRegistry.all_defs():
		if def.category == ItemDef.Category.SALVAGE:
			salvage += 1
		elif def.category == ItemDef.Category.FOOD:
			food += 1
	assert_eq(salvage, 3, "timber, iron, canvas — no more (ARCHITECTURE §9)")
	assert_eq(food, 4, "exactly four ingredients (ARCHITECTURE §7)")


func test_stacking_caps_at_twenty() -> void:
	assert_eq(Inventory.add_item(&"timber", 25), 0)
	assert_eq(Inventory.hotbar[0].count, 20, "first stack tops out")
	assert_eq(Inventory.hotbar[1].count, 5, "remainder starts a new stack")


func test_overflow_returns_leftover() -> void:
	assert_eq(Inventory.add_item(&"timber", 800), 0, "40 slots x 20 fill exactly")
	assert_eq(Inventory.add_item(&"timber", 7), 7, "full inventory returns the leftover")


func test_remove_item_spans_stacks() -> void:
	Inventory.add_item(&"timber", 25)
	assert_eq(Inventory.remove_item(&"timber", 22), 22)
	assert_eq(Inventory.count_of(&"timber"), 3)
	assert_null(Inventory.hotbar[0], "emptied slots become null")


func test_transfer_moves_into_empty_slot() -> void:
	Inventory.add_item(&"timber", 20)
	assert_true(Inventory.transfer(Inventory.Area.HOTBAR, 0, Inventory.Area.STORAGE, 4))
	assert_null(Inventory.hotbar[0])
	assert_eq(Inventory.storage[4].count, 20)


func test_transfer_merges_partially() -> void:
	Inventory.storage[0] = ItemStack.new(&"timber", 15)
	Inventory.hotbar[0] = ItemStack.new(&"timber", 10)
	assert_true(Inventory.transfer(Inventory.Area.HOTBAR, 0, Inventory.Area.STORAGE, 0))
	assert_eq(Inventory.storage[0].count, 20, "merge fills to cap")
	assert_eq(Inventory.hotbar[0].count, 5, "remainder stays behind")


func test_transfer_swaps_different_ids() -> void:
	Inventory.add_item(&"timber", 5)
	Inventory.add_item(&"iron", 8)
	assert_true(Inventory.transfer(Inventory.Area.HOTBAR, 0, Inventory.Area.HOTBAR, 1))
	assert_eq(Inventory.hotbar[0].id, &"iron")
	assert_eq(Inventory.hotbar[1].id, &"timber")


func test_split_stack() -> void:
	Inventory.add_item(&"timber", 20)
	assert_true(Inventory.split_stack(Inventory.Area.HOTBAR, 0, 10, Inventory.Area.STORAGE, 3))
	assert_eq(Inventory.hotbar[0].count, 10)
	assert_eq(Inventory.storage[3].count, 10)
	assert_false(
		Inventory.split_stack(Inventory.Area.HOTBAR, 0, 10, Inventory.Area.STORAGE, 5),
		"a full move is not a split"
	)
	assert_true(Inventory.split_stack(Inventory.Area.HOTBAR, 0, 5, Inventory.Area.STORAGE, 3))
	assert_eq(Inventory.storage[3].count, 15, "split can merge onto same id")
	assert_eq(Inventory.hotbar[0].count, 5)


func test_key_items_live_outside_the_forty() -> void:
	assert_eq(Inventory.add_item(&"figurehead"), 0, "KEY items route to the reserved area")
	assert_true(Inventory.has_key_item(&"figurehead"))
	assert_eq(Inventory.count_of(&"figurehead"), 0, "not in the 40 slots")
	assert_null(Inventory.hotbar[0])
	Inventory.add_key_item(&"figurehead")
	assert_eq(Inventory.key_items.size(), 1, "uniques never duplicate")


func test_hotbar_selection_wraps() -> void:
	watch_signals(Inventory)
	Inventory.select_hotbar(9)
	assert_eq(Inventory.selected_hotbar_index, 9)
	assert_signal_emitted_with_parameters(Inventory, "selection_changed", [9])
	Inventory.select_next()
	assert_eq(Inventory.selected_hotbar_index, 0, "next wraps 9 to 0")
	Inventory.select_prev()
	assert_eq(Inventory.selected_hotbar_index, 9, "prev wraps 0 to 9")


func test_quick_transfer_round_trip() -> void:
	Inventory.add_item(&"timber", 20)
	assert_true(Inventory.quick_transfer(Inventory.Area.HOTBAR, 0))
	assert_null(Inventory.hotbar[0])
	assert_eq(Inventory.storage[0].count, 20)
	assert_true(Inventory.quick_transfer(Inventory.Area.STORAGE, 0))
	assert_eq(Inventory.hotbar[0].count, 20)


func test_save_data_round_trip() -> void:
	Inventory.add_item(&"timber", 25)
	Inventory.add_item(&"iron", 3)
	Inventory.add_key_item(&"hull")
	Inventory.select_hotbar(3)
	var data: Dictionary = Inventory.get_save_data()
	Inventory.clear()
	assert_eq(Inventory.count_of(&"timber"), 0)
	Inventory.apply_save_data(data)
	assert_eq(Inventory.count_of(&"timber"), 25)
	assert_eq(Inventory.count_of(&"iron"), 3)
	assert_true(Inventory.has_key_item(&"hull"))
	assert_eq(Inventory.selected_hotbar_index, 3)


func test_hotbar_ui_builds_ten_slots() -> void:
	var ui: HotbarUI = (preload("res://scenes/ui/hotbar.tscn") as PackedScene).instantiate()
	add_child_autofree(ui)
	assert_eq(ui.get_child_count(), 10)


func test_storage_panel_toggles_without_pausing() -> void:
	var panel: StoragePanel = (preload("res://scenes/ui/storage_panel.tscn") as PackedScene).instantiate()
	add_child_autofree(panel)
	assert_false(panel.visible)
	panel.toggle()
	assert_true(panel.visible)
	assert_true(panel.is_in_group(&"modal_ui"))
	assert_false(get_tree().paused, "storage is not a pause menu")
	panel.toggle()
	assert_false(panel.visible)
	assert_false(panel.is_in_group(&"modal_ui"))
