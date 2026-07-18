extends GutTest
## ARCHITECTURE section 21 integration gate. This test deliberately uses the
## production Lanka scene and its real Nau streaming target. No fixture world,
## mock prefab, or synthetic target is permitted here.

const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")

const LANKA_PATH: String = "res://scenes/levels/lanka/lanka.tscn"
const PLAYER_PATH: NodePath = ^"DistrictAnchors/Shallows/Player"
const FLAMMABLE_SCRIPT_PATH: String = "res://src/world/fire/flammable.gd"
const PREFABS: Dictionary = {
	"campfire": "res://scenes/prefabs/gameplay/campfire.tscn",
	"cairn": "res://scenes/prefabs/gameplay/cairn_entrance.tscn",
	"component": "res://scenes/prefabs/gameplay/component_pickup.tscn",
	"district_trigger": "res://scenes/prefabs/gameplay/district_trigger.tscn",
	"drowned": "res://scenes/prefabs/gameplay/drowned.tscn",
	"figurehead": "res://scenes/prefabs/gameplay/figurehead_carryable.tscn",
	"fire_grid": "res://scenes/prefabs/gameplay/fire_grid.tscn",
	"fragment": "res://scenes/prefabs/gameplay/fragment_pickup.tscn",
	"heat": "res://scenes/prefabs/gameplay/heat_volume.tscn",
	"ocean_kill": "res://scenes/prefabs/gameplay/kill_volume.tscn",
	"setu": "res://scenes/prefabs/gameplay/setu.tscn",
	"water": "res://scenes/prefabs/gameplay/water_volume.tscn",
}
const EXPECTED: Dictionary = {
	&"shallows": {"campfire": 2, "cairn": 2, "component": 1,
		"district_trigger": 1, "fragment": 4, "ocean_kill": 1, "setu": 1},
	&"terraces": {"campfire": 2, "cairn": 2, "district_trigger": 1, "fragment": 4},
	&"ember_quarter": {"campfire": 2, "cairn": 2, "component": 1,
		"district_trigger": 1, "fire_grid": 1, "fragment": 4, "heat": 3},
	&"cistern": {"campfire": 1, "cairn": 2, "component": 1,
		"district_trigger": 1, "fragment": 3, "water": 4},
	&"spine": {"campfire": 1, "component": 1, "district_trigger": 1, "fragment": 3},
	&"dark": {"district_trigger": 1, "drowned": 6, "figurehead": 1, "fragment": 2},
}

var _totals: Dictionary = {}
var _fragment_ids: Dictionary = {}
var _component_ids: Dictionary = {}


func before_each() -> void:
	_totals.clear()
	_fragment_ids.clear()
	_component_ids.clear()
	var game_state: Node = get_tree().root.get_node_or_null("GameState")
	if game_state != null and game_state.has_method("reset"):
		game_state.call("reset")


func test_real_lanka_contains_live_gameplay() -> void:
	var packed: PackedScene = load(LANKA_PATH) as PackedScene
	assert_not_null(packed, "real shipped lanka.tscn loads")
	if packed == null:
		return
	var lanka: Node3D = packed.instantiate() as Node3D
	assert_not_null(lanka, "real shipped lanka.tscn instantiates")
	if lanka == null:
		return

	var player: Node3D = lanka.get_node_or_null(PLAYER_PATH) as Node3D
	var shallows_anchor: Node3D = lanka.get_node_or_null("DistrictAnchors/Shallows") as Node3D
	assert_not_null(player, "player.tscn is instanced in Lanka")
	assert_not_null(shallows_anchor, "Shallows spawn anchor exists")
	add_child_autofree(lanka)
	await _wait_for_initial_streaming(lanka)

	assert_same(lanka.get("streaming_target"), player, "the real player drives streaming")
	assert_gt(int(lanka.call("loaded_chunk_count")), 0, "StreamedChunks is populated")
	assert_gt(int(lanka.call("loaded_district_count")), 0, "StreamedDistricts is populated")
	if player != null and shallows_anchor != null:
		assert_lt(
			player.global_position.distance_to(shallows_anchor.global_position), 2.0,
			"initial streaming cannot drop Nau through the Shallows"
		)
		assert_true(player.is_physics_processing(), "Nau controller is live after collision streams")
		var walk_start: Vector2 = Vector2(player.global_position.x, player.global_position.z)
		Input.action_press(&"move_forward")
		await wait_physics_frames(30)
		Input.action_release(&"move_forward")
		var walk_end: Vector2 = Vector2(player.global_position.x, player.global_position.z)
		assert_gt(walk_start.distance_to(walk_end), 0.5, "Nau walks in real Lanka")
		player.set_physics_process(false)

	var camera: Camera3D = _find_type(player, &"Camera3D") as Camera3D
	assert_not_null(camera, "player supplies a runtime camera")
	if camera != null:
		assert_true(camera.is_current(), "player camera is current")
	var hud: CanvasLayer = _find_type(player, &"CanvasLayer") as CanvasLayer
	assert_not_null(hud, "player supplies its HUD")
	if hud != null:
		assert_true(hud.visible, "HUD CanvasLayer renders")
		assert_gt(_visible_controls(hud), 0, "HUD contains visible runtime controls")
	var environment: WorldEnvironment = lanka.get_node_or_null(
		"PersistentLook/SmokeEnvironment"
	) as WorldEnvironment
	assert_not_null(environment, "persistent WorldEnvironment is live")
	if environment != null:
		assert_not_null(environment.environment, "persistent environment resource is assigned")
	var sun: DirectionalLight3D = lanka.get_node_or_null(
		"PersistentLook/LowSmokeSun"
	) as DirectionalLight3D
	assert_not_null(sun, "persistent low sun is live")

	var shallows: Node = await _move_player_and_get(lanka, player, &"shallows")
	_assert_district(shallows, &"shallows")
	var terraces: Node = await _move_player_and_get(lanka, player, &"terraces")
	_assert_district(terraces, &"terraces")
	var ember: Node = await _move_player_and_get(lanka, player, &"ember_quarter")
	_assert_district(ember, &"ember_quarter")
	_assert_ember(ember)
	var cistern: Node = await _move_player_and_get(lanka, player, &"cistern")
	_assert_district(cistern, &"cistern")
	_assert_cistern(cistern)

	var spine: Node = lanka.get_node_or_null("PersistentLandmarks/SpineDistrict")
	_assert_district(spine, &"spine")

	var dark_packed: PackedScene = load(DistrictContract.DARK_PATH) as PackedScene
	assert_not_null(dark_packed, "real separate Dark scene loads")
	var dark: Node3D = dark_packed.instantiate() as Node3D if dark_packed != null else null
	if dark != null:
		add_child_autofree(dark)
		await get_tree().process_frame
		await get_tree().physics_frame
	_assert_district(dark, &"dark")

	assert_eq(int(_totals.get("campfire", 0)), 8, "all 8 campfires are live")
	assert_eq(int(_totals.get("district_trigger", 0)), 6, "all 6 district triggers are live")
	assert_eq(int(_totals.get("cairn", 0)), 8, "all 8 Cairn entrances are live")
	assert_eq(int(_totals.get("ocean_kill", 0)), 1, "the shipped ocean kill volume is live")
	assert_eq(int(_totals.get("fragment", 0)), 20, "all 20 fragment pickups are live")
	assert_eq(_component_ids.size(), 4, "exactly four trial component ids ship")
	for required_component: StringName in [&"hull", &"keel", &"mast", &"sail"]:
		assert_true(
			_component_ids.has(required_component),
			"the %s trial component pickup ships" % required_component
		)
	_assert_fragment_defs()


func _move_player_and_get(lanka: Node3D, player: Node3D, district_id: StringName) -> Node:
	if player == null:
		return null
	player.global_position = DistrictContract.district_center(district_id)
	return await _wait_for_district(lanka, DistrictContract.district_path(district_id))


func _wait_for_initial_streaming(lanka: Node3D) -> void:
	for frame: int in 1200:
		await get_tree().process_frame
		if (
			int(lanka.call("pending_chunk_count")) == 0
			and int(lanka.call("pending_district_count")) == 0
			and int(lanka.call("loaded_chunk_count")) > 0
			and int(lanka.call("loaded_district_count")) > 0
		):
			return
	fail_test("initial real-player streaming timed out")


func _wait_for_district(lanka: Node3D, scene_path: String) -> Node:
	for frame: int in 1200:
		await get_tree().process_frame
		for child: Node in lanka.get_node("StreamedDistricts").get_children():
			if (
				child.scene_file_path == scene_path
				and bool(child.get_meta(&"district_streaming_ready", true))
			):
				return child
	fail_test("real-player streaming timed out for %s" % scene_path)
	return null


func _assert_district(district: Node, district_id: StringName) -> void:
	assert_not_null(district, "%s shipped scene is resident" % district_id)
	if district == null:
		return
	assert_true(district.is_inside_tree(), "%s shipped scene is live" % district_id)
	var expected: Dictionary = EXPECTED[district_id] as Dictionary
	for type_value: Variant in expected:
		var prefab_type: String = str(type_value)
		var expected_count: int = int(expected[prefab_type])
		var prefab_path: String = str(PREFABS[prefab_type])
		var nodes: Array[Node] = _metadata_nodes(district, &"m9_prefab_path", prefab_path)
		var missing: Array[Node] = _metadata_nodes(district, &"m9_missing_prefab", prefab_path)
		assert_eq(
			missing.size(), 0,
			"%s has the SYSTEMS %s prefab available" % [district_id, prefab_type]
		)
		assert_eq(
			nodes.size(), expected_count,
			"%s has %d live %s instance(s)" % [district_id, expected_count, prefab_type]
		)
		_totals[prefab_type] = int(_totals.get(prefab_type, 0)) + nodes.size()
		for node: Node in nodes:
			assert_true(
				node.is_inside_tree() and node.process_mode != Node.PROCESS_MODE_DISABLED,
				"%s %s instance is active" % [district_id, prefab_type]
			)
			if prefab_type == "fragment":
				_fragment_ids[StringName(str(node.get("fragment_id")))] = true
			elif prefab_type == "component":
				_component_ids[StringName(str(node.get("component_id")))] = true


func _assert_ember(ember: Node) -> void:
	if ember == null:
		return
	var flammables: Array[Node] = _script_nodes(ember, FLAMMABLE_SCRIPT_PATH)
	assert_gte(flammables.size(), 24, "Ember ships a field of flammable timber props")
	for flammable: Node in flammables:
		var body: CollisionObject3D = flammable.get_parent() as CollisionObject3D
		assert_true(
			body != null and (body.collision_layer & (1 << 10)) != 0,
			"shipped flammable timber uses the flammable collision layer"
		)
	var grids: Array[Node] = _metadata_nodes(
		ember, &"m9_prefab_path", str(PREFABS["fire_grid"])
	)
	if not grids.is_empty():
		assert_true(grids[0].has_method("ignite_at"), "shipped FireGrid is callable")
	var heat_nodes: Array[Node] = _metadata_nodes(ember, &"m9_prefab_path", str(PREFABS["heat"]))
	var heights: PackedFloat32Array = PackedFloat32Array()
	for heat: Node in heat_nodes:
		heights.append((heat as Node3D).global_position.y)
	heights.sort()
	assert_true(
		heights.size() == 3 and heights[0] < heights[1] and heights[1] < heights[2],
		"Ember heat volumes are stacked vertically"
	)


func _assert_cistern(cistern: Node) -> void:
	if cistern == null:
		return
	var waters: Array[Node] = _metadata_nodes(cistern, &"m9_prefab_path", str(PREFABS["water"]))
	var live_shapes: int = 0
	for water: Node in waters:
		var shape: CollisionShape3D = _find_type(water, &"CollisionShape3D") as CollisionShape3D
		if shape != null and shape.shape != null and not shape.disabled:
			live_shapes += 1
	assert_eq(live_shapes, 4, "all four Cistern water volumes have active shapes")


func _assert_fragment_defs() -> void:
	assert_eq(_fragment_ids.size(), 20, "fragment ids are unique")
	for id_value: Variant in _fragment_ids:
		var fragment_id: StringName = id_value as StringName
		var def: Resource = load("res://assets/fragments/%s.tres" % fragment_id)
		assert_not_null(def, "%s has an authored FragmentDef" % fragment_id)
		if def != null:
			assert_eq(StringName(str(def.get("id"))), fragment_id)
			assert_ne(str(def.get("crew_name")), "")
			assert_ne(str(def.get("memento")), "")
			assert_ne(str(def.get("lines")), "")


func _metadata_nodes(scope: Node, key: StringName, value: Variant) -> Array[Node]:
	var matches: Array[Node] = []
	if scope == null:
		return matches
	if scope.has_meta(key) and scope.get_meta(key) == value:
		matches.append(scope)
	for child: Node in scope.get_children():
		matches.append_array(_metadata_nodes(child, key, value))
	return matches


func _script_nodes(scope: Node, path: String) -> Array[Node]:
	var matches: Array[Node] = []
	if scope == null:
		return matches
	var script: Script = scope.get_script() as Script
	if script != null and script.resource_path == path:
		matches.append(scope)
	for child: Node in scope.get_children():
		matches.append_array(_script_nodes(child, path))
	return matches


func _find_type(scope: Node, type_name: StringName) -> Node:
	if scope == null:
		return null
	for child: Node in scope.get_children():
		if child.is_class(type_name):
			return child
		var nested: Node = _find_type(child, type_name)
		if nested != null:
			return nested
	return null


func _visible_controls(scope: Node) -> int:
	if scope == null:
		return 0
	var count: int = 1 if scope is Control and (scope as Control).is_visible_in_tree() else 0
	for child: Node in scope.get_children():
		count += _visible_controls(child)
	return count
