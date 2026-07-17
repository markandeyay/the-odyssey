extends RefCounted

const CLIMBABLE_LAYER_BIT: int = 1 << 2
const WORLD_SCENE_ROOTS: PackedStringArray = [
	"res://scenes/levels/lanka",
	"res://scenes/levels/cairns",
	"res://scenes/prefabs/props",
]

var _name_pattern: RegEx


func _init() -> void:
	_name_pattern = RegEx.new()
	var compile_error: Error = _name_pattern.compile(
		"^mat_[a-z0-9]+(?:_[a-z0-9]+)*_grip_(?:solid|crumbling|slick|hot)$"
	)
	assert(compile_error == OK)


func validate_material_name(material_name: String) -> bool:
	return _name_pattern.search(material_name) != null


func validate_world_scenes() -> Array[String]:
	var scene_paths: PackedStringArray = PackedStringArray()
	for root_path: String in WORLD_SCENE_ROOTS:
		_collect_scenes(root_path, scene_paths)
	return validate_scene_paths(scene_paths)


func validate_scene_paths(scene_paths: PackedStringArray) -> Array[String]:
	var issues: Array[String] = []
	for scene_path: String in scene_paths:
		var resource: Resource = ResourceLoader.load(scene_path, "PackedScene")
		if not resource is PackedScene:
			issues.append("%s: unable to load PackedScene" % scene_path)
			continue
		var root: Node = (resource as PackedScene).instantiate()
		issues.append_array(validate_root(root, scene_path))
		root.free()
	return issues


func validate_root(root: Node, source_label: String = "<in-memory>") -> Array[String]:
	var issues: Array[String] = []
	_validate_node(root, source_label, issues)
	return issues


func _validate_node(node: Node, source_label: String, issues: Array[String]) -> void:
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		if collision_object.collision_layer & CLIMBABLE_LAYER_BIT != 0:
			_validate_collision_object(collision_object, source_label, issues)
	elif node is CSGShape3D:
		var csg: CSGShape3D = node as CSGShape3D
		if csg.use_collision and csg.collision_layer & CLIMBABLE_LAYER_BIT != 0:
			_validate_csg(csg, source_label, issues)
	elif node is GridMap:
		var grid_map: GridMap = node as GridMap
		if grid_map.collision_layer & CLIMBABLE_LAYER_BIT != 0:
			_validate_grid_map(grid_map, source_label, issues)
	for child: Node in node.get_children():
		_validate_node(child, source_label, issues)


func _validate_collision_object(
	collision_object: CollisionObject3D,
	source_label: String,
	issues: Array[String]
) -> void:
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(collision_object, mesh_instances)
	if mesh_instances.is_empty():
		issues.append(
			"%s:%s is on climbable layer 3 but has no MeshInstance3D material to classify"
			% [source_label, _node_path(collision_object)]
		)
		return
	for mesh_instance: MeshInstance3D in mesh_instances:
		_validate_mesh_instance(mesh_instance, source_label, issues)


func _validate_mesh_instance(
	mesh_instance: MeshInstance3D,
	source_label: String,
	issues: Array[String]
) -> void:
	if mesh_instance.mesh == null:
		issues.append("%s:%s has no mesh" % [source_label, _node_path(mesh_instance)])
		return
	var surface_count: int = mesh_instance.mesh.get_surface_count()
	if surface_count == 0:
		issues.append("%s:%s mesh has no surfaces" % [source_label, _node_path(mesh_instance)])
		return
	for surface_index: int in surface_count:
		var material: Material = mesh_instance.get_active_material(surface_index)
		_validate_material(material, source_label, mesh_instance, surface_index, issues)


func _validate_material(
	material: Material,
	source_label: String,
	node: Node,
	surface_index: int,
	issues: Array[String]
) -> void:
	if material == null:
		issues.append(
			"%s:%s surface %d is climbable but has no material"
			% [source_label, _node_path(node), surface_index]
		)
		return
	if not validate_material_name(material.resource_name):
		issues.append(
			"%s:%s surface %d material '%s' violates mat_<name>_grip_<class>"
			% [source_label, _node_path(node), surface_index, material.resource_name]
		)


func _validate_csg(csg: CSGShape3D, source_label: String, issues: Array[String]) -> void:
	var material: Material = csg.material
	_validate_material(material, source_label, csg, 0, issues)


func _validate_grid_map(grid_map: GridMap, source_label: String, issues: Array[String]) -> void:
	if grid_map.mesh_library == null:
		issues.append("%s:%s climbable GridMap has no MeshLibrary" % [source_label, _node_path(grid_map)])
		return
	var used_items: Dictionary = {}
	for cell: Vector3i in grid_map.get_used_cells():
		used_items[grid_map.get_cell_item(cell)] = true
	for item_value: Variant in used_items.keys():
		var item_id: int = int(item_value)
		var mesh: Mesh = grid_map.mesh_library.get_item_mesh(item_id)
		if mesh == null:
			issues.append("%s:%s item %d has no mesh" % [source_label, _node_path(grid_map), item_id])
			continue
		for surface_index: int in mesh.get_surface_count():
			_validate_material(mesh.surface_get_material(surface_index), source_label, grid_map, surface_index, issues)


func _collect_mesh_instances(node: Node, output: Array[MeshInstance3D]) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			output.append(child as MeshInstance3D)
		if not child is CollisionObject3D:
			_collect_mesh_instances(child, output)


func _collect_scenes(root_path: String, output: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(root_path)
	if directory == null:
		return
	for filename: String in directory.get_files():
		if filename.get_extension().to_lower() == "tscn":
			output.append(root_path.path_join(filename))
	for child: String in directory.get_directories():
		_collect_scenes(root_path.path_join(child), output)


func _node_path(node: Node) -> String:
	return str(node.get_path()) if node.is_inside_tree() else node.name
