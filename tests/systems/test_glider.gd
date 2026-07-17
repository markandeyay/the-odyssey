extends GutTest
## M13 glider: a fall-management tool, not a flight game (ARCHITECTURE
## §14). Deploy gates (sailcloth key item, airborne, hands free), capped
## descent, updraft lift, auto-stow on landing, and the placeable vent.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _player: Player
var _glider: GliderController


func before_each() -> void:
	Inventory.clear()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.position = Vector3(0, 40, 0)
	_glider = _player.get_node("GliderController") as GliderController


func after_all() -> void:
	Inventory.clear()


func _give_sailcloth() -> void:
	Inventory.add_key_item(GliderController.GLIDER_ITEM_ID)


func _add_floor(y: float = -0.5) -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, y, 0)
	add_child_autofree(floor_body)


func _add_updraft(center: Vector3, radius: float = 8.0, height: float = 80.0) -> UpdraftVolume:
	var updraft: UpdraftVolume = UpdraftVolume.new()
	add_child_autofree(updraft)
	updraft.configure(center, radius, height)
	return updraft


func test_glider_is_a_unique_key_item() -> void:
	var def: ItemDef = ItemRegistry.get_def(&"glider")
	assert_not_null(def, "the glider item def exists")
	assert_eq(def.category, ItemDef.Category.KEY, "the sailcloth is a key item")
	Inventory.add_item(&"glider")
	assert_true(Inventory.has_key_item(&"glider"), "pickup routes to the key item area")
	assert_eq(Inventory.count_of(&"glider"), 0, "never occupies the 40 slots")


func test_cannot_deploy_without_the_sailcloth() -> void:
	await wait_physics_frames(2)
	assert_false(_glider.try_deploy(), "no sailcloth, no glide")
	assert_false(_player.is_gliding())


func test_deploys_airborne_with_the_sailcloth() -> void:
	_give_sailcloth()
	await wait_physics_frames(2)
	watch_signals(_glider)
	assert_true(_glider.try_deploy())
	assert_true(_player.is_gliding())
	assert_signal_emitted(_glider, "deployed")


func test_cannot_deploy_on_the_ground() -> void:
	_add_floor()
	_give_sailcloth()
	_player.position = Vector3(0, 0.5, 0)
	await wait_physics_frames(30)
	assert_true(_player.is_on_floor(), "precondition: standing")
	assert_false(_glider.try_deploy(), "gliding starts in the air")


func test_cannot_deploy_while_carrying() -> void:
	_give_sailcloth()
	await wait_physics_frames(2)
	_player.is_carrying = true
	assert_false(_glider.try_deploy(), "cannot glide while carrying (M13)")


func test_picking_up_a_carry_mid_glide_stows() -> void:
	_give_sailcloth()
	await wait_physics_frames(2)
	assert_true(_glider.try_deploy())
	_player.is_carrying = true
	await wait_physics_frames(2)
	assert_false(_glider.active, "carrying forces the canvas away")


func test_glide_caps_descent() -> void:
	_give_sailcloth()
	await wait_physics_frames(30)
	assert_lt(_player.velocity.y, -3.0, "precondition: free fall is faster than a glide")
	assert_true(_glider.try_deploy())
	await wait_physics_frames(60)
	assert_almost_eq(_player.velocity.y, -_glider.glide_fall_speed, 0.3,
			"descent settles at the glide terminal speed")


func test_a_glide_landing_never_hurts() -> void:
	assert_eq(_player.fall_damage_hearts(_glider.glide_fall_speed), 0.0,
			"glide terminal speed is below the fall damage threshold")


func test_updraft_lifts_a_deployed_glider() -> void:
	_give_sailcloth()
	_add_updraft(Vector3(0, 30, 0))
	await wait_physics_frames(3)
	assert_true(_glider.try_deploy())
	var start_y: float = _player.global_position.y
	await wait_physics_frames(40)
	assert_gt(_player.velocity.y, 0.0, "the updraft lifts a deployed glider")
	assert_gt(_player.global_position.y, start_y, "Nau rises")


func test_updraft_does_nothing_without_the_glider() -> void:
	_add_updraft(Vector3(0, 30, 0))
	await wait_physics_frames(30)
	assert_false(_player.is_gliding())
	assert_lt(_player.velocity.y, 0.0, "updrafts are inert until the glider reads them")


func test_landing_stows_the_glider() -> void:
	_add_floor()
	_give_sailcloth()
	_player.position = Vector3(0, 2.5, 0)
	await wait_physics_frames(2)
	assert_true(_glider.try_deploy())
	watch_signals(_glider)
	await wait_physics_frames(120)
	assert_true(_player.is_on_floor(), "precondition: landed")
	assert_false(_glider.active, "landing stows the canvas")
	assert_signal_emitted_with_parameters(_glider, "stowed", [&"landed"])


func test_canvas_shows_only_while_gliding() -> void:
	_give_sailcloth()
	var canvas: MeshInstance3D = _player.get_node("Visual/GliderCanvas") as MeshInstance3D
	await wait_physics_frames(2)
	assert_false(canvas.visible, "canvas hidden while stowed")
	assert_true(_glider.try_deploy())
	assert_true(canvas.visible, "canvas visible while deployed")
	_glider.stow(&"toggled")
	assert_false(canvas.visible, "canvas hidden again after stowing")


func test_pooled_updrafts_start_inert() -> void:
	var updraft: UpdraftVolume = UpdraftVolume.new()
	add_child_autofree(updraft)
	await wait_physics_frames(1)
	assert_false(updraft.is_active(), "fire updrafts wait for the FireGrid")


func test_standing_vent_activates_itself() -> void:
	var vent_scene: PackedScene = load("res://scenes/prefabs/gameplay/updraft_vent.tscn")
	var vent: UpdraftVolume = vent_scene.instantiate() as UpdraftVolume
	add_child_autofree(vent)
	await wait_physics_frames(1)
	assert_true(vent.is_active(), "a placed street vent is live on ready")
	assert_eq(vent.collision_layer, 2048, "vents live on layer 12 `updraft`")


func test_standing_vent_lifts_from_its_base() -> void:
	_give_sailcloth()
	var vent: UpdraftVolume = UpdraftVolume.new()
	vent.standing = true
	vent.radius = 8.0
	vent.height = 80.0
	add_child_autofree(vent)
	vent.position = Vector3.ZERO  # column rises from the origin; player at y 40 is inside
	await wait_physics_frames(3)
	assert_true(_glider.try_deploy())
	await wait_physics_frames(40)
	assert_gt(_player.velocity.y, 0.0, "the vent column lifts riders above its base")


func test_no_stamina_anywhere_near_the_glider() -> void:
	assert_false("stamina" in _glider, "no stamina, ever (ARCHITECTURE §2)")
