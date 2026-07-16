extends RefCounted

const MixamoBoneMap: Script = preload("res://src/tools/character_pipeline/mixamo_bone_map.gd")
const MANIFEST_PATH: String = "res://src/tools/character_pipeline/mixamo_manifest.json"
const ANIMATION_ROOT: String = "res://assets/characters/nau/source/mixamo/animations"
const EXPECTED_ANIMATIONS: PackedStringArray = [
	"idle", "walk", "run", "jump", "fall", "land", "crouch", "crouch_walk",
	"climb_up", "climb_left", "climb_right", "ledge_grab", "mantle", "carry_idle",
	"carry_walk", "glide", "death",
]
const REQUIRED_PROFILE_BONES: PackedStringArray = [
	"Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftThumbMetacarpal", "LeftThumbProximal", "LeftThumbDistal",
	"LeftIndexProximal", "LeftIndexIntermediate", "LeftIndexDistal",
	"LeftMiddleProximal", "LeftMiddleIntermediate", "LeftMiddleDistal",
	"LeftRingProximal", "LeftRingIntermediate", "LeftRingDistal",
	"LeftLittleProximal", "LeftLittleIntermediate", "LeftLittleDistal",
	"RightThumbMetacarpal", "RightThumbProximal", "RightThumbDistal",
	"RightIndexProximal", "RightIndexIntermediate", "RightIndexDistal",
	"RightMiddleProximal", "RightMiddleIntermediate", "RightMiddleDistal",
	"RightRingProximal", "RightRingIntermediate", "RightRingDistal",
	"RightLittleProximal", "RightLittleIntermediate", "RightLittleDistal",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes",
]


func validate_manifest(manifest: Dictionary = {}) -> Array[String]:
	var issues: Array[String] = []
	var resolved: Dictionary = manifest if not manifest.is_empty() else MixamoBoneMap.load_manifest()
	if resolved.is_empty():
		return ["Unable to parse %s" % MANIFEST_PATH]
	if int(resolved.get("schema_version", 0)) != 1:
		issues.append("Unsupported Nau character manifest schema")
	var download: Dictionary = resolved.get("download_contract", {}) as Dictionary
	_expect_equal(download, "base_format", "FBX Binary", issues)
	_expect_equal(download, "base_pose", "T-pose", issues)
	_expect_equal(download, "base_skin", "With Skin", issues)
	_expect_equal(download, "animation_format", "FBX Binary", issues)
	_expect_equal(download, "animation_skin", "Without Skin", issues)
	_expect_equal(download, "keyframe_reduction", "none", issues)
	if int(download.get("fps", 0)) != 30:
		issues.append("Mixamo animation download FPS must be 30")

	var seen: Dictionary = {}
	var source_files: Dictionary = {}
	var animations: Array = resolved.get("animations", []) as Array
	for animation_value: Variant in animations:
		if not animation_value is Dictionary:
			issues.append("Animation manifest entry is not an object")
			continue
		var animation: Dictionary = animation_value as Dictionary
		var animation_name: String = str(animation.get("name", ""))
		var filename: String = str(animation.get("file", ""))
		if animation_name.is_empty() or seen.has(animation_name):
			issues.append("Animation names must be non-empty and unique: %s" % animation_name)
		seen[animation_name] = true
		if filename.get_extension().to_lower() != "fbx" or filename.get_file() != filename:
			issues.append("Animation %s has an invalid source filename: %s" % [animation_name, filename])
		source_files[filename] = true
		if not bool(animation.get("in_place", false)):
			issues.append("Animation %s must be downloaded In Place (root motion off)" % animation_name)
	for expected: String in EXPECTED_ANIMATIONS:
		if not seen.has(expected):
			issues.append("Missing required animation manifest entry: %s" % expected)
	if seen.size() != EXPECTED_ANIMATIONS.size():
		issues.append("Animation manifest must contain exactly %d clips" % EXPECTED_ANIMATIONS.size())
	if source_files.size() != 16:
		issues.append("The reviewed M3 set must reference exactly 16 unique source FBXs")

	var mapping: Dictionary = resolved.get("bone_map", {}) as Dictionary
	var bone_map: BoneMap = MixamoBoneMap.create(resolved)
	if not bone_map.profile is SkeletonProfileHumanoid:
		issues.append("Bone map must use SkeletonProfileHumanoid")
	for profile_bone: String in REQUIRED_PROFILE_BONES:
		if str(mapping.get(profile_bone, "")).is_empty():
			issues.append("Missing Mixamo bone mapping for %s" % profile_bone)
		elif bone_map.get_skeleton_bone_name(profile_bone) != StringName(str(mapping[profile_bone]).replace(":", "_")):
			issues.append("BoneMap did not preserve mapping for %s" % profile_bone)
	return issues


func validate_sources(manifest: Dictionary = {}) -> Array[String]:
	var issues: Array[String] = []
	var resolved: Dictionary = manifest if not manifest.is_empty() else MixamoBoneMap.load_manifest()
	issues.append_array(validate_manifest(resolved))
	if resolved.is_empty():
		return issues
	var character: Dictionary = resolved.get("character", {}) as Dictionary
	var base_path: String = str(character.get("base_path", ""))
	if not FileAccess.file_exists(base_path):
		issues.append("Missing Mixamo base FBX: %s" % base_path)
	else:
		_validate_fbx_source(base_path, false, issues)
	for animation_value: Variant in resolved.get("animations", []) as Array:
		if not animation_value is Dictionary:
			continue
		var animation: Dictionary = animation_value as Dictionary
		var path: String = ANIMATION_ROOT.path_join(str(animation.get("file", "")))
		if not FileAccess.file_exists(path):
			issues.append("Missing Mixamo animation FBX: %s" % path)
		else:
			_validate_fbx_source(path, true, issues)
	var referenced: Dictionary = {}
	for animation_value: Variant in resolved.get("animations", []) as Array:
		if animation_value is Dictionary:
			referenced[str((animation_value as Dictionary).get("file", ""))] = true
	for filename: String in DirAccess.get_files_at(ANIMATION_ROOT):
		if filename.get_extension().to_lower() == "fbx" and not referenced.has(filename):
			issues.append("Unreferenced downloaded Mixamo FBX: %s" % ANIMATION_ROOT.path_join(filename))
	return issues


func validate_visual_scene(manifest: Dictionary = {}) -> Array[String]:
	var issues: Array[String] = []
	var resolved: Dictionary = manifest if not manifest.is_empty() else MixamoBoneMap.load_manifest()
	issues.append_array(validate_manifest(resolved))
	if resolved.is_empty():
		return issues
	var character: Dictionary = resolved.get("character", {}) as Dictionary
	var visual_path: String = str(character.get("visual_scene_path", ""))
	if not ResourceLoader.exists(visual_path, "PackedScene"):
		issues.append("Missing or invalid Nau visual scene: %s" % visual_path)
		return issues
	var packed: Resource = ResourceLoader.load(visual_path, "PackedScene")
	if not packed is PackedScene:
		issues.append("Missing or invalid Nau visual scene: %s" % visual_path)
		return issues
	var root: Node = (packed as PackedScene).instantiate()
	var skeletons: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
	if skeletons.size() != 1:
		issues.append("Nau visual must contain exactly one Skeleton3D; found %d" % skeletons.size())
	else:
		_validate_skeleton(skeletons[0] as Skeleton3D, character, issues)
	_validate_cover_nodes(root, character, issues)
	_validate_material_slots(root, character, issues)
	_validate_height(root, character, issues)
	_validate_animation_library(root, issues)
	root.free()
	return issues


func _validate_skeleton(skeleton: Skeleton3D, character: Dictionary, issues: Array[String]) -> void:
	for profile_bone: String in REQUIRED_PROFILE_BONES:
		if skeleton.find_bone(profile_bone) < 0:
			issues.append("Retargeted Skeleton3D is missing humanoid bone: %s" % profile_bone)
	var sockets: Dictionary = character.get("sockets", {}) as Dictionary
	for socket_name: String in sockets:
		var socket: Node = skeleton.find_child(socket_name, true, false)
		if not socket is BoneAttachment3D:
			issues.append("Missing BoneAttachment3D socket: %s" % socket_name)
			continue
		var expected_bone: StringName = StringName(sockets[socket_name])
		if (socket as BoneAttachment3D).bone_name != expected_bone:
			issues.append("%s must attach to %s" % [socket_name, expected_bone])


func _validate_cover_nodes(root: Node, character: Dictionary, issues: Array[String]) -> void:
	for node_name: Variant in character.get("required_cover_nodes", []) as Array:
		var cover: Node = root.find_child(str(node_name), true, false)
		if not cover is GeometryInstance3D or not (cover as GeometryInstance3D).visible:
			issues.append("Nau's face-covering geometry is missing or hidden: %s" % node_name)


func _validate_material_slots(root: Node, character: Dictionary, issues: Array[String]) -> void:
	var present: Dictionary = {}
	for mesh_node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var material: Material = mesh_instance.get_active_material(surface_index)
			if material != null and not material.resource_name.is_empty():
				present[material.resource_name] = true
	for material_name: Variant in character.get("required_material_slots", []) as Array:
		if not present.has(str(material_name)):
			issues.append("Missing named Nau material slot: %s" % material_name)


func _validate_height(root: Node, character: Dictionary, issues: Array[String]) -> void:
	var bounds: AABB = _collect_bounds(root, Transform3D.IDENTITY, AABB(), false)
	if bounds.size == Vector3.ZERO:
		issues.append("Nau visual has no mesh bounds")
		return
	var expected: float = float(character.get("expected_height_m", 1.9))
	var tolerance: float = float(character.get("height_tolerance_m", 0.15))
	if absf(bounds.size.y - expected) > tolerance:
		issues.append("Nau height is %.3fm; expected %.3fm +/- %.3fm" % [bounds.size.y, expected, tolerance])


func _validate_animation_library(root: Node, issues: Array[String]) -> void:
	var players: Array[Node] = root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		issues.append("Nau visual has no AnimationPlayer")
		return
	var found: Dictionary = {}
	for player_node: Node in players:
		var player: AnimationPlayer = player_node as AnimationPlayer
		for library_name: StringName in player.get_animation_library_list():
			var library: AnimationLibrary = player.get_animation_library(library_name)
			for clip_name: StringName in library.get_animation_list():
				found[str(clip_name)] = true
				_validate_root_motion_tracks(str(clip_name), library.get_animation(clip_name), issues)
	for expected: String in EXPECTED_ANIMATIONS:
		if not found.has(expected):
			issues.append("Nau AnimationPlayer is missing clip: %s" % expected)


func _validate_root_motion_tracks(clip_name: String, animation: Animation, issues: Array[String]) -> void:
	for track_index: int in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		var path: String = str(animation.track_get_path(track_index)).to_lower()
		if "hips" not in path and "root" not in path:
			continue
		var first: Vector3 = animation.position_track_interpolate(track_index, 0.0)
		var last: Vector3 = animation.position_track_interpolate(track_index, animation.length)
		var horizontal_delta: Vector2 = Vector2(last.x - first.x, last.z - first.z)
		if horizontal_delta.length() > 0.01:
			issues.append("Animation %s contains %.3fm horizontal root motion" % [clip_name, horizontal_delta.length()])


func _validate_fbx_source(path: String, expects_animation: bool, issues: Array[String]) -> void:
	var source: FileAccess = FileAccess.open(path, FileAccess.READ)
	if source == null:
		issues.append("Unable to read Mixamo FBX: %s" % path)
		return
	var header: String = source.get_buffer(23).get_string_from_ascii()
	var source_size: int = source.get_length()
	source.close()
	if source_size <= 23 or not header.begins_with("Kaydara FBX Binary"):
		issues.append("Mixamo source is not FBX Binary: %s" % path)

	var import_path: String = path + ".import"
	var import_config: ConfigFile = ConfigFile.new()
	if import_config.load(import_path) != OK:
		issues.append("Missing committed Godot import metadata: %s" % import_path)
		return
	if str(import_config.get_value("remap", "importer", "")) != "scene":
		issues.append("Mixamo FBX must use Godot's scene importer: %s" % path)
	var animation_imported: bool = bool(import_config.get_value("params", "animation/import", false))
	if animation_imported != expects_animation:
		issues.append(
			"animation/import must be %s for %s"
			% [str(expects_animation).to_lower(), path]
		)
	if expects_animation and int(import_config.get_value("params", "animation/fps", 0)) != 30:
		issues.append("Godot animation bake FPS must be 30: %s" % path)


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


func _expect_equal(values: Dictionary, key: String, expected: String, issues: Array[String]) -> void:
	if str(values.get(key, "")) != expected:
		issues.append("Mixamo download contract %s must be '%s'" % [key, expected])
