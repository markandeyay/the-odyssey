extends GutTest
## M8 water and heat: buoyancy, currents, swimming, breath and drowning,
## dousing (fire dies in water; doused surfaces go SLICK), the ocean as a
## kill volume, ambient heat damage, and heat resistance negating it.

const WATER_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/water_volume.tscn")
const HEAT_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/heat_volume.tscn")
const KILL_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/kill_volume.tscn")
const GRID_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/fire_grid.tscn")
const BRAND_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/brand.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")


func before_each() -> void:
	SaveSystem.save_path = "user://test_autosave_water.json"
	SaveSystem.delete_save()


func after_each() -> void:
	SaveSystem.delete_save()
	SaveSystem.save_path = "user://autosave.json"


func _make_water(center: Vector3, size: Vector3) -> WaterVolume:
	var volume: WaterVolume = WATER_SCENE.instantiate()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	(volume.get_node("CollisionShape3D") as CollisionShape3D).shape = box
	add_child_autofree(volume)
	volume.global_position = center
	return volume


func _make_player(at: Vector3) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = at
	return player


func _make_crate(at: Vector3) -> RigidBody3D:
	var crate: RigidBody3D = RigidBody3D.new()
	crate.collision_layer = 8  # carryable
	crate.collision_mask = 1
	crate.mass = 5.0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	shape.shape = box
	crate.add_child(shape)
	add_child_autofree(crate)
	crate.global_position = at
	return crate


func _make_hot_wall(at: Vector3, layer: int = 4) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = layer
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1, 1, 1)
	shape.shape = box
	body.add_child(shape)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = "mat_stone_grip_hot"
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	add_child_autofree(body)
	body.global_position = at
	return body


func test_rigid_bodies_float() -> void:
	_make_water(Vector3.ZERO, Vector3(8, 4, 8))  # surface at y = 2
	var crate: RigidBody3D = _make_crate(Vector3(0, 0, 0))
	await wait_physics_frames(90)
	assert_gt(crate.global_position.y, 0.5, "submerged rigid bodies rise")
	assert_lt(crate.global_position.y, 2.5, "floaters settle near the surface, not orbit")


func test_currents_push() -> void:
	var water: WaterVolume = _make_water(Vector3.ZERO, Vector3(12, 4, 12))
	water.current = Vector3(6, 0, 0)
	var crate: RigidBody3D = _make_crate(Vector3(0, 0, 0))
	await wait_physics_frames(90)
	assert_gt(crate.global_position.x, 0.5, "currents are force volumes")


func test_player_swims_and_floats_to_surface() -> void:
	_make_water(Vector3.ZERO, Vector3(10, 8, 10))  # surface at y = 4
	var player: Player = _make_player(Vector3(0, -2, 0))
	await wait_physics_frames(20)
	assert_true(player.is_swimming(), "deep water means swimming")
	await wait_physics_frames(200)
	var head_y: float = player.global_position.y + player.head_height
	assert_almost_eq(head_y, 4.0, 0.6, "Nau settles with his head at the surface")
	assert_almost_eq(player.health.current_hearts, 3.0, 0.001, "swimming is safe while breath holds")


func test_breath_runs_out_and_drowning_damages() -> void:
	_make_water(Vector3.ZERO, Vector3(10, 16, 10))  # surface at y = 8, deep
	var player: Player = _make_player(Vector3(0, -6, 0))
	player.breath = 0.2
	await wait_physics_frames(120)
	assert_true(player.is_submerged(), "still under: the surface is far above")
	assert_lt(player.breath_fraction(), 0.1, "breath ran out")
	assert_lt(player.health.current_hearts, 3.0, "drowning damages over time")


func test_no_fall_damage_into_deep_water() -> void:
	_make_water(Vector3.ZERO, Vector3(10, 8, 10))  # spans y -4..4
	var player: Player = _make_player(Vector3(0, 15, 0))
	await wait_physics_frames(150)
	assert_true(player.is_in_water(), "the dive ended in the water")
	assert_almost_eq(player.health.current_hearts, 3.0, 0.001,
			"deep water catches a fall that would otherwise hurt")


func test_water_douses_burning_brand() -> void:
	add_child_autofree(GRID_SCENE.instantiate())
	_make_water(Vector3.ZERO, Vector3(8, 4, 8))
	var brand: Brand = BRAND_SCENE.instantiate()
	add_child_autofree(brand)
	brand.global_position = Vector3(0, 6, 0)
	await get_tree().process_frame
	assert_true(brand.light())
	await wait_physics_frames(90)
	assert_false(brand.is_lit(), "fire dies in water")
	assert_true(brand.flammable.is_doused(), "a dunked brand is wet, not charred")


func test_water_extinguishes_burning_static() -> void:
	add_child_autofree(GRID_SCENE.instantiate())
	var water: WaterVolume = _make_water(Vector3.ZERO, Vector3(8, 4, 8))
	water.douse_interval = 0.1
	var wall: StaticBody3D = _make_hot_wall(Vector3(0.5, 0.5, 0.5), 4 | 1024)
	var flammable: Flammable = Flammable.new()
	flammable.fuel = 10.0
	wall.add_child(flammable)
	await get_tree().process_frame
	assert_true(flammable.ignite())
	await wait_physics_frames(20)
	assert_false(flammable.is_burning(), "fire dies under a doused surface")
	assert_eq(flammable.state, Flammable.State.UNBURNT, "doused, not charred")
	assert_true(flammable.is_doused())


func test_doused_surface_converts_hot_to_slick_then_dries() -> void:
	var water: WaterVolume = _make_water(Vector3.ZERO, Vector3(6, 4, 6))
	water.douse_interval = 0.1
	water.dry_time = 0.2
	var wall: StaticBody3D = _make_hot_wall(Vector3(0.5, 0.5, 0.5))
	assert_eq(Grip.class_from_collision(wall), Grip.Class.HOT, "hot material reads HOT while dry")
	await wait_physics_frames(20)
	assert_true(wall.is_in_group(Grip.DOUSED_GROUP))
	assert_eq(Grip.class_from_collision(wall), Grip.Class.SLICK,
			"dousing converts HOT to SLICK — a tradeoff, not a solution")
	wall.global_position += Vector3(100, 0, 0)
	await wait_physics_frames(40)
	assert_false(wall.is_in_group(Grip.DOUSED_GROUP), "surfaces dry out")
	assert_eq(Grip.class_from_collision(wall), Grip.Class.HOT, "and read HOT again")


func test_ocean_kill_volume_kills() -> void:
	var kill: KillVolume = KILL_SCENE.instantiate()
	add_child_autofree(kill)
	kill.global_position = Vector3.ZERO
	var player: Player = _make_player(Vector3(0, 0, 0))
	watch_signals(EventBus)
	await wait_physics_frames(10)
	assert_signal_emitted(EventBus, "player_died", "the ocean is the wall (§2)")


func test_heat_volume_damages_over_time() -> void:
	add_child_autofree(HEAT_SCENE.instantiate())
	var player: Player = _make_player(Vector3.ZERO)
	await wait_physics_frames(90)
	assert_lt(player.health.current_hearts, 3.0, "ambient heat hurts")


func test_heat_resistance_negates_heat_but_not_fire() -> void:
	add_child_autofree(HEAT_SCENE.instantiate())
	var player: Player = _make_player(Vector3.ZERO)
	player.grant_heat_resistance(90.0)
	await wait_physics_frames(90)
	assert_almost_eq(player.health.current_hearts, 3.0, 0.001,
			"heat resistance negates ambient heat")
	player.apply_damage(0.5, &"hot_surface")
	assert_almost_eq(player.health.current_hearts, 3.0, 0.001,
			"heat resistance opens HOT routes (§5)")
	player.apply_damage(0.5, &"fire")
	assert_almost_eq(player.health.current_hearts, 2.5, 0.001,
			"open flame still burns")


func test_heat_resistance_expires() -> void:
	var player: Player = _make_player(Vector3.ZERO)
	player.grant_heat_resistance(0.05)
	assert_true(player.is_heat_resistant())
	await wait_physics_frames(20)
	assert_false(player.is_heat_resistant(), "the buff runs out")
	player.apply_damage(0.5, &"heat")
	assert_almost_eq(player.health.current_hearts, 2.5, 0.001)
