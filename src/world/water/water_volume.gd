class_name WaterVolume
extends Area3D
## Interactive water (M8): the Cistern only. Buoyancy, currents, dousing,
## swimming, drowning. WORLD places and sizes instances of
## water_volume.tscn; the box top is the water surface.
##
## The ocean is NOT this system. The ocean is a KillVolume with waves on
## it (ARCHITECTURE §2). Do not stretch playable water over the sea.
##
## Dousing: burning bodies that touch the water are extinguished through
## the FireGrid; overlapped surfaces join the `doused` group, so their
## grip reports SLICK (HOT becomes SLICK — climbable but slick, a
## tradeoff). Dynamic bodies are watched through area overlap; static
## surfaces through a periodic shape query, because Jolt areas do not
## pair with static bodies by default.

## Constant push, m/s^2. WORLD sets this per volume for Cistern currents.
@export var current: Vector3 = Vector3.ZERO
## Upward acceleration on submerged rigid bodies. > gravity means it floats.
@export var buoyancy: float = 14.0
## Velocity damping factor while submerged; makes floaters settle, not bob.
@export var water_drag: float = 2.0
## Depth over which buoyancy ramps to full strength.
@export var float_depth: float = 0.5
## Seconds between douse/dry passes over static surfaces.
@export var douse_interval: float = 0.5
## How long a surface stays doused (SLICK) after the water stops touching it.
@export var dry_time: float = 30.0

var _doused: Dictionary = {}  # Node -> seconds until dry
var _douse_accum: float = 0.0
var _grid: FireGrid = null

@onready var _shape_node: CollisionShape3D = _find_shape()


func _ready() -> void:
	collision_layer = 32          # layer 6 `water`
	collision_mask = 2 | 8 | 1024  # player | carryable | flammable
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _shape_node == null or not _shape_node.shape is BoxShape3D:
		push_warning("WaterVolume: %s needs a BoxShape3D child; the box top is the surface" % get_path())


## World-space height of the water surface: the top of the box.
func surface_height() -> float:
	var box: BoxShape3D = _shape_node.shape as BoxShape3D
	return _shape_node.to_global(Vector3(0.0, box.size.y * 0.5, 0.0)).y


func _physics_process(delta: float) -> void:
	for body: Node3D in get_overlapping_bodies():
		var rigid: RigidBody3D = body as RigidBody3D
		if rigid != null:
			_apply_buoyancy(rigid)
	_douse_accum += delta
	if _douse_accum >= douse_interval:
		_douse_accum = 0.0
		_douse_pass()


func _apply_buoyancy(rigid: RigidBody3D) -> void:
	var depth: float = surface_height() - rigid.global_position.y
	if depth <= 0.0:
		return
	var fraction: float = clampf(depth / float_depth, 0.0, 1.0)
	var force: Vector3 = Vector3.UP * buoyancy * fraction * rigid.mass
	force += current * rigid.mass
	force -= rigid.linear_velocity * water_drag * fraction * rigid.mass
	rigid.apply_central_force(force)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player != null:
		player.enter_water(self)
		return
	# Fire dies in water the instant it touches (M7/M8): dunking a lit
	# brand is immediate, not on the next douse tick.
	_douse_fire(body)


func _on_body_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player != null:
		player.exit_water(self)


## Wets everything the water touches: burning things die, surfaces join
## the `doused` group until they dry out.
func _douse_pass() -> void:
	# Dry pass first; anything still wet gets refreshed below.
	for body: Node in _doused.keys():
		if not is_instance_valid(body):
			_doused.erase(body)
			continue
		_doused[body] -= douse_interval
		if _doused[body] <= 0.0:
			body.remove_from_group(Grip.DOUSED_GROUP)
			_doused.erase(body)
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = _shape_node.shape
	params.transform = _shape_node.global_transform
	params.collision_mask = 4 | 1024  # climbable | flammable statics
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(params, 64):
		var body: Node = hit["collider"] as Node
		if body != null:
			_wet(body)
	for body: Node3D in get_overlapping_bodies():
		_wet(body)


func _wet(body: Node) -> void:
	if body is Player:
		return  # Nau is not a surface
	_douse_fire(body)
	if not body.is_in_group(Grip.DOUSED_GROUP):
		body.add_to_group(Grip.DOUSED_GROUP)
	_doused[body] = dry_time


func _douse_fire(body: Node) -> void:
	if not body.is_in_group(Grip.BURNING_GROUP):
		return
	var flammable: Flammable = Flammable.of(body)
	if flammable == null:
		return
	if _grid == null or not is_instance_valid(_grid):
		_grid = get_tree().get_first_node_in_group(FireGrid.GROUP) as FireGrid
	if _grid != null:
		_grid.douse_flammable(flammable)


func _exit_tree() -> void:
	for body: Node in _doused.keys():
		if is_instance_valid(body):
			body.remove_from_group(Grip.DOUSED_GROUP)
	_doused.clear()
	# Streaming can free the volume while Nau swims in it.
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.exit_water(self)


func _find_shape() -> CollisionShape3D:
	for child: Node in get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null
