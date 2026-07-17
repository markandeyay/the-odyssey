class_name UpdraftVolume
extends Area3D
## Updraft the glider (M13) rides. Two lives: pooled volumes the FireGrid
## creates above a sufficiently large burn (M7), inert until configured;
## and standing vents WORLD places where the streets crack (`standing`
## on, sized by the exports, column rising from the node's origin). Sits
## on physics layer `updraft` (12). Do not build flight here.

@export var lift_strength: float = 12.0
## Placed vents activate themselves on ready; pooled fire updrafts leave
## this off and wait for the FireGrid.
@export var standing: bool = false
@export var radius: float = 2.0
@export var height: float = 12.0

var _cylinder: CylinderShape3D = CylinderShape3D.new()
var _shape_node: CollisionShape3D = CollisionShape3D.new()


func _ready() -> void:
	collision_layer = 2048  # layer 12 `updraft`
	collision_mask = 2      # the player
	monitoring = false
	monitorable = true
	_shape_node.shape = _cylinder
	add_child(_shape_node)
	if standing:
		_cylinder.radius = radius
		_cylinder.height = height
		_shape_node.position = Vector3.UP * height * 0.5
		_shape_node.disabled = false
		visible = true
	else:
		deactivate()


func configure(center: Vector3, radius_: float, height_: float) -> void:
	global_position = center
	_cylinder.radius = radius_
	_cylinder.height = height_
	_shape_node.position = Vector3.ZERO
	_shape_node.disabled = false
	visible = true


func deactivate() -> void:
	_shape_node.disabled = true
	visible = false


func is_active() -> bool:
	return not _shape_node.disabled
