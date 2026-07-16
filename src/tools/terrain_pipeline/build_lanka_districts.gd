extends SceneTree

const BuilderScript: Script = preload("res://src/tools/terrain_pipeline/district_scene_builder.gd")
const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")

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
		sockets, "OceanKillVolume", Vector3(0.0, -10.0, -275.0), &"ocean_kill_volume",
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
	_builder.add_visibility_notifier(geometry, AABB(Vector3(-180.0, -15.0, -125.0), Vector3(360.0, 55.0, 250.0)))
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
	return _save_and_free(root, DistrictContract.district_path(&"ember_quarter"))


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
	return _save_and_free(root, DistrictContract.district_path(&"cistern"))


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
	_builder.add_marker(sockets, "DistrictTrigger", Vector3(0.0, 4.0, -82.0), &"district_trigger", {&"socket_size_m": Vector3(50.0, 20.0, 18.0), &"district_id": &"dark"})
	_builder.add_marker(routes, "Entry", Vector3(0.0, 1.0, -78.0), &"route_anchor", {&"route_id": &"entry"})
	_builder.add_marker(routes, "Figurehead", Vector3(0.0, 2.0, 72.0), &"route_anchor", {&"route_id": &"figurehead"})
	_builder.add_marker(routes, "EmergencyHide", Vector3(-88.0, 1.0, 70.0), &"hiding_place", {&"route_id": &"final_hide"})
	_builder.add_box_occluder(geometry, "DarkCoreOccluder", Vector3(0.0, 12.0, 0.0), Vector3(190.0, 24.0, 160.0))
	_builder.add_visibility_notifier(geometry, AABB(Vector3(-108.0, -5.0, -93.0), Vector3(216.0, 38.0, 186.0)))
	return _save_and_free(root, DistrictContract.DARK_PATH)


func _make_materials() -> Dictionary:
	return {
		&"clean_stone": _builder.make_material("mat_clean_stone_grip_solid", Color(0.29, 0.30, 0.28), 0.94),
		&"cracked_stone": _builder.make_material("mat_fire_cracked_stone_grip_crumbling", Color(0.20, 0.19, 0.17), 0.96),
		&"wet_stone": _builder.make_material("mat_wet_stone_grip_slick", Color(0.075, 0.105, 0.10), 0.62),
		&"soot_stone": _builder.make_material("mat_soot_stone_grip_slick", Color(0.055, 0.052, 0.048), 0.9),
		&"ember_stone": _builder.make_material("mat_ember_stone_grip_hot", Color(0.72, 0.16, 0.035), 0.78),
		&"charred_timber": _builder.make_material("mat_charred_timber_grip_crumbling", Color(0.075, 0.055, 0.042), 0.92),
		&"unburnt_timber": _builder.make_material("mat_unburnt_timber_grip_solid", Color(0.24, 0.15, 0.075), 0.86),
		&"ash_earth": _builder.make_material("mat_ash_earth_grip_solid", Color(0.17, 0.17, 0.16), 0.98),
		&"bone_canvas": _builder.make_material("mat_bone_canvas_grip_solid", Color(0.56, 0.54, 0.46), 0.9),
	}


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
	_builder.add_static_box(building, "CollapsedRoof", Vector3(0.0, height * 0.55, 0.0), Vector3(width, 2.5, depth), _materials[&"cracked_stone"], true, Vector3(8.0 + float(variant) * 2.0, float(variant * 13), 16.0))


func _save_and_free(root: Node3D, path: String) -> Error:
	var save_error: Error = _builder.finish_scene(root, path)
	root.free()
	return save_error
