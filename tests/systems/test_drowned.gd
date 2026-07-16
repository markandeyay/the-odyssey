extends GutTest
## M11 the drowned: cannot be hurt (no combat, no attack input), hunt by
## sound (crouch quiet, run loud) and by light (burning things, line of
## sight), lose track when you hide, a leash that keeps them in The Dark,
## and contact = damage + a knockback that separates Nau from his light.

const DROWNED_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/drowned.tscn")
const BRAND_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/brand.tscn")
const GRID_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/fire_grid.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")


func _make_floor(size: float = 60.0) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(size, 1, size)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.position = Vector3(0, -0.5, 0)


func _make_drowned(at: Vector3) -> Drowned:
	var drowned: Drowned = DROWNED_SCENE.instantiate()
	add_child_autofree(drowned)
	drowned.global_position = at
	drowned._home = at
	return drowned


func _make_lit_brand(at: Vector3) -> Brand:
	var brand: Brand = BRAND_SCENE.instantiate()
	add_child_autofree(brand)
	brand.global_position = at
	return brand


func test_cannot_be_hurt_and_no_attack_input() -> void:
	var drowned: Drowned = _make_drowned(Vector3.ZERO)
	assert_false(drowned.has_method("apply_damage"), "the drowned cannot be hurt (§10)")
	assert_false("health" in drowned, "no health, no combat, ever")
	for action: StringName in InputMap.get_actions():
		var name: String = String(action).to_lower()
		assert_false(
			name.contains("attack") or name.contains("weapon") or name.contains("strike"),
			"there is no attack input (§10): found %s" % action
		)
	assert_eq(drowned.collision_layer, 256, "drowned live on layer 9")


func test_hears_near_sound_and_investigates() -> void:
	_make_floor()
	var drowned: Drowned = _make_drowned(Vector3.ZERO)
	EventBus.sound_emitted.emit(Vector3(5, 0, 0), 6.0)
	assert_eq(drowned.state, Drowned.State.INVESTIGATE, "a sound inside its radius is heard")
	var far: Drowned = _make_drowned(Vector3(0, 0, 30))
	EventBus.sound_emitted.emit(Vector3(5, 0, 0), 6.0)
	assert_eq(far.state, Drowned.State.LURK, "loudness is a radius; beyond it, silence")


func test_leash_keeps_them_in_the_dark() -> void:
	_make_floor()
	var drowned: Drowned = _make_drowned(Vector3.ZERO)
	drowned.leash_radius = 10.0
	EventBus.sound_emitted.emit(Vector3(15, 0, 0), 100.0)
	assert_eq(drowned.state, Drowned.State.LURK,
			"stimuli outside the leash are ignored: they never leave The Dark")


func test_hunts_visible_light() -> void:
	_make_floor()
	add_child_autofree(GRID_SCENE.instantiate())
	var brand: Brand = _make_lit_brand(Vector3(0, 0.5, 0))
	var drowned: Drowned = _make_drowned(Vector3(10, 0, 0))
	await get_tree().process_frame
	assert_true(brand.light())
	await wait_physics_frames(90)
	assert_eq(drowned.state, Drowned.State.HUNT, "carried fire is a beacon")
	assert_lt(drowned.global_position.x, 9.0, "and it closes in")


func test_wall_blocks_sight() -> void:
	_make_floor()
	add_child_autofree(GRID_SCENE.instantiate())
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1, 6, 8)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	wall.global_position = Vector3(5, 3, 0)
	var brand: Brand = _make_lit_brand(Vector3(0, 0.5, 0))
	var drowned: Drowned = _make_drowned(Vector3(10, 0, 0))
	await get_tree().process_frame
	assert_true(brand.light())
	await wait_physics_frames(60)
	assert_eq(drowned.state, Drowned.State.LURK, "line of sight is required; hide behind things")


func test_loses_track_when_light_dies() -> void:
	_make_floor()
	var grid: FireGrid = GRID_SCENE.instantiate()
	add_child_autofree(grid)
	var brand: Brand = _make_lit_brand(Vector3(0, 0.5, 0))
	var drowned: Drowned = _make_drowned(Vector3(8, 0, 0))
	drowned.lose_sight_time = 0.2
	drowned.search_time = 0.3
	await get_tree().process_frame
	assert_true(brand.light())
	await wait_physics_frames(40)
	assert_eq(drowned.state, Drowned.State.HUNT)
	grid.douse_flammable(brand.flammable)
	await wait_physics_frames(80)
	assert_eq(drowned.state, Drowned.State.LURK,
			"break line of sight and go quiet: they lose track")


func test_contact_damages_and_separates_nau_from_his_light() -> void:
	_make_floor()
	add_child_autofree(GRID_SCENE.instantiate())
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = Vector3(0.5, 0, 0)
	var brand: Brand = _make_lit_brand(Vector3(0.5, 1, 0))
	await get_tree().process_frame
	assert_true(brand.light())
	var carry: CarryController = player.get_node("CarryController") as CarryController
	assert_true(carry.pick_up(brand))
	var drowned: Drowned = _make_drowned(Vector3.ZERO)
	await wait_physics_frames(20)
	assert_almost_eq(player.health.current_hearts, 2.0, 0.001,
			"contact costs one heart, not instant death (§10)")
	assert_false(player.health.is_dead)
	assert_null(player.carried_body(), "the knockback separates Nau from his light")
	assert_true(brand.is_lit(), "the dropped brand still burns — go get it, with them around it")


func test_running_is_loud() -> void:
	_make_floor()
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = Vector3.ZERO
	watch_signals(EventBus)
	Input.action_press(&"move_forward")
	await wait_physics_frames(80)
	Input.action_release(&"move_forward")
	assert_signal_emitted(EventBus, "sound_emitted", "footsteps make noise")
	var params: Array = get_signal_parameters(EventBus, "sound_emitted")
	assert_almost_eq(float(params[1]), player.run_loudness, 0.001, "running is loud")


func test_crouching_is_quiet() -> void:
	_make_floor()
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = Vector3.ZERO
	player.set_crouching(true)
	watch_signals(EventBus)
	Input.action_press(&"move_forward")
	await wait_physics_frames(80)
	Input.action_release(&"move_forward")
	assert_signal_emit_count(EventBus, "sound_emitted", 0, "crouch is quiet (§10)")
