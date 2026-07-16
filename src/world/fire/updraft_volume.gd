class_name UpdraftVolume
extends Area3D
## Updraft above a sufficiently large burn (M7). Created and pooled by the
## FireGrid; sits on physics layer `updraft` (12). Inert until the glider
## (M13) reads overlapping volumes and applies `lift_strength`. Do not
## build flight here.

@export var lift_strength: float = 12.0

var _cylinder: CylinderShape3D = CylinderShape3D.new()
var _shape_node: CollisionShape3D = CollisionShape3D.new()


func _ready() -> void:
	collision_layer = 2048  # layer 12 `updraft`
	collision_mask = 2      # the player
	monitoring = false
	monitorable = true
	_shape_node.shape = _cylinder
	add_child(_shape_node)
	deactivate()


func configure(center: Vector3, radius: float, height: float) -> void:
	global_position = center
	_cylinder.radius = radius
	_cylinder.height = height
	_shape_node.disabled = false
	visible = true


func deactivate() -> void:
	_shape_node.disabled = true
	visible = false


func is_active() -> bool:
	return not _shape_node.disabled
