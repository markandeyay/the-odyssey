extends GutTest
## Keffer (M15): sequential looping dialogue, a food handout on a
## cooldown, and the hard rule — he never says Nau's name. The
## Figurehead spends it once at the very end (M14) and nothing else on
## the island may.

const KEFFER_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/keffer_interaction.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _player: Player
var _keffer: KefferInteraction


func before_each() -> void:
	GameState.reset()
	Inventory.clear()
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector3(60, 0.1, 0)
	add_child_autofree(_player)
	_keffer = KEFFER_SCENE.instantiate()
	add_child_autofree(_keffer)


func after_all() -> void:
	GameState.reset()
	Inventory.clear()


func _talk() -> void:
	(_keffer.get_node(^"Interactable") as Interactable).interact(_player)


func test_keffer_never_says_naus_name() -> void:
	assert_gt(_keffer.dialogue_lines.size(), 0, "Keffer has something to mutter")
	for line: String in _keffer.dialogue_lines:
		assert_false(
			"nau" in line.to_lower(),
			"HARD RULE (M14/M15): only the Figurehead says the name — not: %s" % line
		)


func test_lines_are_sequential_and_wrap() -> void:
	var seen: Array[String] = []
	for i: int in _keffer.dialogue_lines.size():
		seen.append(_keffer.next_line())
	assert_eq(seen, _keffer.dialogue_lines, "lines come in authored order")
	assert_eq(
		_keffer.next_line(), _keffer.dialogue_lines[0],
		"the loop wraps; he keeps muttering"
	)


func test_talking_shows_a_line_and_sets_the_flag() -> void:
	var box: DialogueBox = _player.get_node(^"HUD/GameHUD/DialogueBox") as DialogueBox
	assert_not_null(box, "the HUD ships the dialogue box")
	_talk()
	assert_true(GameState.get_flag(&"met_keffer"), "meeting him is recorded")
	assert_true(box.visible, "the dialogue box opens")
	assert_true(box.is_in_group(&"modal_ui"), "the camera holds while he talks")


func test_handout_respects_cooldown() -> void:
	_keffer.handout_cooldown_s = 3600.0
	_talk()
	assert_eq(
		Inventory.count_of(_keffer.handout_item_id), 1,
		"the first talk comes with food"
	)
	_talk()
	assert_eq(
		Inventory.count_of(_keffer.handout_item_id), 1,
		"talking again inside the cooldown does not"
	)


func test_zero_cooldown_hands_out_every_talk() -> void:
	_keffer.handout_cooldown_s = 0.0
	_talk()
	_talk()
	assert_eq(Inventory.count_of(_keffer.handout_item_id), 2, "cooldown elapsed, he gives again")


func test_no_handout_item_means_no_handout() -> void:
	_keffer.handout_item_id = &""
	_talk()
	for stack: ItemStack in Inventory.hotbar:
		assert_null(stack, "nothing appears from an empty handout id")
