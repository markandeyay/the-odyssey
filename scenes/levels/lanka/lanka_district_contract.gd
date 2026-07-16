extends RefCounted

const DISTRICT_ROOT: String = "res://scenes/levels/lanka/districts"
const SPINE_PATH: String = DISTRICT_ROOT + "/spine/spine_district.tscn"
const DARK_PATH: String = DISTRICT_ROOT + "/dark/dark_district.tscn"

const OPEN_WORLD_DISTRICTS: Dictionary = {
	&"shallows": {
		"path": DISTRICT_ROOT + "/shallows/shallows_district.tscn",
		"center": Vector3(0.0, 3.0, -410.0),
		"load_radius_m": 290.0,
		"unload_radius_m": 400.0,
	},
	&"terraces": {
		"path": DISTRICT_ROOT + "/terraces/terraces_district.tscn",
		"center": Vector3(-330.0, 50.0, 0.0),
		"load_radius_m": 310.0,
		"unload_radius_m": 420.0,
	},
	&"ember_quarter": {
		"path": DISTRICT_ROOT + "/ember_quarter/ember_quarter_district.tscn",
		"center": Vector3(250.0, 54.0, 80.0),
		"load_radius_m": 320.0,
		"unload_radius_m": 430.0,
	},
	&"cistern": {
		"path": DISTRICT_ROOT + "/cistern/cistern_district.tscn",
		"center": Vector3(250.0, 8.0, 80.0),
		"load_radius_m": 250.0,
		"unload_radius_m": 350.0,
	},
}


static func district_path(district_id: StringName) -> String:
	var data: Dictionary = OPEN_WORLD_DISTRICTS.get(district_id, {}) as Dictionary
	return str(data.get("path", ""))


static func district_center(district_id: StringName) -> Vector3:
	var data: Dictionary = OPEN_WORLD_DISTRICTS.get(district_id, {}) as Dictionary
	return data.get("center", Vector3.ZERO) as Vector3


static func desired_open_world_paths(world_position: Vector3) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	var horizontal_position: Vector2 = Vector2(world_position.x, world_position.z)
	for id_value: Variant in OPEN_WORLD_DISTRICTS:
		var district_id: StringName = id_value as StringName
		var data: Dictionary = OPEN_WORLD_DISTRICTS[district_id] as Dictionary
		var center: Vector3 = data["center"] as Vector3
		if horizontal_position.distance_to(Vector2(center.x, center.z)) <= float(data["load_radius_m"]):
			paths.append(str(data["path"]))
	paths.sort()
	return paths


static func data_for_path(path: String) -> Dictionary:
	for id_value: Variant in OPEN_WORLD_DISTRICTS:
		var data: Dictionary = OPEN_WORLD_DISTRICTS[id_value] as Dictionary
		if str(data.get("path", "")) == path:
			return data
	return {}
