extends GutTest
## M4 interaction: the Interactable component, raycast targeting with
## prompts, pickups into inventory, and add_item stacking rules.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/prefabs/gameplay/item_pickup.tscn")

var _player: Player


func before_each() -> void:
	Inventory.clear()
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(30, 1, 30)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -0.5, 0)
	add_child_autofree(floor_body)

	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.position = Vector3.ZERO


func _spawn_pickup(id: StringName, label: String, count: int, at: Vector3) -> ItemPickup:
	var pickup: ItemPickup = PICKUP_SCENE.instantiate()
	pickup.item_id = id
	pickup.display_name = label
	pickup.count = count
	pickup.position = at
	add_child_autofree(pickup)
	return pickup


func test_interactable_component_emits_on_interact() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 16
	var component: Interactable = Interactable.new()
	body.add_child(component)
	add_child_autofree(body)
	watch_signals(component)
	component.interact(_player)
	assert_signal_emitted_with_parameters(component, "interacted", [_player])
	component.enabled = false
	component.interact(_player)
	assert_signal_emit_count(component, "interacted", 1, "disabled components ignore interact")


func test_interactor_targets_pickup_and_prompts() -> void:
	# The unpitched camera ray travels at rig height (y=1.5).
	_spawn_pickup(&"test_shell", "Shell", 3, Vector3(0, 1.5, -1.5))
	var interactor: PlayerInteractor = _player.get_node("PlayerInteractor") as PlayerInteractor
	watch_signals(interactor)
	await wait_physics_frames(10)
	assert_signal_emitted_with_parameters(interactor, "target_changed", ["Take Shell x3"])


func test_pickup_goes_to_inventory_and_frees() -> void:
	var pickup: ItemPickup = _spawn_pickup(&"test_shell", "Shell", 3, Vector3(0, 1.2, -1.5))
	await wait_physics_frames(2)
	(pickup.get_node("Interactable") as Interactable).interact(_player)
	assert_eq(Inventory.count_of(&"test_shell"), 3, "pickup landed in inventory")
	assert_true(pickup.is_queued_for_deletion(), "consumed pickups free themselves")


func test_add_item_stacks_to_twenty() -> void:
	assert_eq(Inventory.add_item(&"ash", 25), 0, "everything fits")
	assert_eq(Inventory.count_of(&"ash"), 25)
	assert_eq(Inventory.hotbar[0]["count"], 20, "first stack tops out at STACK_MAX")
	assert_eq(Inventory.hotbar[1]["count"], 5, "remainder starts a second stack")


func test_add_item_overflow_returns_leftover() -> void:
	assert_eq(Inventory.add_item(&"ash", 800), 0, "40 slots x 20 fill exactly")
	assert_eq(Inventory.add_item(&"ash", 5), 5, "a full inventory returns the leftover")
