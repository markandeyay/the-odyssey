class_name Flammable
extends Node
## Makes the parent body burnable (M7). Child of a PhysicsBody3D that sits
## on physics layer `flammable` (11). The object holds the fuel; the
## FireGrid's cells are the spread medium. Registration is positional:
## `size` around the parent origin becomes grid cells (rotation is
## deliberately ignored — fire does not care). Mobile flammables (the
## brand, carryable props) occupy exactly one cell that follows the parent.
##
## Lifecycle: UNBURNT -> BURNING (grip reports HOT via the `burning`
## group) -> CHARRED, permanently (grip reports CRUMBLING via the
## `charred` group). Dousing extinguishes back to UNBURNT with the
## remaining fuel and blocks re-ignition while wet.

signal ignited()
signal extinguished()
signal charred()

enum State { UNBURNT, BURNING, CHARRED }

## Cell-seconds of burn: fuel 10 with 2 cells alight lasts 5 more seconds.
@export var fuel: float = 10.0
## World-space extents of the burnable region (static flammables only).
@export var size: Vector3 = Vector3.ONE
## Offset of the burnable region's center from the parent origin.
@export var center_offset: Vector3 = Vector3.ZERO
## Mobile flammables occupy one cell that follows the parent (the brand).
@export var mobile: bool = false
## The brand turns this off: carried fire must not cook the carrier.
@export var contact_damage: bool = true
## The brand has its own flame; pooled grid VFX skip it.
@export var pooled_vfx: bool = true
## How long a dousing blocks re-ignition.
@export var doused_duration: float = 60.0

var state: State = State.UNBURNT
var doused_timer: float = 0.0
var cells: Array[Vector3i] = []
var burning_cells: Dictionary = {}
var last_base_cell: Vector3i = Vector3i.ZERO

var _grid: FireGrid = null

@onready var body: Node3D = get_parent() as Node3D


func _ready() -> void:
	if body == null:
		push_warning("Flammable: parent of %s is not a Node3D; staying inert" % get_path())
		return
	# Deferred so a FireGrid added in the same frame is findable.
	_register.call_deferred()


func _exit_tree() -> void:
	if _grid != null and is_instance_valid(_grid):
		_grid.unregister_flammable(self)
	_grid = null


func is_burning() -> bool:
	return state == State.BURNING


func is_charred() -> bool:
	return state == State.CHARRED


func is_doused() -> bool:
	return doused_timer > 0.0


## Lights the cell at the region center (campfires, the brand, tests).
func ignite() -> bool:
	if _grid == null:
		return false
	return _grid.ignite_flammable(self)


## Grid callbacks. The grid owns all state transitions so that spread,
## fuel, caps, and events stay in one deterministic step().

func on_cell_ignited(cell: Vector3i) -> void:
	burning_cells[cell] = true
	if state == State.BURNING:
		return
	state = State.BURNING
	doused_timer = 0.0
	body.add_to_group(Grip.BURNING_GROUP)
	ignited.emit()
	EventBus.fire_started.emit(body.global_position)


func on_charred() -> void:
	burning_cells.clear()
	state = State.CHARRED
	fuel = 0.0
	body.remove_from_group(Grip.BURNING_GROUP)
	body.add_to_group(Grip.CHARRED_GROUP)
	charred.emit()
	EventBus.fire_extinguished.emit(body.global_position)


func on_extinguished(doused: bool) -> void:
	burning_cells.clear()
	state = State.UNBURNT
	if doused:
		doused_timer = doused_duration
	body.remove_from_group(Grip.BURNING_GROUP)
	extinguished.emit()
	EventBus.fire_extinguished.emit(body.global_position)


func _register() -> void:
	_grid = get_tree().get_first_node_in_group(FireGrid.GROUP) as FireGrid
	if _grid == null:
		push_warning("Flammable: no FireGrid in scene; %s stays inert" % get_path())
		return
	_grid.register_flammable(self)
