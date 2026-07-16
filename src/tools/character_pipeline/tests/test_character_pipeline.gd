extends SceneTree

const MixamoBoneMap: Script = preload("res://src/tools/character_pipeline/mixamo_bone_map.gd")
const NauCharacterValidator: Script = preload("res://src/tools/character_pipeline/nau_character_validator.gd")

var _failures: int = 0


func _initialize() -> void:
	var manifest: Dictionary = MixamoBoneMap.load_manifest()
	_expect(not manifest.is_empty(), "Mixamo manifest parses")
	var validator: RefCounted = NauCharacterValidator.new() as RefCounted
	var issues: Array[String] = validator.validate_manifest(manifest)
	_expect(issues.is_empty(), "manifest satisfies M3 contract: %s" % "; ".join(issues))
	var bone_map: BoneMap = MixamoBoneMap.create(manifest)
	_expect(bone_map.profile is SkeletonProfileHumanoid, "BoneMap uses SkeletonProfileHumanoid")
	_expect(
		bone_map.get_skeleton_bone_name("RightHand") == &"mixamorig:RightHand",
		"Mixamo right hand maps to the humanoid profile"
	)
	var sources: Array[String] = validator.validate_sources(manifest)
	_expect(
		sources.any(func(issue: String) -> bool: return "Missing Mixamo base FBX" in issue),
		"source validation reports the intentionally absent base FBX"
	)
	if _failures == 0:
		print("PASS: Odyssey M3 character pipeline contract tests")
	else:
		printerr("FAIL: %d Odyssey M3 character pipeline assertion(s)" % _failures)
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("ASSERTION FAILED: %s" % message)
