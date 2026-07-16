extends GutTest
## M1 smoke test: the foundation contract from ARCHITECTURE §19.
## Autoloads registered, EventBus vocabulary exact, physics layers named,
## input actions present, ElementSystem inert.

const AUTOLOADS: Array[String] = [
	"EventBus", "GameState", "SaveSystem", "Inventory", "ElementSystem", "AudioDirector",
]

const EVENT_BUS_SIGNALS: Array[String] = [
	"district_entered", "trial_completed", "component_acquired", "cairn_completed",
	"fragment_found", "autosave_requested", "player_died", "fire_started",
	"fire_extinguished", "sound_emitted",
]

const LAYER_NAMES: Array[String] = [
	"world", "player", "climbable", "carryable", "interactable", "water",
	"fire", "heat", "drowned", "sound", "flammable", "updraft",
]

const ACTIONS: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right",
	"look_up", "look_down", "look_left", "look_right",
	"jump", "crouch", "sprint", "interact", "drop", "open_storage", "glide",
	"hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4", "hotbar_5",
	"hotbar_6", "hotbar_7", "hotbar_8", "hotbar_9", "hotbar_10",
	"hotbar_prev", "hotbar_next",
]


func test_autoloads_registered() -> void:
	for autoload_name: String in AUTOLOADS:
		assert_not_null(
			get_tree().root.get_node_or_null(autoload_name),
			"autoload %s should be registered" % autoload_name
		)


func test_event_bus_signals_exact() -> void:
	for signal_name: String in EVENT_BUS_SIGNALS:
		assert_true(EventBus.has_signal(signal_name), "EventBus should declare %s" % signal_name)


func test_physics_layer_names() -> void:
	for i: int in LAYER_NAMES.size():
		var setting: String = "layer_names/3d_physics/layer_%d" % (i + 1)
		assert_eq(
			str(ProjectSettings.get_setting(setting, "")), LAYER_NAMES[i],
			"%s should be named %s" % [setting, LAYER_NAMES[i]]
		)


func test_input_actions_exist() -> void:
	for action: String in ACTIONS:
		assert_true(InputMap.has_action(action), "input action %s should exist" % action)


func test_element_system_inert_on_lanka() -> void:
	assert_false(ElementSystem.has_element(&"fire"), "no element is ever unlocked on Lanka")
	assert_eq(ElementSystem.get_unlocked().size(), 0, "unlock registry starts empty")


func test_inventory_shape() -> void:
	assert_eq(Inventory.hotbar.size(), 10, "hotbar is 10 slots")
	assert_eq(Inventory.storage.size(), 30, "storage is 30 slots")
	assert_eq(Inventory.STACK_MAX, 20, "stacks cap at 20")
