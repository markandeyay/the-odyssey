extends RefCounted

const WORLD_LAYER: int = 1
const CLIMBABLE_LAYER: int = 1 << 2


func make_material(name: String, color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func add_static_box(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector3,
	material: Material,
	climbable: bool = false,
	rotation_degrees_value: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation_degrees = rotation_degrees_value
	body.collision_layer = WORLD_LAYER | (CLIMBABLE_LAYER if climbable else 0)
	body.collision_mask = 0
	parent.add_child(body)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	body.add_child(mesh_instance)
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	body.add_child(collision_shape)
	return body


func add_static_cylinder(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	radius: float,
	height: float,
	material: Material,
	climbable: bool = false,
	rotation_degrees_value: Vector3 = Vector3.ZERO,
	radial_segments: int = 16
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation_degrees = rotation_degrees_value
	body.collision_layer = WORLD_LAYER | (CLIMBABLE_LAYER if climbable else 0)
	body.collision_mask = 0
	parent.add_child(body)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var cylinder_mesh: CylinderMesh = CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius * 1.08
	cylinder_mesh.height = height
	cylinder_mesh.radial_segments = radial_segments
	cylinder_mesh.rings = 3
	cylinder_mesh.material = material
	mesh_instance.mesh = cylinder_mesh
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	body.add_child(mesh_instance)
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape"
	var cylinder_shape: CylinderShape3D = CylinderShape3D.new()
	cylinder_shape.radius = radius
	cylinder_shape.height = height
	collision_shape.shape = cylinder_shape
	body.add_child(collision_shape)
	return body


func add_visual_box(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector3,
	material: Material,
	rotation_degrees_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_degrees_value
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = material
	mesh_instance.mesh = box_mesh
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	parent.add_child(mesh_instance)
	return mesh_instance


func add_marker(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	socket_type: StringName,
	metadata: Dictionary = {}
) -> Marker3D:
	var marker: Marker3D = Marker3D.new()
	marker.name = node_name
	marker.position = position
	marker.set_meta(&"socket_type", socket_type)
	for key_value: Variant in metadata:
		marker.set_meta(key_value as StringName, metadata[key_value])
	parent.add_child(marker)
	return marker


func add_box_occluder(parent: Node3D, node_name: String, position: Vector3, size: Vector3) -> OccluderInstance3D:
	var resource: BoxOccluder3D = BoxOccluder3D.new()
	resource.size = size
	var occluder: OccluderInstance3D = OccluderInstance3D.new()
	occluder.name = node_name
	occluder.position = position
	occluder.occluder = resource
	parent.add_child(occluder)
	return occluder


func add_visibility_notifier(parent: Node3D, aabb: AABB) -> VisibleOnScreenNotifier3D:
	var notifier: VisibleOnScreenNotifier3D = VisibleOnScreenNotifier3D.new()
	notifier.name = "VisibilityNotifier"
	notifier.aabb = aabb
	parent.add_child(notifier)
	return notifier


func finish_scene(root: Node3D, path: String) -> Error:
	_set_owner_recursive(root, root)
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(root)
	if pack_error != OK:
		return pack_error
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	return ResourceSaver.save(packed, path)


func _set_owner_recursive(node: Node, scene_owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_owner
		_set_owner_recursive(child, scene_owner)
