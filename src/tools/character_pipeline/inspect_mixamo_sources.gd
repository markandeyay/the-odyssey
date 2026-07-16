extends SceneTree

const ANIMATION_ROOT: String = "res://assets/characters/nau/source/mixamo/animations"


func _initialize() -> void:
	var filenames: PackedStringArray = DirAccess.get_files_at(ANIMATION_ROOT)
	filenames.sort()
	for filename: String in filenames:
		if filename.get_extension().to_lower() != "fbx":
			continue
		_inspect_scene(ANIMATION_ROOT.path_join(filename))
	quit(0)


func _inspect_scene(path: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		printerr("%s: LOAD FAILED" % path)
		return
	var root: Node = packed.instantiate()
	var skeletons: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	var players: Array[Node] = root.find_children("*", "AnimationPlayer", true, false)
	var bones: PackedStringArray = PackedStringArray()
	if not skeletons.is_empty():
		var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
		for bone_index: int in skeleton.get_bone_count():
			bones.append(skeleton.get_bone_name(bone_index))
	print("SOURCE %s" % path.get_file())
	print("  nodes=%d skeletons=%d meshes=%d players=%d bones=%d" % [
		_count_nodes(root), skeletons.size(), meshes.size(), players.size(), bones.size()
	])
	print("  bone_sample=%s" % ",".join(bones.slice(0, mini(8, bones.size()))))
	for player_node: Node in players:
		var player: AnimationPlayer = player_node as AnimationPlayer
		for library_name: StringName in player.get_animation_library_list():
			var library: AnimationLibrary = player.get_animation_library(library_name)
			for animation_name: StringName in library.get_animation_list():
				var animation: Animation = library.get_animation(animation_name)
				print("  animation=%s length=%.3f tracks=%d loop=%d horizontal_delta=%.4f" % [
					animation_name,
					animation.length,
					animation.get_track_count(),
					animation.loop_mode,
					_horizontal_root_delta(animation),
				])
				var sample_count: int = mini(3, animation.get_track_count())
				var paths: PackedStringArray = PackedStringArray()
				for track_index: int in sample_count:
					paths.append(str(animation.track_get_path(track_index)))
				print("  track_sample=%s" % " | ".join(paths))
	root.free()


func _horizontal_root_delta(animation: Animation) -> float:
	var maximum_delta: float = 0.0
	for track_index: int in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		var track_path: String = str(animation.track_get_path(track_index)).to_lower()
		if "hips" not in track_path and "root" not in track_path:
			continue
		var first: Vector3 = animation.position_track_interpolate(track_index, 0.0)
		var last: Vector3 = animation.position_track_interpolate(track_index, animation.length)
		maximum_delta = maxf(maximum_delta, Vector2(last.x - first.x, last.z - first.z).length())
	return maximum_delta


func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count
