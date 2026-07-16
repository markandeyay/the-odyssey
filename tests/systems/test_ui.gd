extends GutTest
## M12 UI: heart fill math and geometry, breath meter color rules, the
## fragment pipeline (registry -> reader -> pickup), and the HUD wiring on
## the player scene. Look is the human's to judge; these pin the logic.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const FRAGMENT_PICKUP_SCENE: PackedScene = preload(
	"res://scenes/prefabs/gameplay/fragment_pickup.tscn"
)
const FIXTURES_DIR: String = "res://tests/systems/fixtures/fragments/"


func after_each() -> void:
	FragmentRegistry.reset()
	GameState.reset()


# --- hearts ---


func test_heart_fill_fraction() -> void:
	# 2.5 hearts: two full, one half, the rest empty.
	assert_eq(HeartsDisplay.fill_fraction(0, 2.5), 1.0)
	assert_eq(HeartsDisplay.fill_fraction(1, 2.5), 1.0)
	assert_eq(HeartsDisplay.fill_fraction(2, 2.5), 0.5)
	assert_eq(HeartsDisplay.fill_fraction(3, 2.5), 0.0)
	assert_eq(HeartsDisplay.fill_fraction(0, 0.0), 0.0)


func test_heart_points_fit_their_box() -> void:
	for size: float in [16.0, 26.0, 64.0]:
		var points: PackedVector2Array = HeartsDisplay.heart_points(size)
		assert_gt(points.size(), 8, "enough samples to read as a heart")
		for p: Vector2 in points:
			assert_between(p.x, 0.0, size, "x inside the box")
			assert_between(p.y, 0.0, size, "y inside the box")


func test_clip_left_of_halves_a_square() -> void:
	var square: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10),
	])
	var half: PackedVector2Array = HeartsDisplay.clip_left_of(square, 5.0)
	assert_almost_eq(_polygon_area(half), 50.0, 0.001, "half the square remains")
	var none: PackedVector2Array = HeartsDisplay.clip_left_of(square, -1.0)
	assert_lt(none.size(), 3, "cut left of the polygon leaves nothing drawable")
	var all: PackedVector2Array = HeartsDisplay.clip_left_of(square, 11.0)
	assert_almost_eq(_polygon_area(all), 100.0, 0.001, "cut right of the polygon keeps it whole")


func test_hearts_display_tracks_player_health() -> void:
	var player: Player = _make_player()
	var hearts: HeartsDisplay = player.get_node("HUD/GameHUD/Hearts") as HeartsDisplay
	assert_not_null(hearts)
	assert_eq(hearts._max, 3, "bound at ready: three containers (ARCHITECTURE §7)")
	assert_eq(hearts._current, 3.0)
	player.health.apply_damage(0.5, &"fall")
	assert_eq(hearts._current, 2.5, "damage reaches the display through the signal")


# --- breath ---


func test_breath_color_rules() -> void:
	assert_eq(BreathMeter.breath_color(1.0), UIPalette.SEA_GREEN, "full breath is sea green")
	assert_eq(BreathMeter.breath_color(0.5), UIPalette.SEA_GREEN, "safe breath stays sea green")
	assert_eq(BreathMeter.breath_color(0.0), UIPalette.EMBER_ORANGE, "empty breath is ember — danger")


func test_breath_meter_hidden_on_land() -> void:
	var player: Player = _make_player()
	var meter: BreathMeter = player.get_node("HUD/GameHUD/BreathMeter") as BreathMeter
	assert_not_null(meter)
	assert_false(meter.visible, "breath meter only exists underwater (M12)")


# --- heat resistance (diegetic) ---


func test_heat_wisps_burn_then_gutter() -> void:
	assert_false(Player.heat_wisps_lit(0.0), "no buff, no wisps")
	assert_true(Player.heat_wisps_lit(90.0), "steady while the buff holds")
	assert_true(Player.heat_wisps_lit(10.0), "steady at the gutter threshold")
	var states: Dictionary = {}
	for i: int in 20:
		states[Player.heat_wisps_lit(9.0 * float(i) / 20.0)] = true
	assert_true(states.has(true) and states.has(false), "the last seconds flicker on and off")


# --- fragments ---


func test_fragment_registry_loads_defs() -> void:
	FragmentRegistry.reset(FIXTURES_DIR)
	var def: FragmentDef = FragmentRegistry.get_def(&"frag_test_oarsman")
	assert_not_null(def, "fixture fragment loads by id")
	assert_eq(def.crew_name, "Test Oarsman")
	assert_eq(def.memento, "a worn oar grip")
	assert_null(FragmentRegistry.get_def(&"frag_nobody"), "unknown ids are null")


func test_fragment_reader_fallback_for_unauthored_content() -> void:
	var strings: Dictionary = FragmentReader.display_strings(null)
	assert_string_contains(strings["lines"], "waterlogged")
	var def: FragmentDef = FragmentDef.new()
	def.crew_name = "Adaro"
	def.memento = "a tin whistle"
	def.lines = "He sang the depth soundings."
	var authored: Dictionary = FragmentReader.display_strings(def)
	assert_eq(authored["name"], "Adaro")
	assert_eq(authored["memento"], "a tin whistle")


func test_fragment_reader_opens_on_event_and_closes() -> void:
	FragmentRegistry.reset(FIXTURES_DIR)
	var reader: FragmentReader = FragmentReader.new()
	add_child_autofree(reader)
	assert_false(reader.visible)
	EventBus.fragment_found.emit(&"frag_test_oarsman")
	assert_true(reader.visible, "the reader opens on fragment_found")
	assert_true(reader.is_in_group(&"modal_ui"), "camera holds still while reading")
	assert_false(get_tree().paused, "reading does not pause the game")
	reader.close()
	assert_false(reader.visible)
	assert_false(reader.is_in_group(&"modal_ui"))


func test_fragment_pickup_emits_and_gamestate_dedupes() -> void:
	var pickup: FragmentPickup = FRAGMENT_PICKUP_SCENE.instantiate()
	pickup.fragment_id = &"frag_test_oarsman"
	add_child_autofree(pickup)
	watch_signals(EventBus)
	var interactable: Interactable = pickup.get_node("Interactable") as Interactable
	interactable.interact(null)
	assert_signal_emitted_with_parameters(
		EventBus, "fragment_found", [&"frag_test_oarsman"]
	)
	assert_eq(GameState.fragment_count(), 1)
	interactable.interact(null)
	assert_eq(GameState.fragment_count(), 1, "re-reading never double-counts (ARCHITECTURE §12)")
	assert_not_null(pickup.get_parent(), "the remains stay in the world for re-reading")


# --- the anti-scope pins ---


func test_no_minimap_no_quest_log_no_compass() -> void:
	var player: Player = _make_player()
	var hud: GameHUD = player.get_node("HUD/GameHUD") as GameHUD
	for node: Node in hud.find_children("*", "", true, false):
		var lowered: String = node.name.to_lower()
		assert_false("minimap" in lowered, "no minimap (M12): %s" % node.name)
		assert_false("quest" in lowered, "no quest log (M12): %s" % node.name)
		assert_false("compass" in lowered, "the Spine is the compass (M12): %s" % node.name)


func _make_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	return player


static func _polygon_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	for i: int in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		area += a.x * b.y - b.x * a.y
	return absf(area) * 0.5
