extends SceneTree

const BuilderScript: Script = preload("res://src/tools/terrain_pipeline/district_scene_builder.gd")
const ContentContract: Script = preload("res://scenes/levels/lanka/lanka_content_contract.gd")

var _builder: RefCounted
var _materials: Dictionary


func _initialize() -> void:
	_builder = BuilderScript.new() as RefCounted
	_materials = {
		&"solid": _builder.make_material("mat_cairn_stone_grip_solid", Color(0.24, 0.26, 0.25), 0.95),
		&"crumbling": _builder.make_material("mat_cairn_cracked_grip_crumbling", Color(0.17, 0.16, 0.15), 0.97),
		&"slick": _builder.make_material("mat_cairn_wet_grip_slick", Color(0.07, 0.10, 0.10), 0.62),
		&"hot": _builder.make_material("mat_cairn_ember_grip_hot", Color(0.68, 0.14, 0.025), 0.8),
		&"timber": _builder.make_material("mat_cairn_timber_grip_solid", Color(0.21, 0.13, 0.065), 0.9),
	}
	for cairn: Dictionary in ContentContract.CAIRNS:
		var build_error: Error = _build_cairn(cairn)
		if build_error != OK:
			printerr("Unable to build Cairn %s: %s" % [cairn["id"], error_string(build_error)])
			quit(1)
			return
	print("Wrote exactly eight Lanka M6 Cairn scenes")
	quit(0)


func _build_cairn(data: Dictionary) -> Error:
	var cairn_id: StringName = data["id"] as StringName
	var root: Node3D = Node3D.new()
	root.name = ("cairn_" + str(cairn_id)).to_pascal_case()
	root.set_meta(&"cairn_id", cairn_id)
	root.set_meta(&"district_id", data["district_id"])
	root.set_meta(&"taught_mechanic", data["mechanic"])
	root.set_meta(&"single_room", true)
	root.set_meta(&"heart_piece_reward", 1)
	root.set_meta(&"budget_profile", "cairn")
	var geometry: Node3D = Node3D.new()
	geometry.name = "WorldGeometry"
	root.add_child(geometry)
	var sockets: Node3D = Node3D.new()
	sockets.name = "GameplaySockets"
	root.add_child(sockets)
	var routes: Node3D = Node3D.new()
	routes.name = "RouteMarkers"
	root.add_child(routes)
	_add_room_shell(geometry)
	_add_puzzle(geometry, sockets, data["mechanic"] as StringName)
	_builder.add_marker(routes, "Entry", Vector3(0.0, 1.0, 34.0), &"route_anchor", {&"route_id": &"entry"})
	_builder.add_marker(routes, "Exit", Vector3(0.0, 1.0, 38.0), &"route_anchor", {&"route_id": &"exit"})
	_builder.add_marker(
		sockets, "HeartPieceReward", Vector3(0.0, 3.0, -29.0), &"heart_piece_reward",
		{&"cairn_id": cairn_id, &"heart_piece_amount": 1}
	)
	_builder.add_box_occluder(geometry, "RoomOccluder", Vector3(0.0, 10.0, 0.0), Vector3(58.0, 20.0, 68.0))
	_builder.add_visibility_notifier(geometry, AABB(Vector3(-32.0, -3.0, -38.0), Vector3(64.0, 30.0, 76.0)))
	var save_error: Error = _builder.finish_scene(root, str(data["path"]))
	root.free()
	return save_error


func _add_room_shell(geometry: Node3D) -> void:
	_builder.add_static_box(geometry, "Floor", Vector3(0.0, -1.5, 0.0), Vector3(60.0, 3.0, 72.0), _materials[&"solid"], true)
	_builder.add_static_box(geometry, "WestWall", Vector3(-30.0, 10.0, 0.0), Vector3(4.0, 23.0, 72.0), _materials[&"solid"], true)
	_builder.add_static_box(geometry, "EastWall", Vector3(30.0, 10.0, 0.0), Vector3(4.0, 23.0, 72.0), _materials[&"solid"], true)
	_builder.add_static_box(geometry, "NorthWall", Vector3(0.0, 10.0, -36.0), Vector3(60.0, 23.0, 4.0), _materials[&"solid"], true)
	_builder.add_static_box(geometry, "SouthDoorLeft", Vector3(-18.0, 10.0, 36.0), Vector3(24.0, 23.0, 4.0), _materials[&"solid"], true)
	_builder.add_static_box(geometry, "SouthDoorRight", Vector3(18.0, 10.0, 36.0), Vector3(24.0, 23.0, 4.0), _materials[&"solid"], true)
	_builder.add_static_box(geometry, "RewardPlinth", Vector3(0.0, 1.0, -29.0), Vector3(7.0, 2.0, 7.0), _materials[&"solid"], true)


func _add_puzzle(geometry: Node3D, sockets: Node3D, mechanic: StringName) -> void:
	match mechanic:
		&"carry_stack":
			_builder.add_static_box(geometry, "HighShelf", Vector3(0.0, 8.0, -12.0), Vector3(22.0, 3.0, 14.0), _materials[&"solid"], true)
			for index: int in 3:
				_builder.add_marker(sockets, "StackObject%02d" % index, Vector3(-9.0 + float(index) * 9.0, 1.0, 20.0), &"carryable_object", {&"spawn_id": StringName("cairn_stack_%02d" % index)})
		&"carry_counterweight":
			_builder.add_static_box(geometry, "BalanceBridge", Vector3(0.0, 5.0, -4.0), Vector3(38.0, 2.0, 8.0), _materials[&"solid"], true, Vector3(0.0, 0.0, 12.0))
			for index: int in 2:
				_builder.add_marker(sockets, "Counterweight%02d" % index, Vector3(-14.0 + float(index) * 28.0, 1.0, 22.0), &"carryable_object", {&"spawn_id": StringName("cairn_weight_%02d" % index)})
		&"grip_route":
			var materials: Array[Material] = [_materials[&"solid"], _materials[&"slick"], _materials[&"crumbling"], _materials[&"solid"]]
			for index: int in 4:
				_builder.add_static_box(geometry, "GripPillar%02d" % index, Vector3(-18.0 + float(index) * 12.0, 5.0 + float(index) * 2.5, 4.0 - float(index) * 7.0), Vector3(7.0, 10.0 + float(index) * 5.0, 7.0), materials[index], true)
		&"crumbling_timing":
			for index: int in 6:
				_builder.add_static_box(geometry, "CrumblingLedge%02d" % index, Vector3(-20.0 + float(index) * 8.0, 2.0 + float(index) * 2.2, 18.0 - float(index) * 8.0), Vector3(7.0, 2.0, 7.0), _materials[&"crumbling"], true)
		&"fire_fuel":
			for index: int in 4:
				var position: Vector3 = Vector3(-18.0 + float(index) * 12.0, 1.0, 14.0 - float(index) * 9.0)
				_builder.add_static_box(geometry, "FuelPedestal%02d" % index, position, Vector3(7.0, 2.0, 7.0), _materials[&"hot"] if index > 1 else _materials[&"solid"], true)
				_builder.add_marker(sockets, "FuelSource%02d" % index, position + Vector3(0.0, 2.0, 0.0), &"fire_source", {&"spawn_id": StringName("cairn_fuel_%02d" % index)})
		&"updraft_glide":
			_builder.add_static_box(geometry, "LaunchPlatform", Vector3(0.0, 2.0, 18.0), Vector3(20.0, 3.0, 14.0), _materials[&"solid"], true)
			_builder.add_static_box(geometry, "LandingPlatform", Vector3(0.0, 15.0, -18.0), Vector3(20.0, 3.0, 14.0), _materials[&"solid"], true)
			_builder.add_marker(sockets, "Updraft", Vector3(0.0, 2.0, 0.0), &"updraft_volume", {&"socket_size_m": Vector3(16.0, 18.0, 16.0), &"direction": Vector3.UP, &"strength": 16.0})
		&"water_current":
			_builder.add_static_box(geometry, "CurrentBankWest", Vector3(-22.0, 1.0, 0.0), Vector3(12.0, 3.0, 56.0), _materials[&"slick"], true)
			_builder.add_static_box(geometry, "CurrentBankEast", Vector3(22.0, 1.0, 0.0), Vector3(12.0, 3.0, 56.0), _materials[&"slick"], true)
			_builder.add_marker(sockets, "WaterVolume", Vector3(0.0, 1.0, 0.0), &"water_volume", {&"socket_size_m": Vector3(32.0, 8.0, 56.0)})
			_builder.add_marker(sockets, "Current", Vector3(0.0, 1.0, 0.0), &"water_current", {&"socket_size_m": Vector3(30.0, 7.0, 52.0), &"direction": Vector3(0.7, 0.0, -0.7).normalized(), &"strength": 5.0})
		&"carry_flame":
			_builder.add_static_box(geometry, "DryWalkway", Vector3(-16.0, 1.0, 0.0), Vector3(10.0, 3.0, 56.0), _materials[&"solid"], true)
			_builder.add_marker(sockets, "FloodedChannel", Vector3(8.0, 1.0, 0.0), &"water_volume", {&"socket_size_m": Vector3(30.0, 7.0, 56.0)})
			_builder.add_marker(sockets, "CarriedFlame", Vector3(-16.0, 3.0, 25.0), &"fire_source", {&"spawn_id": &"cairn_carried_flame"})
