extends RefCounted

const ISLAND_SIZE_M: Vector2 = Vector2(1100.0, 1100.0)
const CHUNK_SIZE_M: float = 220.0
const CHUNK_COUNT: Vector2i = Vector2i(5, 5)
const GRID_RESOLUTION: int = 65
const MINIMUM_HEIGHT_M: float = -12.0
const MAXIMUM_HEIGHT_M: float = 82.0
const OCEAN_HEIGHT_M: float = 0.0
const LOAD_RADIUS_M: float = 360.0
const UNLOAD_RADIUS_M: float = 460.0
const SPINE_BASE: Vector3 = Vector3(0.0, 68.0, 430.0)
const SPINE_TOP: Vector3 = Vector3(0.0, 320.0, 430.0)

const DISTRICT_ANCHORS: Dictionary = {
	&"shallows": Vector3(0.0, 5.0, -440.0),
	&"terraces": Vector3(-330.0, 50.0, 0.0),
	&"ember_quarter": Vector3(250.0, 54.0, 80.0),
	&"cistern": Vector3(250.0, 18.0, 80.0),
	&"spine": SPINE_BASE,
	&"dark": Vector3(0.0, 20.0, 430.0),
}

const STANDABLE_PADS: Array[Dictionary] = [
	{"id": &"shallows", "center": Vector2(0.0, -410.0), "radius_m": 95.0, "height_m": 4.0},
	{"id": &"arrival", "center": Vector2(0.0, -485.0), "radius_m": 38.0, "height_m": 2.5},
	{"id": &"crossroads", "center": Vector2(0.0, -130.0), "radius_m": 52.0, "height_m": 47.0},
	{"id": &"terraces", "center": Vector2(-330.0, 0.0), "radius_m": 68.0, "height_m": 50.0},
	{"id": &"ember", "center": Vector2(250.0, 80.0), "radius_m": 105.0, "height_m": 54.0},
	{"id": &"spine_approach", "center": Vector2(0.0, 330.0), "radius_m": 58.0, "height_m": 61.0},
	{"id": &"spine_foundation", "center": Vector2(0.0, 430.0), "radius_m": 52.0, "height_m": 68.0},
]


static func chunk_path(grid_coordinate: Vector2i) -> String:
	return "res://scenes/levels/lanka/chunks/chunk_%d_%d.tscn" % [
		grid_coordinate.x, grid_coordinate.y
	]


static func chunk_center(grid_coordinate: Vector2i) -> Vector2:
	var half_count: Vector2 = Vector2(CHUNK_COUNT - Vector2i.ONE) * 0.5
	return (Vector2(grid_coordinate) - half_count) * CHUNK_SIZE_M


static func all_chunk_coordinates() -> Array[Vector2i]:
	var coordinates: Array[Vector2i] = []
	for row: int in CHUNK_COUNT.y:
		for column: int in CHUNK_COUNT.x:
			coordinates.append(Vector2i(column, row))
	return coordinates


static func budget_profile_for_center(center: Vector2) -> String:
	if center.y <= -330.0:
		return "shallows"
	if center.x <= -220.0:
		return "terraces"
	if center.y >= 330.0:
		return "spine"
	if center.x >= 110.0:
		return "ember_quarter"
	return "default"
