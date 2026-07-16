extends RefCounted

const LankaTerrainContract: Script = preload("res://scenes/levels/lanka/lanka_terrain_contract.gd")

var _broad_noise: FastNoiseLite
var _detail_noise: FastNoiseLite


func _init() -> void:
	_broad_noise = FastNoiseLite.new()
	_broad_noise.seed = 1701
	_broad_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_broad_noise.frequency = 0.0025
	_broad_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_broad_noise.fractal_octaves = 4
	_broad_noise.fractal_gain = 0.45
	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = 9173
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 0.012
	_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail_noise.fractal_octaves = 2
	_detail_noise.fractal_gain = 0.35


func sample_height(world_x: float, world_z: float) -> float:
	var position: Vector2 = Vector2(world_x, world_z)
	var broad_variation: float = _broad_noise.get_noise_2d(world_x, world_z) * 4.5
	var detail_variation: float = _detail_noise.get_noise_2d(world_x, world_z) * 1.25
	var plateau_height: float = 52.0 + broad_variation + detail_variation

	var south_rise: float = smoothstep(-535.0, -235.0, world_z)
	var tidal_height: float = -1.5 + sin(world_x * 0.025) * 0.35 + detail_variation * 0.15
	var height: float = lerpf(tidal_height, plateau_height, south_rise)

	var lateral_inset: float = 550.0 - absf(world_x)
	var lateral_cliff: float = smoothstep(4.0, 58.0, lateral_inset)
	var lateral_floor: float = -8.0 if world_z > -260.0 else -2.5
	height = lerpf(lateral_floor, height, lateral_cliff)
	var north_inset: float = 550.0 - world_z
	height = lerpf(-9.0, height, smoothstep(4.0, 58.0, north_inset))

	if world_x < -135.0 and world_z > -230.0 and world_z < 245.0:
		var terrace_height: float = roundf(height / 5.0) * 5.0
		var terrace_weight: float = smoothstep(-135.0, -210.0, world_x)
		height = lerpf(height, terrace_height, terrace_weight * 0.78)

	for pad: Dictionary in LankaTerrainContract.STANDABLE_PADS:
		height = _stamp_pad(
			height,
			position,
			pad.get("center", Vector2.ZERO) as Vector2,
			float(pad.get("radius_m", 1.0)),
			float(pad.get("height_m", height))
		)

	height = _stamp_corridor(
		height, position, Vector2(0.0, -350.0), Vector2(0.0, -145.0), 75.0, 4.0, 47.0
	)
	height = _stamp_corridor(
		height, position, Vector2(0.0, -130.0), Vector2(-330.0, 0.0), 30.0, 47.0, 50.0
	)
	height = _stamp_corridor(
		height, position, Vector2(0.0, -130.0), Vector2(250.0, 80.0), 30.0, 47.0, 54.0
	)
	height = _stamp_corridor(
		height, position, Vector2(250.0, 80.0), Vector2(0.0, 330.0), 28.0, 54.0, 61.0
	)

	return clampf(
		height,
		LankaTerrainContract.MINIMUM_HEIGHT_M,
		LankaTerrainContract.MAXIMUM_HEIGHT_M
	)


func sample_chunk(grid_coordinate: Vector2i) -> PackedFloat32Array:
	var resolution: int = LankaTerrainContract.GRID_RESOLUTION
	var center: Vector2 = LankaTerrainContract.chunk_center(grid_coordinate)
	var spacing: float = LankaTerrainContract.CHUNK_SIZE_M / float(resolution - 1)
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(resolution * resolution)
	for z: int in resolution:
		for x: int in resolution:
			var world_x: float = center.x - LankaTerrainContract.CHUNK_SIZE_M * 0.5 + float(x) * spacing
			var world_z: float = center.y - LankaTerrainContract.CHUNK_SIZE_M * 0.5 + float(z) * spacing
			heights[z * resolution + x] = sample_height(world_x, world_z)
	return heights


func _stamp_pad(
	current_height: float,
	position: Vector2,
	center: Vector2,
	radius_m: float,
	target_height: float
) -> float:
	var distance: float = position.distance_to(center)
	if distance >= radius_m:
		return current_height
	var weight: float = 1.0 - smoothstep(radius_m * 0.58, radius_m, distance)
	return lerpf(current_height, target_height, weight)


func _stamp_corridor(
	current_height: float,
	position: Vector2,
	start: Vector2,
	end: Vector2,
	half_width_m: float,
	start_height: float,
	end_height: float
) -> float:
	var segment: Vector2 = end - start
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= 0.001:
		return current_height
	var progress: float = clampf((position - start).dot(segment) / segment_length_squared, 0.0, 1.0)
	var nearest: Vector2 = start + segment * progress
	var distance: float = position.distance_to(nearest)
	if distance >= half_width_m:
		return current_height
	var weight: float = 1.0 - smoothstep(half_width_m * 0.55, half_width_m, distance)
	return lerpf(current_height, lerpf(start_height, end_height, progress), weight)
