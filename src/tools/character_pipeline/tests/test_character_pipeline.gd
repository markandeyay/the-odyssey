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
		bone_map.get_skeleton_bone_name("RightHand") == &"mixamorig_RightHand",
		"Mixamo right hand maps to the humanoid profile"
	)
	var sources: Array[String] = validator.validate_sources(manifest)
	_expect(sources.is_empty(), "all reviewed Mixamo sources pass strict validation: %s" % "; ".join(sources))
	_test_canonical_library(manifest)
	if _failures == 0:
		print("PASS: Odyssey M3 character pipeline contract tests")
	else:
		printerr("FAIL: %d Odyssey M3 character pipeline assertion(s)" % _failures)
	quit(_failures)


func _test_canonical_library(manifest: Dictionary) -> void:
	var library_path: String = "res://assets/characters/nau/animations/nau_animation_library.tres"
	var library: AnimationLibrary = load(library_path) as AnimationLibrary
	_expect(library != null, "canonical Nau AnimationLibrary loads")
	if library == null:
		return
	var clips: Array = manifest.get("animations", []) as Array
	_expect(library.get_animation_list().size() == clips.size(), "canonical library contains all 17 clips")
	for clip_value: Variant in clips:
		var clip: Dictionary = clip_value as Dictionary
		var clip_name: StringName = StringName(clip.get("name", ""))
		_expect(library.has_animation(clip_name), "canonical library contains %s" % clip_name)
		if not library.has_animation(clip_name):
			continue
		var animation: Animation = library.get_animation(clip_name)
		var expected_loop: int = (
			Animation.LOOP_LINEAR if bool(clip.get("loop", false)) else Animation.LOOP_NONE
		)
		_expect(animation.loop_mode == expected_loop, "%s uses the declared loop mode" % clip_name)
		for track_index: int in animation.get_track_count():
			var path: String = str(animation.track_get_path(track_index))
			_expect(path.begins_with("NauSkeleton:"), "%s track targets the contract skeleton" % clip_name)
			if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
				continue
			if path != "NauSkeleton:Hips" or animation.track_get_key_count(track_index) == 0:
				continue
			var anchor: Vector3 = animation.track_get_key_value(track_index, 0) as Vector3
			for key_index: int in animation.track_get_key_count(track_index):
				var value: Vector3 = animation.track_get_key_value(track_index, key_index) as Vector3
				_expect(
					Vector2(value.x - anchor.x, value.z - anchor.z).length() <= 0.0001,
					"%s has no horizontal root displacement" % clip_name
				)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("ASSERTION FAILED: %s" % message)
