extends SceneTree

const LankaTerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")
const LankaHeightGenerator: Script = preload("res://src/tools/terrain_pipeline/lanka_height_generator.gd")

var _failures: int = 0
var _height_generator: RefCounted


func _initialize() -> void:
	_height_generator = LankaHeightGenerator.new() as RefCounted
	_test_contract_dimensions()
	_test_chunk_seams()
	_test_geographic_profile()
	_test_authored_pads()
	_test_spine_sightlines()
	if _failures == 0:
		print("PASS: Odyssey M4 Lanka height model tests")
	else:
		printerr("FAIL: %d Odyssey M4 height model assertion(s)" % _failures)
	quit(_failures)


func _test_contract_dimensions() -> void:
	_expect(LankaTerrainContract.ISLAND_SIZE_M == Vector2(1100.0, 1100.0), "playable footprint is 1100m square")
	var coordinates: Array[Vector2i] = LankaTerrainContract.all_chunk_coordinates()
	_expect(coordinates.size() == 25, "terrain contract defines 25 stream chunks")
	var paths: Dictionary = {}
	for coordinate: Vector2i in coordinates:
		paths[LankaTerrainContract.chunk_path(coordinate)] = true
	_expect(paths.size() == 25, "every stream chunk has a unique scene path")


func _test_chunk_seams() -> void:
	var resolution: int = LankaTerrainContract.GRID_RESOLUTION
	for row: int in LankaTerrainContract.CHUNK_COUNT.y:
		for column: int in LankaTerrainContract.CHUNK_COUNT.x - 1:
			var left: PackedFloat32Array = _height_generator.sample_chunk(Vector2i(column, row))
			var right: PackedFloat32Array = _height_generator.sample_chunk(Vector2i(column + 1, row))
			for sample: int in resolution:
				_expect(
					is_equal_approx(left[sample * resolution + resolution - 1], right[sample * resolution]),
					"east/west chunk border is seamless"
				)
	for row: int in LankaTerrainContract.CHUNK_COUNT.y - 1:
		for column: int in LankaTerrainContract.CHUNK_COUNT.x:
			var south: PackedFloat32Array = _height_generator.sample_chunk(Vector2i(column, row))
			var north: PackedFloat32Array = _height_generator.sample_chunk(Vector2i(column, row + 1))
			for sample: int in resolution:
				_expect(
					is_equal_approx(south[(resolution - 1) * resolution + sample], north[sample]),
					"north/south chunk border is seamless"
				)


func _test_geographic_profile() -> void:
	_expect(_sample(0.0, -550.0) < LankaTerrainContract.OCEAN_HEIGHT_M, "south edge descends below ocean level")
	_expect(_sample(0.0, -485.0) > 1.5, "arrival pad sits above the tide")
	_expect(_sample(0.0, -260.0) > 20.0, "south approach rises gradually onto the mesa")
	_expect(_sample(-550.0, 0.0) < 0.0, "west edge is a sea cliff")
	_expect(_sample(550.0, 0.0) < 0.0, "east edge is a sea cliff")
	_expect(_sample(0.0, 550.0) < 0.0, "north edge is a sea cliff")
	_expect(_sample(-480.0, 0.0) > 35.0, "west cliff reaches the plateau inside its edge band")
	_expect(_sample(480.0, 0.0) > 35.0, "east cliff reaches the plateau inside its edge band")
	_expect(_sample(0.0, 480.0) > 35.0, "north cliff reaches the plateau inside its edge band")


func _test_authored_pads() -> void:
	for pad: Dictionary in LankaTerrainContract.STANDABLE_PADS:
		var center: Vector2 = pad.get("center", Vector2.ZERO) as Vector2
		var target_height: float = float(pad.get("height_m", 0.0))
		_expect(
			absf(_sample(center.x, center.y) - target_height) <= 0.01,
			"authored pad %s holds its target height" % str(pad.get("id", &"unknown"))
		)


func _test_spine_sightlines() -> void:
	var visible_samples: int = 0
	for z: int in range(-500, 501, 50):
		for x: int in range(-500, 501, 50):
			var ground_height: float = _sample(float(x), float(z))
			if ground_height <= LankaTerrainContract.OCEAN_HEIGHT_M:
				continue
			visible_samples += 1
			_expect(
				_spine_top_visible(Vector3(float(x), ground_height + 1.9, float(z))),
				"Spine top remains visible from playable terrain at (%d, %d)" % [x, z]
			)
	_expect(visible_samples > 300, "sightline audit samples the full playable island")


func _spine_top_visible(vantage: Vector3) -> bool:
	var target: Vector3 = LankaTerrainContract.SPINE_TOP
	for step: int in range(1, 80):
		var progress: float = float(step) / 80.0
		var line_position: Vector3 = vantage.lerp(target, progress)
		var terrain_height: float = _sample(line_position.x, line_position.z)
		if terrain_height > line_position.y - 0.2:
			return false
	return true


func _sample(world_x: float, world_z: float) -> float:
	return float(_height_generator.sample_height(world_x, world_z))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("ASSERTION FAILED: %s" % message)
