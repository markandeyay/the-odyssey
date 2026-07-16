extends RefCounted

const DistrictContract: Script = preload("res://scenes/levels/lanka/lanka_district_contract.gd")
const CLIMBABLE_LAYER: int = 1 << 2
const KNOWN_SOCKET_TYPES: PackedStringArray = [
	"ocean_kill_volume", "district_trigger", "carryable_object", "fire_source",
	"heat_volume", "updraft_volume", "water_volume", "water_current",
	"water_douse_target", "drowned_spawn", "ingredient_habitat", "route_anchor",
	"hiding_place",
]


func validate_districts(district_ids: PackedStringArray) -> Array[String]:
	var issues: Array[String] = []
	for district_id: String in district_ids:
		_validate_district(StringName(district_id), issues)
	return issues


func validate_all() -> Array[String]:
	return validate_districts(PackedStringArray([
		"shallows", "terraces", "ember_quarter", "cistern", "spine", "dark",
	]))


func _validate_district(district_id: StringName, issues: Array[String]) -> void:
	var path: String = _path_for_id(district_id)
	var resource: Resource = ResourceLoader.load(path, "PackedScene")
	if not resource is PackedScene:
		issues.append("%s: unable to load district scene" % path)
		return
	var root: Node3D = (resource as PackedScene).instantiate() as Node3D
	if root == null:
		issues.append("%s: district root must be Node3D" % path)
		return
	if root.get_meta(&"district_id", &"") != district_id:
		issues.append("%s: district_id metadata is incorrect" % path)
	for group_name: String in ["WorldGeometry", "Dressing", "GameplaySockets", "RouteMarkers"]:
		if root.get_node_or_null(group_name) == null:
			issues.append("%s: missing %s" % [path, group_name])
	_validate_sockets(root, path, issues)
	if _count_type(root, "VisibleOnScreenNotifier3D") < 1:
		issues.append("%s: district lacks an expensive-prop visibility notifier" % path)
	match district_id:
		&"shallows":
			_validate_shallows(root, path, issues)
		&"terraces":
			_validate_terraces(root, path, issues)
		&"ember_quarter":
			_validate_ember(root, path, issues)
		&"cistern":
			_validate_cistern(root, path, issues)
		&"spine":
			_validate_spine(root, path, issues)
		&"dark":
			_validate_dark(root, path, issues)
	root.free()


func _validate_sockets(root: Node, path: String, issues: Array[String]) -> void:
	var sockets: Node = root.get_node_or_null("GameplaySockets")
	if sockets == null:
		return
	var markers: Array[Marker3D] = []
	_collect_markers(sockets, markers)
	for marker: Marker3D in markers:
		var socket_type: String = str(marker.get_meta(&"socket_type", &""))
		if socket_type not in KNOWN_SOCKET_TYPES:
			issues.append("%s:%s has unknown socket_type '%s'" % [path, marker.name, socket_type])
		if socket_type.ends_with("volume") and not marker.has_meta(&"socket_size_m"):
			issues.append("%s:%s volume socket lacks socket_size_m" % [path, marker.name])
		if socket_type in ["updraft_volume", "water_current"]:
			if not marker.has_meta(&"direction") or not marker.has_meta(&"strength"):
				issues.append("%s:%s directional socket lacks direction or strength" % [path, marker.name])


func _validate_shallows(root: Node3D, path: String, issues: Array[String]) -> void:
	_expect_count_prefix(root, "SetuStump", 12, path, issues)
	for node_name: String in ["ArrivalWreck", "EasternWreck", "KefferOverturnedHull", "SetuBuildSite"]:
		if _find_name(root, node_name) == null:
			issues.append("%s: missing %s" % [path, node_name])
	var ocean: Marker3D = _find_name(root, "OceanKillVolume") as Marker3D
	if ocean == null or (ocean.get_meta(&"socket_size_m", Vector3.ZERO) as Vector3).z < 500.0:
		issues.append("%s: ocean kill socket does not cover the south waterline" % path)
	var final_stump: Node3D = _find_name(root, "SetuStump11") as Node3D
	if final_stump == null or root.position.z + final_stump.position.z > -740.0:
		issues.append("%s: Setu stumps do not vanish far enough into the sea" % path)
	if _count_type(root, "Area3D") > 0:
		issues.append("%s: Shallows may not use an invisible Area3D wall" % path)


func _validate_terraces(root: Node3D, path: String, issues: Array[String]) -> void:
	_expect_count_prefix(root, "TerraceBed", 6, path, issues)
	_expect_count_prefix(root, "RetainingWall", 6, path, issues)
	if _count_prefix(root, "IrrigationChannel") < 12:
		issues.append("%s: dry irrigation network is incomplete" % path)
	var grip_classes: Dictionary = _grip_classes(root)
	for grip_class: String in ["solid", "crumbling", "slick", "hot"]:
		if not grip_classes.has(grip_class):
			issues.append("%s: climbing gym lacks grip class %s" % [path, grip_class])


func _validate_ember(root: Node3D, path: String, issues: Array[String]) -> void:
	_expect_count_prefix(root, "BurntBuilding", 6, path, issues)
	_expect_socket_count(root, &"fire_source", 7, path, issues)
	_expect_socket_count(root, &"updraft_volume", 3, path, issues)
	_expect_socket_count(root, &"heat_volume", 3, path, issues)
	_expect_socket_count(root, &"ingredient_habitat", 5, path, issues)


func _validate_cistern(root: Node3D, path: String, issues: Array[String]) -> void:
	_expect_count_prefix(root, "ReservoirColumn", 12, path, issues)
	_expect_socket_count(root, &"water_volume", 1, path, issues)
	_expect_socket_count(root, &"water_current", 3, path, issues)
	_expect_socket_count(root, &"ingredient_habitat", 4, path, issues)
	if _find_name(root, "FlameCarryStart") == null:
		issues.append("%s: flame carry route is missing" % path)


func _validate_spine(root: Node3D, path: String, issues: Array[String]) -> void:
	if not bool(root.get_meta(&"persistent_landmark", false)):
		issues.append("%s: Spine is not persistent" % path)
	var requirements: PackedStringArray = root.get_meta(&"convergence_requirements", PackedStringArray()) as PackedStringArray
	if requirements != PackedStringArray(["hold", "smolder", "cistern"]):
		issues.append("%s: Spine convergence requirements are incorrect" % path)
	for socket_name: String in ["HoldGateCarryable", "SmolderGateUpdraft", "CisternGateDouseTarget"]:
		if _find_name(root, socket_name) == null:
			issues.append("%s: missing physical convergence socket %s" % [path, socket_name])
	var tower: StaticBody3D = _find_name(root, "SootedTowerCore") as StaticBody3D
	if tower == null or "_grip_slick" not in _first_material_name(tower):
		issues.append("%s: tower core must be slick to prevent a direct climb skip" % path)
	var summit: Marker3D = _find_name(root, "Summit") as Marker3D
	if summit == null or root.position.y + summit.position.y < 320.0:
		issues.append("%s: summit does not reach the Spine sightline contract" % path)


func _validate_dark(root: Node3D, path: String, issues: Array[String]) -> void:
	if not bool(root.get_meta(&"separate_streamed_area", false)) or bool(root.get_meta(&"open_world_loaded", true)):
		issues.append("%s: The Dark must remain separate from open-world streaming" % path)
	_expect_socket_count(root, &"drowned_spawn", 6, path, issues)
	if _count_socket_type(root, &"hiding_place") < 8:
		issues.append("%s: The Dark lacks required hiding coverage" % path)
	if DistrictContract.desired_open_world_paths(root.position).has(path):
		issues.append("%s: The Dark leaked into open-world district selection" % path)


func _path_for_id(district_id: StringName) -> String:
	if district_id == &"spine":
		return DistrictContract.SPINE_PATH
	if district_id == &"dark":
		return DistrictContract.DARK_PATH
	return DistrictContract.district_path(district_id)


func _expect_count_prefix(root: Node, prefix: String, expected: int, path: String, issues: Array[String]) -> void:
	var actual: int = _count_prefix(root, prefix)
	if actual != expected:
		issues.append("%s: expected %d %s nodes, found %d" % [path, expected, prefix, actual])


func _expect_socket_count(root: Node, socket_type: StringName, expected: int, path: String, issues: Array[String]) -> void:
	var actual: int = _count_socket_type(root, socket_type)
	if actual != expected:
		issues.append("%s: expected %d %s sockets, found %d" % [path, expected, socket_type, actual])


func _count_socket_type(root: Node, socket_type: StringName) -> int:
	var count: int = int(root.get_meta(&"socket_type", &"") == socket_type)
	for child: Node in root.get_children():
		count += _count_socket_type(child, socket_type)
	return count


func _count_prefix(root: Node, prefix: String) -> int:
	var count: int = int(root.name.begins_with(prefix))
	for child: Node in root.get_children():
		count += _count_prefix(child, prefix)
	return count


func _count_type(root: Node, type_name: String) -> int:
	var count: int = int(root.is_class(type_name))
	for child: Node in root.get_children():
		count += _count_type(child, type_name)
	return count


func _find_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child: Node in root.get_children():
		var result: Node = _find_name(child, node_name)
		if result != null:
			return result
	return null


func _collect_markers(root: Node, output: Array[Marker3D]) -> void:
	if root is Marker3D:
		output.append(root as Marker3D)
	for child: Node in root.get_children():
		_collect_markers(child, output)


func _grip_classes(root: Node) -> Dictionary:
	var classes: Dictionary = {}
	_collect_grip_classes(root, classes)
	return classes


func _collect_grip_classes(node: Node, output: Dictionary) -> void:
	if node is CollisionObject3D and (node as CollisionObject3D).collision_layer & CLIMBABLE_LAYER != 0:
		var material_name: String = _first_material_name(node)
		for grip_class: String in ["solid", "crumbling", "slick", "hot"]:
			if material_name.ends_with("_grip_" + grip_class):
				output[grip_class] = true
	for child: Node in node.get_children():
		_collect_grip_classes(child, output)


func _first_material_name(root: Node) -> String:
	if root is MeshInstance3D:
		var mesh_instance: MeshInstance3D = root as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
			var material: Material = mesh_instance.get_active_material(0)
			return material.resource_name if material != null else ""
	for child: Node in root.get_children():
		var result: String = _first_material_name(child)
		if not result.is_empty():
			return result
	return ""
