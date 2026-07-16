extends GutTest
## M7 fire: deterministic spread (faster upward), fuel exhaustion, the
## char transition (charred grip becomes CRUMBLING), hard caps on burning
## cells and emitters, dousing, updrafts over big burns, contact and
## radiant damage, and the brand. The grid's step() is driven manually so
## nothing here depends on wall-clock time.

const GRID_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/fire_grid.tscn")
const BRAND_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/brand.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _grid: FireGrid


func before_each() -> void:
	_grid = GRID_SCENE.instantiate()
	add_child_autofree(_grid)


func _make_flammable(pos: Vector3, fuel: float = 10.0, size: Vector3 = Vector3.ONE) -> Flammable:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1024  # layer 11 `flammable`
	var flammable: Flammable = Flammable.new()
	flammable.fuel = fuel
	flammable.size = size
	body.add_child(flammable)
	add_child_autofree(body)
	body.global_position = pos
	return flammable


func _step(times: int, delta: float = 0.5) -> void:
	for i: int in times:
		_grid.step(delta)


func test_ignite_and_burning_grip_is_hot() -> void:
	var wood: Flammable = _make_flammable(Vector3(0.5, 0.5, 0.5))
	await get_tree().process_frame
	watch_signals(EventBus)
	assert_true(wood.ignite(), "an unburnt flammable ignites")
	assert_true(wood.is_burning())
	assert_eq(_grid.burning_cell_count(), 1)
	assert_signal_emitted(EventBus, "fire_started")
	assert_eq(Grip.class_from_collision(wood.body), Grip.Class.HOT,
			"a burning surface reports HOT regardless of material")


func test_fire_spreads_to_adjacent_flammable() -> void:
	var source: Flammable = _make_flammable(Vector3(0.5, 0.5, 0.5), 30.0)
	var target: Flammable = _make_flammable(Vector3(1.5, 0.5, 0.5), 30.0)
	await get_tree().process_frame
	source.ignite()
	_step(4)
	assert_false(target.is_burning(), "heat must accumulate before ignition")
	_step(4)
	assert_true(target.is_burning(), "fire spreads by proximity and contact")


func test_fire_spreads_faster_upward_than_downward() -> void:
	var middle: Flammable = _make_flammable(Vector3(0.5, 0.5, 0.5), 30.0)
	var above: Flammable = _make_flammable(Vector3(0.5, 1.5, 0.5), 30.0)
	var below: Flammable = _make_flammable(Vector3(0.5, -0.5, 0.5), 30.0)
	await get_tree().process_frame
	middle.ignite()
	_step(4)
	assert_true(above.is_burning(), "upward spread is fast (M7)")
	assert_false(below.is_burning(), "downward spread lags")
	_step(16)
	assert_true(below.is_burning(), "downward spread still happens, eventually")


func test_fuel_exhaustion_chars_permanently() -> void:
	var wood: Flammable = _make_flammable(Vector3(0.5, 0.5, 0.5), 1.0)
	await get_tree().process_frame
	watch_signals(EventBus)
	wood.ignite()
	_step(3)
	assert_eq(wood.state, Flammable.State.CHARRED, "spent fuel chars the object")
	assert_eq(_grid.burning_cell_count(), 0, "the fire died with the fuel")
	assert_signal_emitted(EventBus, "fire_extinguished")
	assert_true(wood.body.is_in_group(Grip.CHARRED_GROUP))
	assert_false(wood.body.is_in_group(Grip.BURNING_GROUP))
	assert_eq(Grip.class_from_collision(wood.body), Grip.Class.CRUMBLING,
			"a charred surface's grip class becomes CRUMBLING (M7)")
	assert_false(wood.ignite(), "charred is permanent; it never burns again")


func test_hard_cap_on_burning_cells() -> void:
	_grid.max_burning_cells = 1
	var first: Flammable = _make_flammable(Vector3(0.5, 0.5, 0.5), 30.0)
	var second: Flammable = _make_flammable(Vector3(4.5, 0.5, 0.5))
	var third: Flammable = _make_flammable(Vector3(1.5, 0.5, 0.5))
	await get_tree().process_frame
	assert_true(first.ignite())
	assert_false(second.ignite(), "the cap refuses direct ignition")
	_step(20)
	assert_false(third.is_burning(), "the cap refuses spread too")
	assert_eq(_grid.burning_cell_count(), 1, "a hard cap, not a budget")


func test_douse_extinguishes_and_blocks_reignition_while_wet() -> void:
	var wood: Flammable = _make_flammable(Vector3(0.5, 0.5, 0.5), 10.0)
	wood.doused_duration = 1.0
	await get_tree().process_frame
	wood.ignite()
	_step(2)
	watch_signals(EventBus)
	_grid.douse_area(Vector3(0.5, 0.5, 0.5), 1.5)
	assert_false(wood.is_burning(), "fire dies in water (M7)")
	assert_eq(wood.state, Flammable.State.UNBURNT, "doused is not charred")
	assert_between(wood.fuel, 8.0, 9.5, "unburnt fuel remains")
	assert_signal_emitted(EventBus, "fire_extinguished")
	assert_false(wood.ignite(), "a doused surface refuses fire")
	_step(3)
	assert_true(wood.ignite(), "dry again, it burns again")


func test_updraft_vents_above_a_big_burn() -> void:
	_grid.updraft_min_cells = 2
	var beam: Flammable = _make_flammable(Vector3(1.0, 0.5, 0.5), 60.0, Vector3(2, 1, 1))
	await get_tree().process_frame
	assert_eq(beam.cells.size(), 2, "a 2m beam occupies two cells")
	beam.ignite()
	_step(2)
	assert_eq(_grid.active_updraft_count(), 0, "one burning cell is not enough")
	_step(8)
	assert_eq(_grid.active_updraft_count(), 1, "a big enough burn vents an updraft")
	var volume: UpdraftVolume = null
	for child: Node in _grid.get_children():
		if child is UpdraftVolume and (child as UpdraftVolume).is_active():
			volume = child as UpdraftVolume
	assert_not_null(volume)
	assert_gt(volume.global_position.y, 1.0, "the updraft sits above the burn")
	assert_eq(volume.collision_layer, 2048, "updraft volumes live on layer 12")


func test_hard_cap_on_emitters() -> void:
	_grid.max_fire_emitters = 1
	var first: Flammable = _make_flammable(Vector3(0.5, 0.5, 0.5))
	var second: Flammable = _make_flammable(Vector3(4.5, 0.5, 0.5))
	await get_tree().process_frame
	first.ignite()
	second.ignite()
	_step(2)
	assert_eq(_grid.burning_cell_count(), 2)
	assert_eq(_grid.live_emitter_count(), 1, "emitter cap holds under more fire")


func test_fire_damages_on_contact_and_radiates_heat() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	player.global_position = Vector3.ZERO
	var near: Flammable = _make_flammable(Vector3(0.5, 0.5, 0.5))
	await get_tree().process_frame
	near.ignite()
	_step(2)
	var after_contact: float = player.health.current_hearts
	assert_lt(after_contact, 3.0, "fire damages on contact")
	near.body.queue_free()
	_grid.unregister_flammable(near)
	var far: Flammable = _make_flammable(Vector3(2.5, 0.5, 0.5))
	await get_tree().process_frame
	far.ignite()
	_step(2)
	assert_lt(player.health.current_hearts, after_contact, "fire radiates ambient heat")


func test_brand_is_loud_and_visible_while_lit() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(10, 1, 10)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	add_child_autofree(floor_body)
	floor_body.position = Vector3(0, -0.5, 0)
	var brand: Brand = BRAND_SCENE.instantiate()
	add_child_autofree(brand)
	brand.global_position = Vector3(0.5, 0.5, 0.5)
	await get_tree().process_frame
	assert_false(brand.is_lit())
	watch_signals(EventBus)
	assert_true(brand.light(), "a brand can be lit")
	assert_true(brand.is_lit())
	assert_true((brand.get_node("Light") as OmniLight3D).visible, "carried fire is visible")
	await wait_physics_frames(70)
	assert_signal_emitted(EventBus, "sound_emitted")
	assert_true(brand.is_lit(), "a lit brand keeps burning")
	assert_eq(brand.collision_layer, 1048, "carryable | interactable | flammable")
