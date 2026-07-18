extends SceneTree

const BuilderScript: Script = preload("res://src/tools/terrain_pipeline/district_scene_builder.gd")
const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")
const ContentContract: Script = preload("res://scenes/levels/lanka/lanka_content_contract.gd")
const EmberRuntimeScript: Script = preload("res://scenes/levels/lanka/districts/ember_quarter/ember_quarter_runtime.gd")
const DistrictSegmentLoaderScript: Script = preload("res://scenes/levels/lanka/district_segment_loader.gd")
const FLAMMABLE_SCRIPT_PATH: String = "res://src/world/fire/flammable.gd"
const SEGMENT_BATCH_SIZE: int = 2
const SEGMENT_CONTAINER_NAMES: Array[String] = [
	"GameplaySockets", "WorldGeometry", "Dressing", "RouteMarkers", "M8RenderBatches",
]

const PREFAB_PATHS: Dictionary = {
	&"campfire": "res://scenes/prefabs/gameplay/campfire.tscn",
	&"cairn_entrance": "res://scenes/prefabs/gameplay/cairn_entrance.tscn",
	&"crew_fragment": "res://scenes/prefabs/gameplay/fragment_pickup.tscn",
	&"district_trigger": "res://scenes/prefabs/gameplay/district_trigger.tscn",
	&"drowned_spawn": "res://scenes/prefabs/gameplay/drowned.tscn",
	&"heat_volume": "res://scenes/prefabs/gameplay/heat_volume.tscn",
	&"ocean_kill_volume": "res://scenes/prefabs/gameplay/kill_volume.tscn",
	&"water_current": "res://scenes/prefabs/gameplay/water_volume.tscn",
	&"water_volume": "res://scenes/prefabs/gameplay/water_volume.tscn",
}

const FIRE_GRID_PATH: String = "res://scenes/prefabs/gameplay/fire_grid.tscn"
const COMPONENT_PICKUP_PATH: String = "res://scenes/prefabs/gameplay/component_pickup.tscn"
const FIGUREHEAD_PATH: String = "res://scenes/prefabs/gameplay/figurehead_carryable.tscn"
const SETU_PATH: String = "res://scenes/prefabs/gameplay/setu.tscn"

var _builder: RefCounted
var _materials: Dictionary = {}


func _initialize() -> void:
	_builder = BuilderScript.new() as RefCounted
	_materials = _make_materials()
	var requested: PackedStringArray = OS.get_cmdline_user_args()
	if requested.is_empty():
		requested = PackedStringArray([
			"shallows", "terraces", "ember_quarter", "cistern", "spine", "dark",
		])
	for district_id: String in requested:
		var build_error: Error = _build_district(district_id)
		if build_error != OK:
			printerr("Unable to build %s: %s" % [district_id, error_string(build_error)])
			quit(1)
			return
	print("Wrote Lanka M5 district scenes: %s" % ", ".join(requested))
	quit(0)


func _build_district(district_id: String) -> Error:
	match district_id:
		"shallows":
			return _build_shallows()
		"terraces":
			return _build_terraces()
		"ember_quarter":
			return _build_ember_quarter()
		"cistern":
			return _build_cistern()
		"spine":
			return _build_spine()
		"dark":
			return _build_dark()
		_:
			return ERR_INVALID_PARAMETER


func _build_shallows() -> Error:
	var root: Node3D = _make_open_world_root(&"shallows")
	var geometry: Node3D = root.get_node("WorldGeometry") as Node3D
	var dressing: Node3D = root.get_node("Dressing") as Node3D
	var sockets: Node3D = root.get_node("GameplaySockets") as Node3D
	var routes: Node3D = root.get_node("RouteMarkers") as Node3D
	for index: int in 12:
		var distance: float = float(index) * 25.0
		var stump_position: Vector3 = Vector3(
			sin(float(index) * 0.9) * 5.0,
			-2.0 - float(index) * 0.32,
			-82.0 - distance
		)
		_builder.add_static_cylinder(
			geometry,
			"SetuStump%02d" % index,
			stump_position,
			5.8 - minf(float(index) * 0.14, 1.6),
			18.0 - minf(float(index), 6.0),
			_materials[&"wet_stone"],
			true,
			Vector3(0.0, 0.0, sin(float(index)) * 4.0),
			18
		)
	_builder.add_visibility_notifier(
		geometry, AABB(Vector3(-20.0, -12.0, -375.0), Vector3(40.0, 35.0, 320.0))
	)
	_add_wrecked_hull(dressing, "ArrivalWreck", Vector3(-92.0, 5.0, 22.0), -18.0, 1.0)
	_add_wrecked_hull(dressing, "EasternWreck", Vector3(125.0, 3.0, -38.0), 22.0, 0.78)
	_add_wrecked_hull(dressing, "KefferOverturnedHull", Vector3(-135.0, 8.0, 68.0), 8.0, 0.9)
	for debris_index: int in 18:
		var angle: float = float(debris_index) * 1.71
		var debris_position: Vector3 = Vector3(
			sin(angle) * (55.0 + float(debris_index % 4) * 34.0),
			1.8,
			cos(angle) * (45.0 + float(debris_index % 5) * 24.0)
		)
		_builder.add_visual_box(
			dressing,
			"WreckDebris%02d" % debris_index,
			debris_position,
			Vector3(2.5 + float(debris_index % 3), 1.2, 12.0 + float(debris_index % 4) * 3.0),
			_materials[&"charred_timber"],
			Vector3(float((debris_index * 13) % 28), angle * 28.0, float((debris_index * 7) % 18))
		)
	var build_site: Node3D = Node3D.new()
	build_site.name = "SetuBuildSite"
	build_site.position = Vector3(105.0, 4.0, 78.0)
	geometry.add_child(build_site)
	_builder.add_static_box(build_site, "SlipwayLeft", Vector3(-14.0, 0.0, 0.0), Vector3(4.0, 2.0, 52.0), _materials[&"clean_stone"], true)
	_builder.add_static_box(build_site, "SlipwayRight", Vector3(14.0, 0.0, 0.0), Vector3(4.0, 2.0, 52.0), _materials[&"clean_stone"], true)
	_builder.add_static_box(build_site, "AssemblyPlinth", Vector3(0.0, 2.0, 18.0), Vector3(38.0, 4.0, 22.0), _materials[&"clean_stone"], true)
	_builder.add_marker(
		sockets, "OceanKillVolume", Vector3(0.0, -15.0, -275.0), &"ocean_kill_volume",
		{&"socket_size_m": Vector3(1250.0, 24.0, 520.0), &"district_id": &"shallows"}
	)
	_builder.add_marker(
		sockets, "DistrictTrigger", Vector3(0.0, 6.0, 105.0), &"district_trigger",
		{&"socket_size_m": Vector3(260.0, 30.0, 80.0), &"district_id": &"shallows"}
	)
	for carry_index: int in 4:
		_builder.add_marker(
			sockets, "HoldCarryable%02d" % carry_index,
			Vector3(-48.0 + float(carry_index) * 25.0, 4.0, 35.0), &"carryable_object",
			{&"spawn_id": StringName("hold_object_%02d" % carry_index)}
		)
	_builder.add_marker(routes, "Arrival", Vector3(0.0, 3.0, -75.0), &"route_anchor", {&"route_id": &"arrival"})
	_builder.add_marker(routes, "HoldTrial", Vector3(45.0, 5.0, 32.0), &"route_anchor", {&"route_id": &"hold"})
	_builder.add_marker(routes, "KefferShelter", Vector3(-135.0, 5.0, 68.0), &"route_anchor", {&"route_id": &"keffer"})
	_builder.add_marker(routes, "InlandExit", Vector3(0.0, 10.0, 155.0), &"route_anchor", {&"route_id": &"inland"})
	_builder.add_box_occluder(dressing, "KefferHullOccluder", Vector3(-135.0, 8.0, 68.0), Vector3(54.0, 15.0, 22.0))
	_add_m6_content(root, &"shallows")
	_add_m9_gameplay(root, &"shallows")
	return _save_and_free(root, DistrictContract.district_path(&"shallows"))


func _build_terraces() -> Error:
	var root: Node3D = _make_open_world_root(&"terraces")
	var geometry: Node3D = root.get_node("WorldGeometry") as Node3D
	var dressing: Node3D = root.get_node("Dressing") as Node3D
	var sockets: Node3D = root.get_node("GameplaySockets") as Node3D
	var routes: Node3D = root.get_node("RouteMarkers") as Node3D
	var grip_materials: Array[Material] = [
		_materials[&"clean_stone"], _materials[&"cracked_stone"],
		_materials[&"soot_stone"], _materials[&"ember_stone"],
		_materials[&"clean_stone"], _materials[&"cracked_stone"],
	]
	for tier: int in 6:
		var tier_x: float = -145.0 + float(tier) * 54.0
		var tier_y: float = -9.0 + float(tier) * 5.5
		_builder.add_static_box(
			geometry, "TerraceBed%02d" % tier, Vector3(tier_x, tier_y - 1.5, 0.0),
			Vector3(52.0, 3.0, 230.0), _materials[&"ash_earth"], false
		)
		_builder.add_static_box(
			geometry, "RetainingWall%02d" % tier, Vector3(tier_x - 27.0, tier_y + 1.0, 0.0),
			Vector3(5.0, 8.0, 230.0), grip_materials[tier], true
		)
		_builder.add_static_box(
			geometry, "IrrigationChannelLeft%02d" % tier, Vector3(tier_x, tier_y + 0.3, -55.0),
			Vector3(48.0, 1.0, 4.0), _materials[&"wet_stone"], true
		)
		_builder.add_static_box(
			geometry, "IrrigationChannelRight%02d" % tier, Vector3(tier_x, tier_y + 0.3, 55.0),
			Vector3(48.0, 1.0, 4.0), _materials[&"wet_stone"], true
		)
		var safe_route_z: float = -92.0 + float(tier) * 34.0
		_builder.add_static_box(
			geometry, "SafeRouteStep%02d" % tier,
			Vector3(tier_x - 27.0, tier_y + 2.0, safe_route_z),
			Vector3(13.0, 3.0, 17.0), _materials[&"clean_stone"], true
		)
		_builder.add_marker(
			routes, "TierLanding%02d" % tier, Vector3(tier_x, tier_y + 1.5, 0.0), &"route_anchor",
			{&"route_id": StringName("terrace_tier_%02d" % tier), &"grip_lesson": grip_materials[tier].resource_name}
		)
	for collapse: int in 14:
		var collapse_position: Vector3 = Vector3(
			-125.0 + float((collapse * 37) % 260),
			-3.0 + float(collapse % 5) * 2.8,
			-105.0 + float((collapse * 61) % 210)
		)
		_builder.add_visual_box(
			dressing, "CollapsedWallStone%02d" % collapse, collapse_position,
			Vector3(8.0 + float(collapse % 3) * 3.0, 4.0, 5.0 + float(collapse % 4)),
			_materials[&"cracked_stone"], Vector3(0.0, float((collapse * 29) % 180), float((collapse % 3) * 9))
		)
	for habitat: int in 6:
		_builder.add_marker(
			sockets, "AshrootHabitat%02d" % habitat,
			Vector3(-118.0 + float(habitat) * 46.0, -5.0 + float(habitat) * 5.0, -82.0 + float((habitat * 33) % 155)),
			&"ingredient_habitat", {&"spawn_id": StringName("ashroot_habitat_%02d" % habitat)}
		)
	_builder.add_marker(
		sockets, "DistrictTrigger", Vector3(145.0, 8.0, 0.0), &"district_trigger",
		{&"socket_size_m": Vector3(70.0, 35.0, 210.0), &"district_id": &"terraces"}
	)
	_builder.add_marker(routes, "SouthEntry", Vector3(110.0, 2.0, -110.0), &"route_anchor", {&"route_id": &"south_entry"})
	_builder.add_marker(routes, "MesaExit", Vector3(150.0, 10.0, 95.0), &"route_anchor", {&"route_id": &"mesa_exit"})
	for occluder_tier: int in [1, 3, 5]:
		var occluder_x: float = -172.0 + float(occluder_tier) * 54.0
		var occluder_y: float = -8.0 + float(occluder_tier) * 5.5
		_builder.add_box_occluder(
			geometry, "TerraceStepOccluder%02d" % occluder_tier,
			Vector3(occluder_x, occluder_y, 0.0), Vector3(5.0, 8.0, 230.0)
		)
	_builder.add_visibility_notifier(geometry, AABB(Vector3(-180.0, -15.0, -125.0), Vector3(360.0, 55.0, 250.0)))
	_add_m6_content(root, &"terraces")
	_add_m9_gameplay(root, &"terraces")
	return _save_and_free(root, DistrictContract.district_path(&"terraces"))


func _build_ember_quarter() -> Error:
	var root: Node3D = _make_open_world_root(&"ember_quarter")
	var geometry: Node3D = root.get_node("WorldGeometry") as Node3D
	var dressing: Node3D = root.get_node("Dressing") as Node3D
	var sockets: Node3D = root.get_node("GameplaySockets") as Node3D
	var routes: Node3D = root.get_node("RouteMarkers") as Node3D
	for street: int in 3:
		_builder.add_static_box(
			geometry, "EastWestStreet%02d" % street, Vector3(0.0, -1.2, -105.0 + float(street) * 105.0),
			Vector3(300.0, 2.4, 24.0), _materials[&"soot_stone"], true
		)
	for street: int in 3:
		_builder.add_static_box(
			geometry, "NorthSouthStreet%02d" % street, Vector3(-105.0 + float(street) * 105.0, -1.0, 0.0),
			Vector3(22.0, 2.0, 250.0), _materials[&"soot_stone"], true
		)
	var building_positions: Array[Vector3] = [
		Vector3(-65.0, 0.0, -62.0), Vector3(60.0, 0.0, -62.0),
		Vector3(-66.0, 0.0, 58.0), Vector3(62.0, 0.0, 58.0),
		Vector3(128.0, 0.0, 62.0), Vector3(128.0, 0.0, -62.0),
	]
	for building_index: int in building_positions.size():
		_add_burnt_building(
			geometry, "BurntBuilding%02d" % building_index, building_positions[building_index],
			18.0 + float(building_index % 3) * 5.0, building_index
		)
	for crack: int in 7:
		var crack_position: Vector3 = Vector3(-118.0 + float(crack) * 39.0, 0.25, -12.0 + sin(float(crack)) * 42.0)
		_builder.add_visual_box(
			dressing, "EmberCrack%02d" % crack, crack_position,
			Vector3(24.0, 0.35, 2.4), _materials[&"ember_stone"], Vector3(0.0, float(crack * 17), 0.0)
		)
		_builder.add_marker(
			sockets, "FireSource%02d" % crack, crack_position + Vector3(0.0, 1.0, 0.0), &"fire_source",
			{&"spawn_id": StringName("ember_fire_%02d" % crack)}
		)
		_builder.add_fire_visual(dressing, "EmberFireVisual%02d" % crack, crack_position, 1.35)
	if true:
		var updraft_positions: Array[Vector3] = [Vector3(-38.0, 2.0, -8.0), Vector3(72.0, 2.0, 18.0), Vector3(118.0, 2.0, -72.0)]
		for updraft_index: int in updraft_positions.size():
			_builder.add_marker(
				sockets, "Updraft%02d" % updraft_index, updraft_positions[updraft_index], &"updraft_volume",
				{&"socket_size_m": Vector3(18.0, 55.0, 18.0), &"direction": Vector3.UP, &"strength": 18.0}
			)
	for heat_level: int in 3:
		_builder.add_marker(
			sockets, "HeatLayer%02d" % heat_level, Vector3(22.0, 6.0 + float(heat_level) * 22.0, 0.0), &"heat_volume",
			{&"socket_size_m": Vector3(250.0, 20.0, 220.0), &"strength": 1.0 + float(heat_level) * 0.55}
		)
	for habitat: int in 5:
		_builder.add_marker(
			sockets, "CharwoodHabitat%02d" % habitat,
			building_positions[habitat] + Vector3(8.0, 2.0, -6.0), &"ingredient_habitat",
			{&"spawn_id": StringName("charwood_habitat_%02d" % habitat)}
		)
	_builder.add_marker(
		sockets, "DistrictTrigger", Vector3(-138.0, 8.0, -95.0), &"district_trigger",
		{&"socket_size_m": Vector3(50.0, 35.0, 80.0), &"district_id": &"ember_quarter"}
	)
	_builder.add_marker(routes, "WestEntry", Vector3(-145.0, 3.0, -92.0), &"route_anchor", {&"route_id": &"west_entry"})
	_builder.add_marker(routes, "SmolderTrial", Vector3(66.0, 4.0, 20.0), &"route_anchor", {&"route_id": &"smolder"})
	_builder.add_marker(routes, "CisternEntrance", Vector3(105.0, 2.0, 96.0), &"route_anchor", {&"route_id": &"cistern_entrance"})
	_builder.add_box_occluder(geometry, "CityCoreOccluder", Vector3(15.0, 13.0, 0.0), Vector3(175.0, 26.0, 175.0))
	_builder.add_visibility_notifier(geometry, AABB(Vector3(-165.0, -5.0, -135.0), Vector3(340.0, 75.0, 270.0)))
	_add_m6_content(root, &"ember_quarter")
	root.set_script(EmberRuntimeScript)
	_add_m9_gameplay(root, &"ember_quarter")
	return _save_segmented_and_free(
		root, DistrictContract.district_path(&"ember_quarter"), &"ember_quarter"
	)


func _build_cistern() -> Error:
	var root: Node3D = _make_open_world_root(&"cistern")
	var geometry: Node3D = root.get_node("WorldGeometry") as Node3D
	var dressing: Node3D = root.get_node("Dressing") as Node3D
	var sockets: Node3D = root.get_node("GameplaySockets") as Node3D
	var routes: Node3D = root.get_node("RouteMarkers") as Node3D
	_builder.add_static_box(geometry, "ReservoirFloor", Vector3(0.0, -28.0, 0.0), Vector3(190.0, 4.0, 150.0), _materials[&"wet_stone"], true)
	_builder.add_static_box(geometry, "NorthWall", Vector3(0.0, 2.0, 76.0), Vector3(190.0, 64.0, 7.0), _materials[&"wet_stone"], true)
	_builder.add_static_box(geometry, "SouthWall", Vector3(0.0, 2.0, -76.0), Vector3(190.0, 64.0, 7.0), _materials[&"wet_stone"], true)
	_builder.add_static_box(geometry, "WestWall", Vector3(-96.0, 2.0, 0.0), Vector3(7.0, 64.0, 150.0), _materials[&"wet_stone"], true)
	_builder.add_static_box(geometry, "EastWall", Vector3(96.0, 2.0, 0.0), Vector3(7.0, 64.0, 150.0), _materials[&"wet_stone"], true)
	for column_x: int in 4:
		for column_z: int in 3:
			_builder.add_static_cylinder(
				geometry, "ReservoirColumn%d%d" % [column_x, column_z],
				Vector3(-66.0 + float(column_x) * 44.0, 0.0, -46.0 + float(column_z) * 46.0),
				4.2, 56.0, _materials[&"clean_stone"], true, Vector3.ZERO, 16
			)
	for walkway: int in 3:
		_builder.add_static_box(
			geometry, "SlickWalkway%02d" % walkway, Vector3(0.0, -18.0 + float(walkway) * 8.0, -48.0 + float(walkway) * 48.0),
			Vector3(170.0, 2.0, 8.0), _materials[&"wet_stone"], true
		)
	_builder.add_static_box(geometry, "EntranceShaft", Vector3(74.0, 20.0, 54.0), Vector3(20.0, 92.0, 20.0), _materials[&"clean_stone"], true)
	for drip: int in 12:
		_builder.add_visual_box(
			dressing, "CeilingRib%02d" % drip,
			Vector3(-82.0 + float(drip) * 15.0, 29.0, 0.0), Vector3(3.0, 3.0, 145.0),
			_materials[&"soot_stone"]
		)
	var water_scenery: MeshInstance3D = _builder.add_visual_plane(
		dressing, "ReservoirWaterScenery", Vector3(0.0, -12.0, 0.0),
		Vector2(182.0, 142.0), _materials[&"cistern_water"], Vector2i(32, 24)
	)
	water_scenery.set_meta(&"scenery_only", true)
	water_scenery.set_meta(&"simulation", false)
	var shaft_light: SpotLight3D = SpotLight3D.new()
	shaft_light.name = "EntranceShaftGodRay"
	shaft_light.position = Vector3(74.0, 61.0, 54.0)
	shaft_light.rotation_degrees.x = -90.0
	shaft_light.light_color = Color(0.82, 0.91, 0.84)
	shaft_light.light_energy = 7.0
	shaft_light.light_volumetric_fog_energy = 2.2
	shaft_light.spot_range = 98.0
	shaft_light.spot_angle = 19.0
	shaft_light.spot_attenuation = 0.65
	shaft_light.shadow_enabled = false
	shaft_light.distance_fade_enabled = true
	shaft_light.distance_fade_begin = 180.0
	shaft_light.distance_fade_shadow = 140.0
	shaft_light.distance_fade_length = 70.0
	shaft_light.set_meta(&"visual_only", true)
	shaft_light.set_meta(&"m8_shadow_budget", "volumetric_only")
	dressing.add_child(shaft_light)
	_builder.add_marker(
		sockets, "MainWaterVolume", Vector3(0.0, -20.0, 0.0), &"water_volume",
		{&"socket_size_m": Vector3(182.0, 16.0, 142.0), &"district_id": &"cistern"}
	)
	var current_directions: Array[Vector3] = [Vector3(1.0, 0.0, 0.15), Vector3(-0.25, 0.0, 1.0), Vector3(-1.0, 0.0, -0.2)]
	for current_index: int in current_directions.size():
		_builder.add_marker(
			sockets, "WaterCurrent%02d" % current_index,
			Vector3(-55.0 + float(current_index) * 55.0, -19.0, -25.0 + float(current_index) * 25.0), &"water_current",
			{&"socket_size_m": Vector3(42.0, 12.0, 42.0), &"direction": current_directions[current_index].normalized(), &"strength": 5.0}
		)
	for fish_habitat: int in 4:
		_builder.add_marker(
			sockets, "BlindFishHabitat%02d" % fish_habitat,
			Vector3(-65.0 + float(fish_habitat) * 42.0, -18.0, 38.0 - float(fish_habitat % 2) * 70.0),
			&"ingredient_habitat", {&"spawn_id": StringName("blind_fish_habitat_%02d" % fish_habitat)}
		)
	_builder.add_marker(
		sockets, "DistrictTrigger", Vector3(74.0, 56.0, 54.0), &"district_trigger",
		{&"socket_size_m": Vector3(24.0, 20.0, 24.0), &"district_id": &"cistern"}
	)
	_builder.add_marker(routes, "Entrance", Vector3(74.0, 61.0, 54.0), &"route_anchor", {&"route_id": &"entrance"})
	_builder.add_marker(routes, "FlameCarryStart", Vector3(-72.0, -8.0, -54.0), &"route_anchor", {&"route_id": &"flame_start"})
	_builder.add_marker(routes, "CisternTrial", Vector3(0.0, -15.0, 52.0), &"route_anchor", {&"route_id": &"cistern_trial"})
	_builder.add_box_occluder(geometry, "ReservoirOccluder", Vector3(0.0, 0.0, 0.0), Vector3(190.0, 60.0, 150.0))
	_builder.add_visibility_notifier(geometry, AABB(Vector3(-100.0, -32.0, -80.0), Vector3(200.0, 100.0, 160.0)))
	_add_m6_content(root, &"cistern")
	_add_m9_gameplay(root, &"cistern")
	return _save_segmented_and_free(root, DistrictContract.district_path(&"cistern"), &"cistern")


func _build_spine() -> Error:
	var root: Node3D = _make_root(&"spine", Vector3(0.0, 68.0, 430.0), "spine")
	root.set_meta(&"persistent_landmark", true)
	root.set_meta(&"convergence_requirements", PackedStringArray(["hold", "smolder", "cistern"]))
	var geometry: Node3D = root.get_node("WorldGeometry") as Node3D
	var sockets: Node3D = root.get_node("GameplaySockets") as Node3D
	var routes: Node3D = root.get_node("RouteMarkers") as Node3D
	_builder.add_static_cylinder(geometry, "SootedTowerCore", Vector3(0.0, 126.0, 0.0), 19.0, 252.0, _materials[&"soot_stone"], true, Vector3.ZERO, 24)
	for band: int in 9:
		var angle: float = float(band) * 0.78
		var band_y: float = 14.0 + float(band) * 25.0
		var radius: float = 24.0 + float(band % 2) * 4.0
		_builder.add_static_box(
			geometry, "RouteLedge%02d" % band,
			Vector3(cos(angle) * radius, band_y, sin(angle) * radius),
			Vector3(21.0, 3.0, 10.0),
			_materials[&"clean_stone"] if band not in [3, 6] else _materials[&"cracked_stone"],
			true, Vector3(0.0, -rad_to_deg(angle), 0.0)
		)
		_builder.add_marker(
			routes, "SpiralLanding%02d" % band,
			Vector3(cos(angle) * radius, band_y + 2.0, sin(angle) * radius), &"route_anchor",
			{&"route_id": StringName("spine_landing_%02d" % band)}
		)
	_builder.add_static_box(geometry, "HoldGateShelf", Vector3(0.0, 17.0, -27.0), Vector3(44.0, 4.0, 16.0), _materials[&"clean_stone"], true)
	_builder.add_static_box(geometry, "HoldGateBlocker", Vector3(0.0, 9.0, -22.0), Vector3(38.0, 18.0, 8.0), _materials[&"soot_stone"], true)
	_builder.add_marker(
		sockets, "HoldGateCarryable", Vector3(0.0, 1.0, -35.0), &"carryable_object",
		{&"spawn_id": &"spine_hold_gate_object", &"requirement_id": &"hold"}
	)
	_builder.add_static_box(geometry, "SmolderGapLower", Vector3(24.0, 91.0, 0.0), Vector3(14.0, 4.0, 24.0), _materials[&"clean_stone"], true)
	_builder.add_static_box(geometry, "SmolderGapUpper", Vector3(-24.0, 139.0, 0.0), Vector3(14.0, 4.0, 24.0), _materials[&"clean_stone"], true)
	_builder.add_marker(
		sockets, "SmolderGateUpdraft", Vector3(0.0, 92.0, 0.0), &"updraft_volume",
		{&"socket_size_m": Vector3(24.0, 52.0, 24.0), &"direction": Vector3.UP, &"strength": 22.0, &"requirement_id": &"smolder"}
	)
	_builder.add_static_box(geometry, "CisternHotGate", Vector3(-22.0, 184.0, 0.0), Vector3(10.0, 44.0, 42.0), _materials[&"ember_stone"], true)
	_builder.add_marker(
		sockets, "CisternGateDouseTarget", Vector3(-27.0, 184.0, 0.0), &"water_douse_target",
		{&"socket_size_m": Vector3(12.0, 46.0, 44.0), &"requirement_id": &"cistern"}
	)
	_builder.add_static_cylinder(geometry, "SummitCrown", Vector3(0.0, 264.0, 0.0), 13.0, 24.0, _materials[&"clean_stone"], true, Vector3.ZERO, 20)
	_builder.add_static_box(geometry, "SummitPlatform", Vector3(0.0, 252.0, 0.0), Vector3(58.0, 4.0, 58.0), _materials[&"clean_stone"], true)
	_builder.add_marker(sockets, "DistrictTrigger", Vector3(0.0, 3.0, -52.0), &"district_trigger", {&"socket_size_m": Vector3(80.0, 30.0, 45.0), &"district_id": &"spine"})
	_builder.add_marker(routes, "SpineBase", Vector3(0.0, 2.0, -42.0), &"route_anchor", {&"route_id": &"spine_base"})
	_builder.add_marker(routes, "Summit", Vector3(0.0, 256.0, 0.0), &"route_anchor", {&"route_id": &"summit"})
	_builder.add_box_occluder(geometry, "SpineOccluder", Vector3(0.0, 126.0, 0.0), Vector3(34.0, 252.0, 34.0))
	_builder.add_visibility_notifier(geometry, AABB(Vector3(-45.0, 0.0, -45.0), Vector3(90.0, 280.0, 90.0)))
	_add_m6_content(root, &"spine")
	_add_m9_gameplay(root, &"spine")
	return _save_and_free(root, DistrictContract.SPINE_PATH)


func _build_dark() -> Error:
	var root: Node3D = _make_root(&"dark", Vector3(0.0, -34.0, 430.0), "dark")
	root.set_meta(&"separate_streamed_area", true)
	root.set_meta(&"open_world_loaded", false)
	var geometry: Node3D = root.get_node("WorldGeometry") as Node3D
	var dressing: Node3D = root.get_node("Dressing") as Node3D
	var sockets: Node3D = root.get_node("GameplaySockets") as Node3D
	var routes: Node3D = root.get_node("RouteMarkers") as Node3D
	_builder.add_static_box(geometry, "DarkFloor", Vector3(0.0, -2.0, 0.0), Vector3(210.0, 4.0, 180.0), _materials[&"wet_stone"], true)
	_builder.add_static_box(geometry, "DarkCeiling", Vector3(0.0, 28.0, 0.0), Vector3(210.0, 5.0, 180.0), _materials[&"soot_stone"], true)
	var wall_data: Array[Dictionary] = [
		{"p": Vector3(-105.0, 13.0, 0.0), "s": Vector3(6.0, 30.0, 180.0)},
		{"p": Vector3(105.0, 13.0, 0.0), "s": Vector3(6.0, 30.0, 180.0)},
		{"p": Vector3(0.0, 13.0, -90.0), "s": Vector3(210.0, 30.0, 6.0)},
		{"p": Vector3(0.0, 13.0, 90.0), "s": Vector3(210.0, 30.0, 6.0)},
		{"p": Vector3(-38.0, 10.0, -42.0), "s": Vector3(6.0, 24.0, 88.0)},
		{"p": Vector3(34.0, 10.0, 38.0), "s": Vector3(6.0, 24.0, 96.0)},
		{"p": Vector3(68.0, 10.0, -18.0), "s": Vector3(68.0, 24.0, 6.0)},
		{"p": Vector3(-70.0, 10.0, 26.0), "s": Vector3(64.0, 24.0, 6.0)},
	]
	for wall_index: int in wall_data.size():
		var data: Dictionary = wall_data[wall_index]
		_builder.add_static_box(geometry, "DarkWall%02d" % wall_index, data["p"] as Vector3, data["s"] as Vector3, _materials[&"wet_stone"], true)
	for alcove: int in 7:
		var side: float = -1.0 if alcove % 2 == 0 else 1.0
		var alcove_position: Vector3 = Vector3(side * (82.0 - float(alcove % 3) * 12.0), 7.0, -65.0 + float(alcove) * 21.0)
		_builder.add_visual_box(dressing, "HidingAlcoveLintel%02d" % alcove, alcove_position + Vector3(0.0, 8.0, 0.0), Vector3(22.0, 4.0, 12.0), _materials[&"clean_stone"])
		_builder.add_marker(routes, "HidingAlcove%02d" % alcove, alcove_position, &"hiding_place", {&"route_id": StringName("hide_%02d" % alcove)})
	var spawn_positions: Array[Vector3] = [
		Vector3(-72.0, 0.0, -58.0), Vector3(72.0, 0.0, -48.0), Vector3(-12.0, 0.0, -10.0),
		Vector3(58.0, 0.0, 46.0), Vector3(-62.0, 0.0, 62.0), Vector3(0.0, 0.0, 74.0),
	]
	for spawn_index: int in spawn_positions.size():
		_builder.add_marker(
			sockets, "DrownedSpawn%02d" % spawn_index, spawn_positions[spawn_index], &"drowned_spawn",
			{&"spawn_id": StringName("dark_drowned_%02d" % spawn_index), &"district_id": &"dark"}
		)
	_builder.add_marker(sockets, "CarriedLightStart", Vector3(0.0, 2.0, -72.0), &"fire_source", {&"spawn_id": &"dark_carried_light"})
	_builder.add_fire_visual(dressing, "CarriedLightStartVisual", Vector3(0.0, 2.0, -72.0), 0.62)
	_builder.add_marker(sockets, "DistrictTrigger", Vector3(0.0, 4.0, -82.0), &"district_trigger", {&"socket_size_m": Vector3(50.0, 20.0, 18.0), &"district_id": &"dark"})
	_builder.add_marker(routes, "Entry", Vector3(0.0, 1.0, -78.0), &"route_anchor", {&"route_id": &"entry"})
	_builder.add_marker(routes, "Figurehead", Vector3(0.0, 2.0, 72.0), &"route_anchor", {&"route_id": &"figurehead"})
	_builder.add_marker(routes, "EmergencyHide", Vector3(-88.0, 1.0, 70.0), &"hiding_place", {&"route_id": &"final_hide"})
	_builder.add_box_occluder(geometry, "DarkCoreOccluder", Vector3(0.0, 12.0, 0.0), Vector3(190.0, 24.0, 160.0))
	_builder.add_visibility_notifier(geometry, AABB(Vector3(-108.0, -5.0, -93.0), Vector3(216.0, 38.0, 186.0)))
	_add_m6_content(root, &"dark")
	_add_m9_gameplay(root, &"dark")
	return _save_and_free(root, DistrictContract.DARK_PATH)


func _add_m9_gameplay(root: Node3D, district_id: StringName) -> void:
	var sockets: Node3D = root.get_node("GameplaySockets") as Node3D
	for child: Node in sockets.get_children():
		if not child is Marker3D:
			continue
		var socket: Marker3D = child as Marker3D
		var socket_type: StringName = socket.get_meta(&"socket_type", &"") as StringName
		if not PREFAB_PATHS.has(socket_type):
			continue
		var prefab_path: String = str(PREFAB_PATHS[socket_type])
		if not ResourceLoader.exists(prefab_path):
			socket.set_meta(&"m9_missing_prefab", prefab_path)
			continue
		var instance: Node3D = _instance_prefab(
			root, socket, prefab_path, _m9_instance_name(socket_type)
		)
		match socket_type:
			&"campfire":
				_set_enum_property(
					instance, &"initial_flame", "EMBERS" if district_id == &"cistern" else "LIT"
				)
				_set_optional_property(instance, &"checkpoint_id", socket.get_meta(&"checkpoint_id", &""))
			&"cairn_entrance":
				_set_required_property(instance, &"cairn_id", socket.get_meta(&"cairn_id", &""))
				var target_path: String = str(socket.get_meta(&"target_scene_path", ""))
				_set_required_property(instance, &"target_scene", load(target_path) as PackedScene)
			&"crew_fragment":
				_set_required_property(instance, &"fragment_id", socket.get_meta(&"fragment_id", &""))
			&"district_trigger":
				_set_required_property(instance, &"district_id", socket.get_meta(&"district_id", &""))
				_resize_volume(instance, socket.get_meta(&"socket_size_m", Vector3.ONE) as Vector3)
			&"heat_volume":
				_set_required_property(instance, &"damage_per_second", float(socket.get_meta(&"strength", 1.0)))
				_resize_volume(instance, socket.get_meta(&"socket_size_m", Vector3.ONE) as Vector3)
			&"ocean_kill_volume":
				_resize_volume(instance, socket.get_meta(&"socket_size_m", Vector3.ONE) as Vector3)
			&"water_current":
				var direction: Vector3 = socket.get_meta(&"direction", Vector3.ZERO) as Vector3
				var strength: float = float(socket.get_meta(&"strength", 0.0))
				_set_required_property(instance, &"current", direction * strength)
				_resize_volume(instance, socket.get_meta(&"socket_size_m", Vector3.ONE) as Vector3)
			&"water_volume":
				_set_required_property(instance, &"current", Vector3.ZERO)
				_resize_volume(instance, socket.get_meta(&"socket_size_m", Vector3.ONE) as Vector3)

	match district_id:
		&"shallows":
			var build_site: Node3D = root.get_node("WorldGeometry/SetuBuildSite") as Node3D
			var setu: Node3D = _instance_prefab(root, build_site, SETU_PATH, "Setu")
			setu.position = Vector3(0.0, 4.0, 18.0)
			_add_component_pickup(root, "RouteMarkers/HoldTrial", &"hull")
		&"ember_quarter":
			_instance_prefab(root, sockets, FIRE_GRID_PATH, "FireGrid")
			_add_ember_flammables(root)
			_add_component_pickup(root, "RouteMarkers/SmolderTrial", &"mast")
		&"cistern":
			_add_component_pickup(root, "RouteMarkers/CisternTrial", &"sail")
		&"spine":
			_add_component_pickup(root, "RouteMarkers/Summit", &"keel")
		&"dark":
			var figurehead_marker: Node3D = root.get_node("RouteMarkers/Figurehead") as Node3D
			_instance_prefab(root, figurehead_marker, FIGUREHEAD_PATH, "FigureheadCarryable")


func _m9_instance_name(socket_type: StringName) -> String:
	match socket_type:
		&"crew_fragment":
			return "FragmentPickup"
		&"drowned_spawn":
			return "Drowned"
		&"water_current", &"water_volume":
			return "WaterVolume"
		_:
			return str(socket_type).to_pascal_case()


func _instance_prefab(
	root: Node3D, parent: Node, prefab_path: String, node_name: String
) -> Node3D:
	var packed: PackedScene = load(prefab_path) as PackedScene
	assert(packed != null, "Missing M9 prefab: %s" % prefab_path)
	var instance: Node3D = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	assert(instance != null, "M9 prefab root must be Node3D: %s" % prefab_path)
	instance.name = node_name
	instance.set_meta(&"m9_prefab_path", prefab_path)
	parent.add_child(instance)
	instance.owner = root
	root.set_editable_instance(instance, true)
	return instance


func _add_component_pickup(root: Node3D, marker_path: String, component_id: StringName) -> void:
	var marker: Node3D = root.get_node(marker_path) as Node3D
	var pickup: Node3D = _instance_prefab(
		root, marker, COMPONENT_PICKUP_PATH, "ComponentPickup_" + str(component_id).to_pascal_case()
	)
	_set_required_property(pickup, &"component_id", component_id)


func _add_ember_flammables(root: Node3D) -> void:
	var geometry: Node3D = root.get_node("WorldGeometry") as Node3D
	for building_child: Node in geometry.get_children():
		if not building_child.name.begins_with("BurntBuilding"):
			continue
		for prop_child: Node in building_child.get_children():
			if not prop_child is StaticBody3D:
				continue
			var prop: StaticBody3D = prop_child as StaticBody3D
			prop.collision_layer |= 1 << 10
			var size: Vector3 = Vector3(2.0, 2.0, 2.0)
			var collision: CollisionShape3D = prop.get_node_or_null("CollisionShape") as CollisionShape3D
			if collision != null and collision.shape is BoxShape3D:
				size = (collision.shape as BoxShape3D).size
			var flammable: Node = Node.new()
			flammable.name = "Flammable"
			flammable.set_script(load(FLAMMABLE_SCRIPT_PATH) as Script)
			flammable.set(&"fuel", 20.0 if prop.name.begins_with("CollapsedRoof") else 12.0)
			flammable.set(&"size", size)
			flammable.set(&"mobile", false)
			flammable.set_meta(&"m9_gameplay_type", &"flammable")
			prop.add_child(flammable)


func _resize_volume(instance: Node3D, size: Vector3) -> void:
	var collision_nodes: Array[Node] = instance.find_children("*", "CollisionShape3D", true, false)
	assert(not collision_nodes.is_empty(), "%s has no CollisionShape3D" % instance.scene_file_path)
	var collision: CollisionShape3D = collision_nodes[0] as CollisionShape3D
	assert(collision.shape is BoxShape3D, "%s volume collision must use BoxShape3D" % instance.scene_file_path)
	var shape: BoxShape3D = (collision.shape as BoxShape3D).duplicate() as BoxShape3D
	shape.size = size
	collision.shape = shape


func _set_required_property(node: Node, property_name: StringName, value: Variant) -> void:
	assert(_has_property(node, property_name), "%s is missing exported %s" % [node.scene_file_path, property_name])
	node.set(property_name, value)


func _set_optional_property(node: Node, property_name: StringName, value: Variant) -> void:
	if _has_property(node, property_name):
		node.set(property_name, value)


func _set_enum_property(node: Node, property_name: StringName, option_name: String) -> void:
	for property: Dictionary in node.get_property_list():
		if property.get(&"name", &"") != property_name:
			continue
		assert(int(property.get(&"hint", PROPERTY_HINT_NONE)) == PROPERTY_HINT_ENUM)
		var options: PackedStringArray = str(property.get(&"hint_string", "")).split(",")
		for option_index: int in options.size():
			var option: String = options[option_index]
			var fields: PackedStringArray = option.split(":")
			if fields[0].strip_edges().to_upper() != option_name.to_upper():
				continue
			var value: int = int(fields[1]) if fields.size() > 1 else option_index
			node.set(property_name, value)
			return
	assert(false, "%s enum has no %s option" % [property_name, option_name])


func _has_property(node: Node, property_name: StringName) -> bool:
	for property: Dictionary in node.get_property_list():
		if property.get(&"name", &"") == property_name:
			return true
	return false


func _make_materials() -> Dictionary:
	return {
		&"clean_stone": _builder.make_stylized_material("mat_clean_stone_grip_solid", Color(0.31, 0.32, 0.30), 0.94, 0.0, 0.0, 0.08, 0.20),
		&"cracked_stone": _builder.make_stylized_material("mat_fire_cracked_stone_grip_crumbling", Color(0.20, 0.20, 0.18), 0.97, 0.0, 0.0, 0.30, 0.18),
		&"wet_stone": _builder.make_stylized_material("mat_wet_stone_grip_slick", Color(0.075, 0.115, 0.105), 0.62, 0.0, 0.82, 0.10, 0.08),
		&"soot_stone": _builder.make_stylized_material("mat_soot_stone_grip_slick", Color(0.095, 0.095, 0.085), 0.90, 0.0, 0.10, 0.78, 0.10),
		&"ember_stone": _builder.make_stylized_material("mat_ember_stone_grip_hot", Color(0.20, 0.055, 0.012), 0.78, 0.0, 0.0, 0.45, 0.05, 2.6),
		&"charred_timber": _builder.make_stylized_material("mat_charred_timber_grip_crumbling", Color(0.075, 0.072, 0.062), 0.92, 0.0, 0.0, 0.86, 0.12),
		&"unburnt_timber": _builder.make_stylized_material("mat_unburnt_timber_grip_solid", Color(0.17, 0.16, 0.12), 0.86, 0.0, 0.0, 0.22, 0.10),
		&"ash_earth": _builder.make_stylized_material("mat_ash_earth_grip_solid", Color(0.16, 0.17, 0.16), 0.98, 0.0, 0.0, 0.08, 0.52),
		&"bone_canvas": _builder.make_stylized_material("mat_bone_canvas_grip_solid", Color(0.58, 0.56, 0.48), 0.90, 0.0, 0.0, 0.18, 0.10),
		&"salvage_iron": _builder.make_stylized_material("mat_salvage_iron_grip_solid", Color(0.19, 0.24, 0.23), 0.50, 0.70, 0.18, 0.18, 0.05),
		&"shellfish": _builder.make_stylized_material("mat_shellfish_grip_solid", Color(0.40, 0.51, 0.47), 0.72, 0.0, 0.30, 0.0, 0.02),
		&"ashroot": _builder.make_stylized_material("mat_ashroot_grip_solid", Color(0.24, 0.27, 0.21), 0.95, 0.0, 0.0, 0.16, 0.18),
		&"charwood_fruit": _builder.make_stylized_material("mat_charwood_fruit_grip_solid", Color(0.34, 0.075, 0.012), 0.76, 0.0, 0.0, 0.18, 0.05, 0.65),
		&"blind_fish": _builder.make_stylized_material("mat_blind_fish_grip_solid", Color(0.43, 0.50, 0.48), 0.64, 0.0, 0.28, 0.0, 0.03),
		&"keffer_cloth": _builder.make_stylized_material("mat_keffer_cloth_grip_solid", Color(0.13, 0.14, 0.13), 0.94, 0.0, 0.0, 0.30, 0.14),
		&"cistern_water": _builder.make_water_scenery_material("mat_cistern_water_scenery_grip_slick", 0.22),
	}


func _add_m6_content(root: Node3D, district_id: StringName) -> void:
	var geometry: Node3D = root.get_node("WorldGeometry") as Node3D
	var dressing: Node3D = root.get_node("Dressing") as Node3D
	var sockets: Node3D = root.get_node("GameplaySockets") as Node3D
	for cairn: Dictionary in ContentContract.entries_for_district(ContentContract.CAIRNS, district_id):
		var cairn_id: StringName = cairn["id"] as StringName
		var position: Vector3 = cairn["position"] as Vector3
		_builder.add_marker(
			sockets, "CairnEntrance_" + str(cairn_id).to_pascal_case(), position, &"cairn_entrance",
			{&"cairn_id": cairn_id, &"target_scene_path": str(cairn["path"]), &"district_id": district_id}
		)
		var entrance: Node3D = Node3D.new()
		entrance.name = "CairnDoor_" + str(cairn_id).to_pascal_case()
		entrance.position = position
		geometry.add_child(entrance)
		_builder.add_static_box(entrance, "LeftPillar", Vector3(-3.2, 3.5, 0.0), Vector3(2.2, 7.0, 2.2), _materials[&"clean_stone"], true)
		_builder.add_static_box(entrance, "RightPillar", Vector3(3.2, 3.5, 0.0), Vector3(2.2, 7.0, 2.2), _materials[&"clean_stone"], true)
		_builder.add_static_box(entrance, "Lintel", Vector3(0.0, 7.2, 0.0), Vector3(8.6, 2.0, 2.2), _materials[&"cracked_stone"], true)
	for fragment: Dictionary in ContentContract.entries_for_district(ContentContract.CREW_FRAGMENTS, district_id):
		var fragment_id: StringName = fragment["id"] as StringName
		var position: Vector3 = fragment["position"] as Vector3
		_builder.add_marker(
			sockets, "CrewFragment_" + str(fragment_id).to_pascal_case(), position, &"crew_fragment",
			{&"fragment_id": fragment_id, &"memory_object": str(fragment["object"]), &"memory_text": str(fragment["text"]), &"district_id": district_id}
		)
		_builder.add_visual_box(dressing, "FragmentProxy_" + str(fragment_id).to_pascal_case(), position + Vector3(0.0, 0.35, 0.0), Vector3(1.4, 0.5, 0.6), _materials[&"bone_canvas"], Vector3(12.0, float(fragment_id.hash() % 180), 8.0))
	for salvage: Dictionary in ContentContract.entries_for_district(ContentContract.SALVAGE, district_id):
		var placement_id: StringName = salvage["id"] as StringName
		var salvage_id: StringName = salvage["salvage_id"] as StringName
		var position: Vector3 = salvage["position"] as Vector3
		_builder.add_marker(
			sockets, "Salvage_" + str(placement_id).to_pascal_case(), position, &"salvage_pickup",
			{&"placement_id": placement_id, &"salvage_id": salvage_id, &"district_id": district_id}
		)
		var material: Material = _materials[&"salvage_iron"] if salvage_id == &"iron" else (_materials[&"bone_canvas"] if salvage_id == &"canvas" else _materials[&"unburnt_timber"])
		_builder.add_visual_box(dressing, "SalvageProxy_" + str(placement_id).to_pascal_case(), position + Vector3(0.0, 0.5, 0.0), Vector3(2.6, 0.8, 1.4), material, Vector3(0.0, float(placement_id.hash() % 180), 0.0))
	for ingredient: Dictionary in ContentContract.entries_for_district(ContentContract.INGREDIENTS, district_id):
		var placement_id: StringName = ingredient["id"] as StringName
		var ingredient_id: StringName = ingredient["ingredient_id"] as StringName
		var position: Vector3 = ingredient["position"] as Vector3
		_builder.add_marker(
			sockets, "Ingredient_" + str(placement_id).to_pascal_case(), position, &"ingredient_pickup",
			{&"placement_id": placement_id, &"ingredient_id": ingredient_id, &"district_id": district_id}
		)
		var material_key: StringName = &"shellfish"
		if ingredient_id == &"ashroot":
			material_key = &"ashroot"
		elif ingredient_id == &"charwood_fruit":
			material_key = &"charwood_fruit"
		elif ingredient_id == &"blind_fish":
			material_key = &"blind_fish"
		_builder.add_visual_box(dressing, "IngredientProxy_" + str(placement_id).to_pascal_case(), position + Vector3(0.0, 0.3, 0.0), Vector3(0.7, 0.5, 0.7), _materials[material_key], Vector3(0.0, float(placement_id.hash() % 180), 0.0))
	for campfire: Dictionary in ContentContract.entries_for_district(ContentContract.CAMPFIRES, district_id):
		var checkpoint_id: StringName = campfire["id"] as StringName
		var position: Vector3 = campfire["position"] as Vector3
		_builder.add_marker(
			sockets, "Campfire_" + str(checkpoint_id).to_pascal_case(), position, &"campfire",
			{&"checkpoint_id": checkpoint_id, &"district_id": district_id}
		)
		if ResourceLoader.exists(str(PREFAB_PATHS[&"campfire"])):
			continue
		var proxy: Node3D = Node3D.new()
		proxy.name = "CampfireProxy_" + str(checkpoint_id).to_pascal_case()
		proxy.position = position
		dressing.add_child(proxy)
		_builder.add_visual_box(proxy, "LogA", Vector3(0.0, 0.3, 0.0), Vector3(3.0, 0.55, 0.55), _materials[&"charred_timber"], Vector3(0.0, 35.0, 0.0))
		_builder.add_visual_box(proxy, "LogB", Vector3(0.0, 0.3, 0.0), Vector3(3.0, 0.55, 0.55), _materials[&"charred_timber"], Vector3(0.0, -35.0, 0.0))
		_builder.add_visual_box(proxy, "EmberBed", Vector3(0.0, 0.22, 0.0), Vector3(1.4, 0.3, 1.4), _materials[&"ember_stone"])
		_builder.add_fire_visual(proxy, "FireVisual", Vector3(0.0, 0.25, 0.0), 0.78)
	if district_id == &"shallows":
		_add_keffer(dressing, sockets)


func _add_keffer(dressing: Node3D, sockets: Node3D) -> void:
	var keffer: Node3D = Node3D.new()
	keffer.name = "Keffer"
	keffer.position = Vector3(-135.0, 5.0, 68.0)
	keffer.set_meta(&"is_merchant", false)
	keffer.set_meta(&"dialogue_lines", ContentContract.KEFFER_DIALOGUE)
	keffer.set_meta(&"handout_item_id", &"tidepool_shellfish")
	keffer.set_meta(&"handout_cooldown_s", 120.0)
	dressing.add_child(keffer)
	_builder.add_visual_box(keffer, "Body", Vector3(0.0, 0.95, 0.0), Vector3(1.25, 1.8, 0.85), _materials[&"keffer_cloth"])
	_builder.add_visual_box(keffer, "Hood", Vector3(0.0, 2.15, 0.0), Vector3(1.05, 0.9, 0.9), _materials[&"keffer_cloth"], Vector3(0.0, 8.0, 0.0))
	_builder.add_visual_box(keffer, "Pack", Vector3(0.0, 1.0, 0.62), Vector3(0.95, 1.2, 0.5), _materials[&"bone_canvas"])
	_builder.add_marker(
		sockets, "KefferInteraction", keffer.position, &"keffer_interaction",
		{&"dialogue_lines": ContentContract.KEFFER_DIALOGUE, &"handout_item_id": &"tidepool_shellfish", &"handout_cooldown_s": 120.0, &"is_merchant": false}
	)


func _make_open_world_root(district_id: StringName) -> Node3D:
	var data: Dictionary = DistrictContract.OPEN_WORLD_DISTRICTS[district_id] as Dictionary
	var root: Node3D = _make_root(district_id, data["center"] as Vector3, str(district_id))
	root.set_meta(&"stream_center", data["center"])
	root.set_meta(&"stream_load_radius_m", data["load_radius_m"])
	root.set_meta(&"stream_unload_radius_m", data["unload_radius_m"])
	root.set_meta(&"open_world_loaded", true)
	return root


func _make_root(district_id: StringName, position: Vector3, budget_profile: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = (str(district_id) + "_district").to_pascal_case()
	root.position = position
	root.set_meta(&"district_id", district_id)
	root.set_meta(&"budget_profile", budget_profile)
	for group_name: String in ["WorldGeometry", "Dressing", "GameplaySockets", "RouteMarkers"]:
		var group: Node3D = Node3D.new()
		group.name = group_name
		root.add_child(group)
	return root


func _add_wrecked_hull(parent: Node3D, node_name: String, position: Vector3, yaw_degrees: float, scale_value: float) -> void:
	var hull: Node3D = Node3D.new()
	hull.name = node_name
	hull.position = position
	hull.rotation_degrees.y = yaw_degrees
	hull.scale = Vector3.ONE * scale_value
	parent.add_child(hull)
	_builder.add_static_box(hull, "Keel", Vector3(0.0, 0.0, 0.0), Vector3(5.0, 5.0, 58.0), _materials[&"charred_timber"], true, Vector3(0.0, 0.0, 8.0))
	for rib: int in 7:
		_builder.add_static_cylinder(
			hull, "Rib%02d" % rib, Vector3(0.0, 5.0, -24.0 + float(rib) * 8.0),
			1.5, 36.0 - absf(float(rib) - 3.0) * 3.0, _materials[&"charred_timber"], true,
			Vector3(0.0, 0.0, 78.0 + (float(rib % 2) * 7.0)), 10
		)
	_builder.add_visual_box(hull, "TornCanvas", Vector3(4.0, 8.0, -5.0), Vector3(1.0, 17.0, 29.0), _materials[&"bone_canvas"], Vector3(0.0, 0.0, 14.0))


func _add_burnt_building(parent: Node3D, node_name: String, position: Vector3, height: float, variant: int) -> void:
	var building: Node3D = Node3D.new()
	building.name = node_name
	building.position = position
	parent.add_child(building)
	var width: float = 34.0 + float(variant % 2) * 8.0
	var depth: float = 30.0 + float((variant + 1) % 3) * 5.0
	for corner_x: int in 2:
		for corner_z: int in 2:
			_builder.add_static_box(
				building, "FramePost%d%d" % [corner_x, corner_z],
				Vector3((-0.5 + float(corner_x)) * width, height * 0.5, (-0.5 + float(corner_z)) * depth),
				Vector3(4.5, height, 4.5), _materials[&"charred_timber"], true,
				Vector3(float((variant + corner_x) % 3) * 3.0, 0.0, float((variant + corner_z) % 2) * 4.0)
			)
	_builder.add_static_box(building, "NorthBeam", Vector3(0.0, height - 3.0, -depth * 0.5), Vector3(width + 5.0, 4.0, 4.0), _materials[&"charred_timber"], true, Vector3(0.0, 0.0, float(variant % 3) * 5.0))
	_builder.add_static_box(building, "SouthBeam", Vector3(0.0, height - 5.0, depth * 0.5), Vector3(width + 5.0, 4.0, 4.0), _materials[&"charred_timber"], true, Vector3(0.0, 0.0, -float((variant + 1) % 3) * 6.0))
	# Roofs are separate authored props rather than one huge FireGrid footprint.
	# Each tile registers on its own streamed frame, keeping spread behavior while
	# avoiding a single thousands-of-cells registration spike.
	var roof_rotation: Vector3 = Vector3(
		8.0 + float(variant) * 2.0, float(variant * 13), 16.0
	)
	var roof_basis: Basis = Basis.from_euler(Vector3(
		deg_to_rad(roof_rotation.x), deg_to_rad(roof_rotation.y), deg_to_rad(roof_rotation.z)
	))
	var roof_tile_size: Vector3 = Vector3(width / 3.0, 2.5, depth / 2.0)
	for roof_x: int in 3:
		for roof_z: int in 2:
			var local_offset: Vector3 = Vector3(
				(float(roof_x) - 1.0) * roof_tile_size.x,
				0.0,
				(float(roof_z) - 0.5) * roof_tile_size.z
			)
			_builder.add_static_box(
				building,
				"CollapsedRoof%d%d" % [roof_x, roof_z],
				Vector3(0.0, height * 0.55, 0.0) + roof_basis * local_offset,
				roof_tile_size,
				_materials[&"cracked_stone"],
				true,
				roof_rotation
			)


func _save_and_free(root: Node3D, path: String) -> Error:
	var save_error: Error = _builder.finish_scene(root, path)
	root.free()
	return save_error


func _save_segmented_and_free(
	root: Node3D, path: String, district_id: StringName
) -> Error:
	_builder.prepare_scene(root)
	var segment_paths: PackedStringArray = PackedStringArray()
	var parent_paths: Array[NodePath] = []
	var segment_root_path: String = path.get_base_dir() + "/stream_segments"
	var segment_index: int = 0
	for container_name: String in SEGMENT_CONTAINER_NAMES:
		var container: Node = root.get_node_or_null(container_name)
		if container == null:
			continue
		var children: Array[Node] = []
		for child: Node in container.get_children():
			# Occlusion resources remain in the lightweight host. Creating their
			# renderer RIDs from worker-loaded segments is unsafe on D3D12.
			if child is OccluderInstance3D or child is VisibleOnScreenNotifier3D:
				continue
			children.append(child)
		if container_name == "GameplaySockets":
			children.sort_custom(_gameplay_segment_before)
		var batch_start: int = 0
		while batch_start < children.size():
			var segment: Node3D = Node3D.new()
			segment.name = "DistrictSegment%02d" % segment_index
			var nested_units: Array[Dictionary] = []
			var batch_end: int = mini(batch_start + SEGMENT_BATCH_SIZE, children.size())
			for child_index: int in range(batch_start, batch_end):
				var child: Node = children[child_index]
				if (
					district_id == &"ember_quarter"
					and container_name == "WorldGeometry"
					and child.name.begins_with("BurntBuilding")
				):
					for nested_child: Node in child.get_children():
						var nested_owned: Array[Node] = _nodes_owned_by(nested_child, root)
						for owned_node: Node in nested_owned:
							owned_node.owner = null
						child.remove_child(nested_child)
						nested_units.append({
							"node": nested_child,
							"owned": nested_owned,
							"parent": NodePath("../WorldGeometry/" + str(child.name)),
						})
				var originally_owned: Array[Node] = _nodes_owned_by(child, root)
				for owned_node: Node in originally_owned:
					owned_node.owner = null
				container.remove_child(child)
				segment.add_child(child)
				for owned_node: Node in originally_owned:
					owned_node.owner = segment
			var segment_error: Error = _write_segment(
				segment, segment_root_path, district_id, segment_index,
				NodePath("../" + container_name), segment_paths, parent_paths
			)
			if segment_error != OK:
				root.free()
				return segment_error
			segment_index += 1
			for nested_unit: Dictionary in nested_units:
				var nested_segment: Node3D = Node3D.new()
				nested_segment.name = "DistrictSegment%02d" % segment_index
				var nested_node: Node = nested_unit["node"] as Node
				nested_segment.add_child(nested_node)
				for owned_node: Node in nested_unit["owned"] as Array[Node]:
					owned_node.owner = nested_segment
				segment_error = _write_segment(
					nested_segment, segment_root_path, district_id, segment_index,
					nested_unit["parent"] as NodePath, segment_paths, parent_paths
				)
				if segment_error != OK:
					root.free()
					return segment_error
				segment_index += 1
			batch_start = batch_end

	var loader: Node = Node.new()
	loader.name = "DistrictSegmentLoader"
	loader.set_script(DistrictSegmentLoaderScript)
	loader.set(&"segment_paths", segment_paths)
	loader.set(&"segment_parent_paths", parent_paths)
	root.add_child(loader)
	loader.owner = root
	root.set_meta(&"district_streaming_ready", false)
	var save_error: Error = _builder.save_prepared_scene(root, path)
	root.free()
	return save_error


func _nodes_owned_by(node: Node, scene_owner: Node) -> Array[Node]:
	var owned: Array[Node] = []
	if node.owner == scene_owner:
		owned.append(node)
	for child: Node in node.get_children():
		owned.append_array(_nodes_owned_by(child, scene_owner))
	return owned


func _write_segment(
	segment: Node3D,
	segment_root_path: String,
	district_id: StringName,
	segment_index: int,
	parent_path: NodePath,
	segment_paths: PackedStringArray,
	parent_paths: Array[NodePath]
) -> Error:
	var segment_path: String = "%s/%s_%02d.tscn" % [
		segment_root_path, district_id, segment_index,
	]
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(segment)
	if pack_error != OK:
		segment.free()
		return pack_error
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(segment_root_path))
	var segment_error: Error = ResourceSaver.save(packed, segment_path)
	segment.free()
	if segment_error == OK:
		segment_paths.append(segment_path)
		parent_paths.append(parent_path)
	return segment_error


func _gameplay_segment_before(left: Node, right: Node) -> bool:
	if left.name == &"FireGrid":
		return true
	if right.name == &"FireGrid":
		return false
	return left.get_index() < right.get_index()
