extends SceneTree

const MixamoBoneMap: Script = preload("res://src/tools/character_pipeline/mixamo_bone_map.gd")
const SOURCE_ROOT: String = "res://assets/characters/nau/source/mixamo/animations"
const OUTPUT_PATH: String = "res://assets/characters/nau/animations/nau_animation_library.tres"


func _initialize() -> void:
	var manifest: Dictionary = MixamoBoneMap.load_manifest()
	if manifest.is_empty():
		_fail("Unable to load Mixamo manifest")
		return
	var reverse_bone_map: Dictionary = _reverse_bone_map(manifest)
	var library: AnimationLibrary = AnimationLibrary.new()
	for clip_value: Variant in manifest.get("animations", []) as Array:
		if not clip_value is Dictionary:
			_fail("Animation manifest contains a non-object entry")
			return
		var clip: Dictionary = clip_value as Dictionary
		var source_path: String = SOURCE_ROOT.path_join(str(clip.get("file", "")))
		var source_animation: Animation = _load_source_animation(source_path)
		if source_animation == null:
			_fail("Unable to find an animation in %s" % source_path)
			return
		var animation: Animation = source_animation.duplicate(true) as Animation
		_retarget_tracks(animation, reverse_bone_map)
		_remove_horizontal_root_motion(animation)
		animation.loop_mode = (
			Animation.LOOP_LINEAR if bool(clip.get("loop", false)) else Animation.LOOP_NONE
		)
		var clip_name: StringName = StringName(clip.get("name", ""))
		if library.add_animation(clip_name, animation) != OK:
			_fail("Unable to add canonical animation %s" % clip_name)
			return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var save_error: Error = ResourceSaver.save(library, OUTPUT_PATH)
	if save_error != OK:
		_fail("Unable to save %s: %s" % [OUTPUT_PATH, error_string(save_error)])
		return
	print("Wrote %d canonical animations to %s" % [library.get_animation_list().size(), OUTPUT_PATH])
	quit(0)


func _load_source_animation(path: String) -> Animation:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var root: Node = packed.instantiate()
	for player_node: Node in root.find_children("*", "AnimationPlayer", true, false):
		var player: AnimationPlayer = player_node as AnimationPlayer
		for library_name: StringName in player.get_animation_library_list():
			var library: AnimationLibrary = player.get_animation_library(library_name)
			for animation_name: StringName in library.get_animation_list():
				var animation: Animation = library.get_animation(animation_name)
				root.free()
				return animation
	root.free()
	return null


func _reverse_bone_map(manifest: Dictionary) -> Dictionary:
	var reverse: Dictionary = {}
	var mappings: Dictionary = manifest.get("bone_map", {}) as Dictionary
	for profile_bone: String in mappings:
		var imported_bone: String = str(mappings[profile_bone]).replace(":", "_")
		reverse[imported_bone] = profile_bone
	return reverse


func _retarget_tracks(animation: Animation, reverse_bone_map: Dictionary) -> void:
	for track_index: int in range(animation.get_track_count() - 1, -1, -1):
		var path: NodePath = animation.track_get_path(track_index)
		if path.get_subname_count() == 0:
			animation.remove_track(track_index)
			continue
		var source_bone: String = path.get_subname(path.get_subname_count() - 1)
		if not reverse_bone_map.has(source_bone):
			animation.remove_track(track_index)
			continue
		var profile_bone: String = str(reverse_bone_map[source_bone])
		animation.track_set_path(track_index, NodePath("NauSkeleton:%s" % profile_bone))


func _remove_horizontal_root_motion(animation: Animation) -> void:
	for track_index: int in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		if str(animation.track_get_path(track_index)) != "NauSkeleton:Hips":
			continue
		if animation.track_get_key_count(track_index) == 0:
			continue
		var anchor: Vector3 = animation.track_get_key_value(track_index, 0) as Vector3
		for key_index: int in animation.track_get_key_count(track_index):
			var value: Vector3 = animation.track_get_key_value(track_index, key_index) as Vector3
			animation.track_set_key_value(
				track_index,
				key_index,
				Vector3(anchor.x, value.y, anchor.z)
			)


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
