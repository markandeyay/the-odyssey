class_name Grip
extends RefCounted
## Grip classes (ARCHITECTURE §5) and their runtime derivation (§19).
## A climbable surface's grip class comes from its material name:
##   mat_<name>_grip_solid | crumbling | slick | hot
## WORLD authors material names; SYSTEMS reads them here. There is no
## per-node grip property, ever — that is the seam.
## Fire overrides materials at runtime through scene groups, so this file
## stays decoupled from the fire system (M7 maintains group membership):
## a collider in "burning" reports HOT, in "charred" reports CRUMBLING.

enum Class { SOLID, CRUMBLING, SLICK, HOT }

const BURNING_GROUP: StringName = &"burning"
const CHARRED_GROUP: StringName = &"charred"
const _GRIP_TOKEN: String = "_grip_"

static var _warned_names: Dictionary = {}


static func class_from_collision(collider: Object) -> Class:
	var node: Node = collider as Node
	if node != null:
		if node.is_in_group(BURNING_GROUP):
			return Class.HOT
		if node.is_in_group(CHARRED_GROUP):
			return Class.CRUMBLING
	return class_from_material_name(material_name_of(collider))


static func class_from_material_name(material_name: String) -> Class:
	var lowered: String = material_name.to_lower()
	var token_at: int = lowered.rfind(_GRIP_TOKEN)
	if token_at >= 0:
		var suffix: String = lowered.substr(token_at + _GRIP_TOKEN.length())
		match suffix:
			"solid":
				return Class.SOLID
			"crumbling":
				return Class.CRUMBLING
			"slick":
				return Class.SLICK
			"hot":
				return Class.HOT
	_warn_once(material_name)
	return Class.SOLID


static func material_name_of(collider: Object) -> String:
	var mesh_instance: MeshInstance3D = _find_mesh_instance(collider)
	if mesh_instance == null:
		return ""
	var material: Material = mesh_instance.material_override
	if material == null and mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		material = mesh_instance.get_active_material(0)
	if material == null:
		return ""
	if material.resource_name != "":
		return material.resource_name
	return material.resource_path.get_file().get_basename()


## Covers both authoring patterns: a body with a MeshInstance3D child, and
## a collision body generated as a child of the MeshInstance3D itself.
static func _find_mesh_instance(collider: Object) -> MeshInstance3D:
	var node: Node = collider as Node
	if node == null:
		return null
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return node.get_parent() as MeshInstance3D


static func _warn_once(material_name: String) -> void:
	var key: String = material_name if material_name != "" else "<no material>"
	if _warned_names.has(key):
		return
	_warned_names[key] = true
	push_warning("Grip: material '%s' does not match mat_<name>_grip_<class>; defaulting to SOLID" % key)
