extends SceneTree

const MixamoBoneMap: Script = preload("res://src/tools/character_pipeline/mixamo_bone_map.gd")
const BASE_PATH: String = "res://assets/characters/nau/source/mixamo/base/nau_base.fbx"
const LIBRARY_PATH: String = "res://assets/characters/nau/animations/nau_animation_library.tres"
const OUTPUT_PATH: String = "res://assets/characters/nau/nau_visual.tscn"
const TARGET_HEIGHT_M: float = 1.9
const SOCKETS: Dictionary = {
	"Socket_RightHand": "RightHand",
	"Socket_LeftHand": "LeftHand",
	"Socket_Back": "UpperChest",
	"Socket_Hip": "Hips",
}


func _initialize() -> void:
	if not ResourceLoader.exists(BASE_PATH, "PackedScene"):
		_fail("Missing imported skinned Mixamo base: %s" % BASE_PATH)
		return
	var packed_base: PackedScene = load(BASE_PATH) as PackedScene
	var root: Node3D = packed_base.instantiate() as Node3D
	if root == null:
		_fail("Mixamo base root must be Node3D")
		return
	root.name = "NauVisual"
	var skeletons: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if skeletons.size() != 1 or meshes.is_empty():
		root.free()
		_fail("Mixamo base must contain exactly one Skeleton3D and at least one MeshInstance3D")
		return
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	var reverse_bone_map: Dictionary = _reverse_bone_map(MixamoBoneMap.load_manifest())
	_rename_skin_binds(meshes, reverse_bone_map)
	_rename_skeleton_bones(skeleton, reverse_bone_map)
	skeleton.name = "NauSkeleton"
	_install_animation_library(root)
	_add_sockets(skeleton)
	_add_face_cover(skeleton)
	_name_body_materials(meshes)
	_scale_to_contract(root)
	_set_owner_recursive(root, root)
	var packed_output: PackedScene = PackedScene.new()
	var pack_error: Error = packed_output.pack(root)
	if pack_error != OK:
		root.free()
		_fail("Unable to pack Nau visual: %s" % error_string(pack_error))
		return
	var save_error: Error = ResourceSaver.save(packed_output, OUTPUT_PATH)
	root.free()
	if save_error != OK:
		_fail("Unable to save %s: %s" % [OUTPUT_PATH, error_string(save_error)])
		return
	print("Wrote contract visual scene to %s" % OUTPUT_PATH)
	quit(0)


func _reverse_bone_map(manifest: Dictionary) -> Dictionary:
	var reverse: Dictionary = {}
	var mappings: Dictionary = manifest.get("bone_map", {}) as Dictionary
	for profile_bone: String in mappings:
		reverse[str(mappings[profile_bone]).replace(":", "_")] = profile_bone
	return reverse


func _rename_skin_binds(meshes: Array[Node], reverse_bone_map: Dictionary) -> void:
	for mesh_node: Node in meshes:
		var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
		if mesh_instance.skin == null:
			continue
		for bind_index: int in mesh_instance.skin.get_bind_count():
			var bind_name: String = str(mesh_instance.skin.get_bind_name(bind_index))
			if reverse_bone_map.has(bind_name):
				mesh_instance.skin.set_bind_name(bind_index, reverse_bone_map[bind_name])


func _rename_skeleton_bones(skeleton: Skeleton3D, reverse_bone_map: Dictionary) -> void:
	for bone_index: int in skeleton.get_bone_count():
		var source_name: String = str(skeleton.get_bone_name(bone_index))
		if reverse_bone_map.has(source_name):
			skeleton.set_bone_name(bone_index, reverse_bone_map[source_name])


func _install_animation_library(root: Node) -> void:
	var library: AnimationLibrary = load(LIBRARY_PATH) as AnimationLibrary
	if library == null:
		return
	var players: Array[Node] = root.find_children("*", "AnimationPlayer", true, false)
	var player: AnimationPlayer
	if players.is_empty():
		player = AnimationPlayer.new()
		player.name = "AnimationPlayer"
		root.add_child(player)
	else:
		player = players[0] as AnimationPlayer
	for library_name: StringName in player.get_animation_library_list():
		player.remove_animation_library(library_name)
	player.add_animation_library(&"", library)


func _add_sockets(skeleton: Skeleton3D) -> void:
	for socket_name: String in SOCKETS:
		var socket: BoneAttachment3D = BoneAttachment3D.new()
		socket.name = socket_name
		socket.bone_name = SOCKETS[socket_name]
		skeleton.add_child(socket)


func _add_face_cover(skeleton: Skeleton3D) -> void:
	var head_attachment: BoneAttachment3D = BoneAttachment3D.new()
	head_attachment.name = "NauHeadCoverAttachment"
	head_attachment.bone_name = &"Head"
	skeleton.add_child(head_attachment)

	var hood_material: StandardMaterial3D = _make_material(
		"mat_nau_hood", Color(0.075, 0.065, 0.06), 1.0, 0.0
	)
	var hood_mesh: SphereMesh = SphereMesh.new()
	hood_mesh.radius = 0.17
	hood_mesh.height = 0.34
	hood_mesh.radial_segments = 16
	hood_mesh.rings = 8
	hood_mesh.material = hood_material
	var hood: MeshInstance3D = MeshInstance3D.new()
	hood.name = "NauHood"
	hood.position = Vector3(0.0, 0.09, 0.0)
	hood.mesh = hood_mesh
	head_attachment.add_child(hood)
	var hood_collar_mesh: CylinderMesh = CylinderMesh.new()
	hood_collar_mesh.top_radius = 0.15
	hood_collar_mesh.bottom_radius = 0.23
	hood_collar_mesh.height = 0.18
	hood_collar_mesh.radial_segments = 16
	hood_collar_mesh.rings = 2
	hood_collar_mesh.material = hood_material
	var hood_collar: MeshInstance3D = MeshInstance3D.new()
	hood_collar.name = "NauHoodCollar"
	hood_collar.position = Vector3(0.0, -0.11, 0.0)
	hood_collar.mesh = hood_collar_mesh
	head_attachment.add_child(hood_collar)

	var mask_material: StandardMaterial3D = _make_material(
		"mat_nau_mask", Color(0.16, 0.145, 0.13), 0.62, 0.35
	)
	var mask_mesh: BoxMesh = BoxMesh.new()
	mask_mesh.size = Vector3(0.21, 0.16, 0.055)
	mask_mesh.material = mask_material
	var mask: MeshInstance3D = MeshInstance3D.new()
	mask.name = "NauMask"
	mask.position = Vector3(0.0, 0.06, 0.165)
	mask.mesh = mask_mesh
	head_attachment.add_child(mask)

	var cloth_attachment: BoneAttachment3D = BoneAttachment3D.new()
	cloth_attachment.name = "NauClothAttachment"
	cloth_attachment.bone_name = &"UpperChest"
	skeleton.add_child(cloth_attachment)
	var cloth_material: StandardMaterial3D = _make_material(
		"mat_nau_cloth", Color(0.19, 0.18, 0.16), 1.0, 0.0
	)
	var cloth_mesh: ArrayMesh = _make_mantle_mesh(cloth_material)
	var cloth: MeshInstance3D = MeshInstance3D.new()
	cloth.name = "NauShoulderCloth"
	cloth.position = Vector3(0.0, -0.08, -0.14)
	cloth.mesh = cloth_mesh
	cloth_attachment.add_child(cloth)
	var wrap_mesh: CapsuleMesh = CapsuleMesh.new()
	wrap_mesh.radius = 0.075
	wrap_mesh.height = 0.64
	wrap_mesh.radial_segments = 12
	wrap_mesh.rings = 4
	wrap_mesh.material = cloth_material
	var wrap: MeshInstance3D = MeshInstance3D.new()
	wrap.name = "NauShoulderWrap"
	wrap.position = Vector3(0.0, 0.06, 0.0)
	wrap.rotation_degrees.z = 90.0
	wrap.mesh = wrap_mesh
	cloth_attachment.add_child(wrap)


func _name_body_materials(meshes: Array[Node]) -> void:
	var assigned_body: bool = false
	for mesh_node: Node in meshes:
		var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var material: Material = _make_material(
				"mat_nau_body", Color(0.105, 0.078, 0.058), 0.82, 0.0
			)
			mesh_instance.set_surface_override_material(surface_index, material)
			assigned_body = true
	if not assigned_body:
		push_warning("Nau base has no assignable body material surfaces")


func _make_material(
	resource_name: String, albedo: Color, roughness: float, metallic: float
) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = resource_name
	material.albedo_color = albedo
	material.roughness = roughness
	material.metallic = metallic
	return material


func _make_mantle_mesh(material: Material) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.39, 0.12, 0.0),
		Vector3(0.39, 0.12, 0.0),
		Vector3(0.27, -0.58, 0.0),
		Vector3(-0.27, -0.58, 0.0),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK,
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.85, 1.0), Vector2(0.15, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


func _scale_to_contract(root: Node3D) -> void:
	var bounds: AABB = _collect_bounds(root, Transform3D.IDENTITY, AABB(), false)
	if bounds.size.y <= 0.0:
		return
	root.scale *= Vector3.ONE * (TARGET_HEIGHT_M / bounds.size.y)


func _collect_bounds(node: Node, parent_transform: Transform3D, bounds: AABB, has_bounds: bool) -> AABB:
	var current_transform: Transform3D = parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			var mesh_bounds: AABB = current_transform * mesh_instance.get_aabb()
			bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
			has_bounds = true
	for child: Node in node.get_children():
		var child_bounds: AABB = _collect_bounds(child, current_transform, AABB(), false)
		if child_bounds.size != Vector3.ZERO:
			bounds = bounds.merge(child_bounds) if has_bounds else child_bounds
			has_bounds = true
	return bounds


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
