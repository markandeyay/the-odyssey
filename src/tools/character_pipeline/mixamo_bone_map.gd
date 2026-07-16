extends RefCounted

const MANIFEST_PATH: String = "res://src/tools/character_pipeline/mixamo_manifest.json"


static func create(manifest: Dictionary = {}) -> BoneMap:
	var resolved_manifest: Dictionary = manifest
	if resolved_manifest.is_empty():
		resolved_manifest = load_manifest()
	var bone_map: BoneMap = BoneMap.new()
	bone_map.profile = SkeletonProfileHumanoid.new()
	var mappings: Dictionary = resolved_manifest.get("bone_map", {}) as Dictionary
	for profile_bone: String in mappings:
		bone_map.set_skeleton_bone_name(profile_bone, str(mappings[profile_bone]))
	return bone_map


static func load_manifest(path: String = MANIFEST_PATH) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}
