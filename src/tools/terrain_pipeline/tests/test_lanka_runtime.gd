extends SceneTree

const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")

const LANKA_SCENE_PATH: String = "res://scenes/levels/lanka/lanka.tscn"
const PLAYER_SCENE_PATH: String = "res://scenes/player/player.tscn"
const PLAYER_PATH: NodePath = ^"DistrictAnchors/Shallows/Player"
const FLAMMABLE_SCRIPT_PATH: String = "res://src/world/fire/flammable.gd"
const PREFAB_PATHS: Dictionary = {
	"campfire": "res://scenes/prefabs/gameplay/campfire.tscn",
	"cairn": "res://scenes/prefabs/gameplay/cairn_entrance.tscn",
	"component": "res://scenes/prefabs/gameplay/component_pickup.tscn",
	"district_trigger": "res://scenes/prefabs/gameplay/district_trigger.tscn",
	"drowned": "res://scenes/prefabs/gameplay/drowned.tscn",
	"figurehead": "res://scenes/prefabs/gameplay/figurehead_carryable.tscn",
	"fire_grid": "res://scenes/prefabs/gameplay/fire_grid.tscn",
	"fragment": "res://scenes/prefabs/gameplay/fragment_pickup.tscn",
	"heat": "res://scenes/prefabs/gameplay/heat_volume.tscn",
	"setu": "res://scenes/prefabs/gameplay/setu.tscn",
	"water": "res://scenes/prefabs/gameplay/water_volume.tscn",
}
const EXPECTED_BY_DISTRICT: Dictionary = {
	"shallows": {
		"campfire": 2,
		"cairn": 2,
		"component": 1,
		"district_trigger": 1,
		"fragment": 4,
		"setu": 1,
	},
	"terraces": {
		"campfire": 2,
		"cairn": 2,
		"district_trigger": 1,
		"fragment": 4,
	},
	"ember_quarter": {
		"campfire": 2,
		"cairn": 2,
		"component": 1,
		"district_trigger": 1,
		"fire_grid": 1,
		"fragment": 4,
		"heat": 3,
	},
	"cistern": {
		"campfire": 1,
		"cairn": 2,
		"component": 1,
		"district_trigger": 1,
		"fragment": 3,
		"water": 4,
	},
	"spine": {
		"campfire": 1,
		"component": 1,
		"district_trigger": 1,
		"fragment": 3,
	},
	"dark": {
		"district_trigger": 1,
		"drowned": 6,
		"figurehead": 1,
		"fragment": 2,
	},
}

var _failures: int = 0
var _observed_totals: Dictionary = {}
var _fragment_ids: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load(LANKA_SCENE_PATH) as PackedScene
	_expect(packed != null, "real shipped Lanka scene loads")
	if packed == null:
		quit(_failures)
		return

	var lanka: Node3D = packed.instantiate() as Node3D
	_expect(lanka != null, "real shipped Lanka scene instantiates")
	if lanka == null:
		quit(_failures)
		return

	var shallows_anchor: Node3D = lanka.get_node_or_null("DistrictAnchors/Shallows") as Node3D
	var player: Node3D = lanka.get_node_or_null(PLAYER_PATH) as Node3D
	_expect(shallows_anchor != null, "Shallows spawn anchor exists")
	_expect(player != null, "SYSTEMS player scene is instanced at the Shallows anchor")
	if player != null:
		_expect(player.position.is_zero_approx(), "Nau's authored transform is the Shallows anchor")

	root.add_child(lanka)

	_expect(lanka.get("streaming_target") == player, "the live Nau instance drives Lanka streaming")
	if shallows_anchor != null and player != null:
		var player_xz: Vector2 = Vector2(player.global_position.x, player.global_position.z)
		var anchor_xz: Vector2 = Vector2(
			shallows_anchor.global_position.x, shallows_anchor.global_position.z
		)
		_expect(
			player_xz.is_equal_approx(anchor_xz),
			"Nau starts over the Shallows anchor before terrain settling"
		)
	_expect(
		player != null and player.scene_file_path == PLAYER_SCENE_PATH,
		"the shipped scene preserves player.tscn as an external instance"
	)

	var camera: Camera3D = _find_descendant_of_type(player, &"Camera3D") as Camera3D
	_expect(camera != null and camera.is_current(), "the instanced player contributes the current camera")
	var hud_layer: CanvasLayer = _find_descendant_of_type(player, &"CanvasLayer") as CanvasLayer
	_expect(hud_layer != null and hud_layer.visible, "the player HUD CanvasLayer is live and visible")
	_expect(_visible_control_count(hud_layer) > 0, "the player HUD has visible runtime controls")

	var environment_node: WorldEnvironment = lanka.get_node_or_null(
		"PersistentLook/SmokeEnvironment"
	) as WorldEnvironment
	_expect(
		environment_node != null and environment_node.environment != null,
		"persistent sky, fog, and volumetrics are active before district streaming"
	)
	var sun: DirectionalLight3D = lanka.get_node_or_null(
		"PersistentLook/LowSmokeSun"
	) as DirectionalLight3D
	_expect(sun != null and sun.visible, "persistent low smoke sun is live")

	await _wait_for_initial_streaming(lanka)
	_expect(int(lanka.call("loaded_chunk_count")) > 0, "StreamedChunks populates around Nau")
	_expect(int(lanka.call("loaded_district_count")) > 0, "StreamedDistricts populates around Nau")
	if player != null and shallows_anchor != null:
		_expect(player.is_physics_processing(), "Nau's controller releases after initial collision streams")
		_expect(
			player.global_position.distance_to(shallows_anchor.global_position) < 2.0,
			"Nau remains at the Shallows spawn while initial collision streams"
		)
		var walk_start: Vector2 = Vector2(player.global_position.x, player.global_position.z)
		Input.action_press(&"move_forward")
		for frame: int in 30:
			await physics_frame
		Input.action_release(&"move_forward")
		var walk_end: Vector2 = Vector2(player.global_position.x, player.global_position.z)
		_expect(walk_start.distance_to(walk_end) > 0.5, "Nau walks in the real shipped scene")
		# Freeze only after the production spawn guard has been proven. The smoke then
		# moves this same real Nau instance through normal streaming without allowing
		# gravity to outrun collision at each distant test position.
		player.set_physics_process(false)

	var shallows: Node = await _move_real_player_and_get_district(
		lanka, player, &"shallows"
	)
	_assert_district_runtime(shallows, &"shallows")

	var terraces: Node = await _move_real_player_and_get_district(
		lanka, player, &"terraces"
	)
	_assert_district_runtime(terraces, &"terraces")

	# Ember and Cistern deliberately share an x/z streaming center; both are real
	# shipped scenes loaded by Lanka's normal player-driven streaming path.
	var ember: Node = await _move_real_player_and_get_district(
		lanka, player, &"ember_quarter"
	)
	var cistern: Node = await _wait_for_district(lanka, DistrictContract.district_path(&"cistern"))
	_assert_district_runtime(ember, &"ember_quarter")
	_assert_district_runtime(cistern, &"cistern")
	_assert_ember_runtime(ember)
	_assert_cistern_runtime(cistern)

	var spine: Node = lanka.get_node_or_null("PersistentLandmarks/SpineDistrict")
	_expect(spine != null, "the full Spine shipped scene remains persistent")
	_assert_district_runtime(spine, &"spine")

	# The Dark is a separate streamed area by architecture, never an open-world
	# district. Instantiate its real shipped scene for the same runtime smoke pass.
	var dark_packed: PackedScene = load(DistrictContract.DARK_PATH) as PackedScene
	_expect(dark_packed != null, "the real shipped Dark scene loads")
	var dark: Node3D = null
	if dark_packed != null:
		dark = dark_packed.instantiate() as Node3D
		root.add_child(dark)
		await process_frame
		await physics_frame
	_assert_district_runtime(dark, &"dark")

	_assert_component_set()
	_assert_fragment_defs()
	_expect(int(_observed_totals.get("campfire", 0)) == 8, "all 8 shipped campfires are live")
	_expect(int(_observed_totals.get("district_trigger", 0)) == 6, "all 6 district triggers are live")
	_expect(int(_observed_totals.get("cairn", 0)) == 8, "all 8 Cairn entrances are live")
	_expect(int(_observed_totals.get("fragment", 0)) == 20, "all 20 fragment pickups are live")

	if player != null:
		player.set_physics_process(true)
		await physics_frame
		_expect(player.is_physics_processing(), "Nau's runtime controller is processing")

	print(
		"RUNTIME: player=%s hud=%s chunks=%d districts=%d prefabs=%s fragments=%d"
		% [
			player != null,
			hud_layer != null and hud_layer.visible,
			int(lanka.call("loaded_chunk_count")),
			int(lanka.call("loaded_district_count")),
			str(_observed_totals),
			_fragment_ids.size(),
		]
	)

	if dark != null:
		dark.queue_free()
	lanka.queue_free()
	for frame: int in 4:
		await process_frame
	if _failures == 0:
		print("PASS: Lanka shipped-scene M9 integration smoke")
	else:
		printerr("FAIL: %d Lanka shipped-scene assertion(s)" % _failures)
	quit(_failures)


func _move_real_player_and_get_district(
	lanka: Node3D, player: Node3D, district_id: StringName
) -> Node:
	if player == null:
		_expect(false, "%s cannot stream without the shipped player" % district_id)
		return null
	var position: Vector3 = DistrictContract.district_center(district_id)
	player.global_position = position
	return await _wait_for_district(lanka, DistrictContract.district_path(district_id))


func _wait_for_district(lanka: Node3D, scene_path: String) -> Node:
	for frame: int in 1200:
		await process_frame
		for child: Node in lanka.get_node("StreamedDistricts").get_children():
			if child.scene_file_path == scene_path:
				return child
	_expect(false, "player-driven streaming loads %s before timeout" % scene_path)
	return null


func _wait_for_initial_streaming(lanka: Node3D) -> void:
	for frame: int in 1200:
		await process_frame
		if (
			int(lanka.call("pending_chunk_count")) == 0
			and int(lanka.call("pending_district_count")) == 0
			and int(lanka.call("loaded_chunk_count")) > 0
			and int(lanka.call("loaded_district_count")) > 0
		):
			return
	_expect(false, "initial player-driven streaming completes before timeout")


func _assert_district_runtime(district: Node, district_id: StringName) -> void:
	_expect(district != null and district.is_inside_tree(), "%s shipped scene is live" % district_id)
	if district == null:
		return
	var expected: Dictionary = EXPECTED_BY_DISTRICT.get(str(district_id), {}) as Dictionary
	for prefab_name_value: Variant in expected:
		var prefab_name: String = str(prefab_name_value)
		var prefab_path: String = str(PREFAB_PATHS[prefab_name])
		var expected_count: int = int(expected[prefab_name])
		var nodes: Array[Node] = _nodes_with_metadata(district, &"m9_prefab_path", prefab_path)
		var missing_markers: Array[Node] = _nodes_with_metadata(
			district, &"m9_missing_prefab", prefab_path
		)
		_expect(
			missing_markers.is_empty(),
			"%s has the SYSTEMS %s prefab available" % [district_id, prefab_name]
		)
		_expect(
			nodes.size() == expected_count,
			"%s has %d live %s instance(s), found %d"
			% [district_id, expected_count, prefab_name, nodes.size()]
		)
		_observed_totals[prefab_name] = int(_observed_totals.get(prefab_name, 0)) + nodes.size()
		for node: Node in nodes:
			_expect(
				node.is_inside_tree() and node.process_mode != Node.PROCESS_MODE_DISABLED,
				"%s %s instance is live at runtime" % [district_id, prefab_name]
			)
		if prefab_name == "fragment":
			_record_fragment_ids(nodes, district_id)


func _assert_ember_runtime(ember: Node) -> void:
	if ember == null:
		return
	var grids: Array[Node] = _nodes_with_metadata(
		ember, &"m9_prefab_path", str(PREFAB_PATHS["fire_grid"])
	)
	if not grids.is_empty():
		_expect(grids[0].has_method("ignite_at"), "Ember FireGrid exposes the live ignition seam")
	var flammables: Array[Node] = _nodes_using_script(ember, FLAMMABLE_SCRIPT_PATH)
	_expect(flammables.size() >= 24, "Ember has a real field of flammable shipped timber props")
	for flammable: Node in flammables:
		_expect(flammable.is_inside_tree(), "a shipped Ember flammable component is live")
		var body: CollisionObject3D = flammable.get_parent() as CollisionObject3D
		_expect(
			body != null and (body.collision_layer & (1 << 10)) != 0,
			"flammable timber participates on the SYSTEMS flammable layer"
		)
	var heat_nodes: Array[Node] = _nodes_with_metadata(
		ember, &"m9_prefab_path", str(PREFAB_PATHS["heat"])
	)
	var heat_y: PackedFloat32Array = PackedFloat32Array()
	for heat: Node in heat_nodes:
		if heat is Node3D:
			heat_y.append((heat as Node3D).global_position.y)
	heat_y.sort()
	_expect(
		heat_y.size() == 3 and heat_y[0] < heat_y[1] and heat_y[1] < heat_y[2],
		"Ember heat volumes are stacked vertically because heat rises"
	)


func _assert_cistern_runtime(cistern: Node) -> void:
	if cistern == null:
		return
	var waters: Array[Node] = _nodes_with_metadata(
		cistern, &"m9_prefab_path", str(PREFAB_PATHS["water"])
	)
	var live_shapes: int = 0
	for water: Node in waters:
		var shape: CollisionShape3D = _find_descendant_of_type(water, &"CollisionShape3D") as CollisionShape3D
		if shape != null and not shape.disabled and shape.shape != null:
			live_shapes += 1
	_expect(live_shapes == 4, "all Cistern water volumes have live collision shapes")


func _assert_component_set() -> void:
	var expected_ids: Dictionary = {
		&"hull": true,
		&"mast": true,
		&"sail": true,
		&"keel": true,
	}
	var observed_ids: Dictionary = {}
	for district_id_value: Variant in EXPECTED_BY_DISTRICT:
		var district_id: StringName = StringName(str(district_id_value))
		# Component counts were accumulated while each streamed scene was live; IDs
		# are checked from the shipped scenes directly to survive later unloading.
		var path: String = DistrictContract.district_path(district_id)
		if district_id == &"spine":
			path = DistrictContract.SPINE_PATH
		if path.is_empty():
			continue
		var packed: PackedScene = load(path) as PackedScene
		var scene: Node = packed.instantiate() if packed != null else null
		if scene == null:
			continue
		for pickup: Node in _nodes_with_metadata(
			scene, &"m9_prefab_path", str(PREFAB_PATHS["component"])
		):
			observed_ids[StringName(str(pickup.get("component_id")))] = true
		scene.free()
	_expect(observed_ids == expected_ids, "trial ends ship hull, mast, sail, and keel pickups")


func _record_fragment_ids(nodes: Array[Node], district_id: StringName) -> void:
	for pickup: Node in nodes:
		var fragment_id: StringName = StringName(str(pickup.get("fragment_id")))
		_expect(fragment_id != &"", "%s fragment pickup has a stable id" % district_id)
		_expect(not _fragment_ids.has(fragment_id), "fragment id %s is unique" % fragment_id)
		_fragment_ids[fragment_id] = true


func _assert_fragment_defs() -> void:
	_expect(_fragment_ids.size() == 20, "the shipped scenes expose 20 unique fragment ids")
	for fragment_id_value: Variant in _fragment_ids:
		var fragment_id: StringName = fragment_id_value as StringName
		var def_path: String = "res://assets/fragments/%s.tres" % fragment_id
		var def: Resource = load(def_path)
		_expect(def != null, "fragment %s has an authored FragmentDef" % fragment_id)
		if def != null:
			_expect(StringName(str(def.get("id"))) == fragment_id, "%s FragmentDef id matches" % fragment_id)
			_expect(not str(def.get("crew_name")).is_empty(), "%s has a crew name" % fragment_id)
			_expect(not str(def.get("memento")).is_empty(), "%s has a memento" % fragment_id)
			_expect(not str(def.get("lines")).is_empty(), "%s has memory text" % fragment_id)


func _nodes_with_metadata(scope: Node, key: StringName, value: Variant) -> Array[Node]:
	var matches: Array[Node] = []
	if scope == null:
		return matches
	if scope.has_meta(key) and scope.get_meta(key) == value:
		matches.append(scope)
	for child: Node in scope.get_children():
		matches.append_array(_nodes_with_metadata(child, key, value))
	return matches


func _nodes_using_script(scope: Node, script_path: String) -> Array[Node]:
	var matches: Array[Node] = []
	if scope == null:
		return matches
	var script: Script = scope.get_script() as Script
	if script != null and script.resource_path == script_path:
		matches.append(scope)
	for child: Node in scope.get_children():
		matches.append_array(_nodes_using_script(child, script_path))
	return matches


func _visible_control_count(scope: Node) -> int:
	if scope == null:
		return 0
	var count: int = 0
	if scope is Control and (scope as Control).is_visible_in_tree():
		count += 1
	for child: Node in scope.get_children():
		count += _visible_control_count(child)
	return count


func _find_descendant_of_type(parent: Node, type_name: StringName) -> Node:
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child.is_class(type_name):
			return child
		var nested: Node = _find_descendant_of_type(child, type_name)
		if nested != null:
			return nested
	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("ASSERTION FAILED: %s" % message)
