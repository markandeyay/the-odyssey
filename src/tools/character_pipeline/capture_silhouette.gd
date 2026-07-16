extends SceneTree

const PREVIEW_PATH: String = "res://src/tools/character_pipeline/nau_silhouette_preview.tscn"

var _distance_m: float = 200.0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load(PREVIEW_PATH) as PackedScene
	if packed == null:
		printerr("Unable to load silhouette preview")
		quit(1)
		return
	var preview: Node = packed.instantiate()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("distance="):
			_distance_m = float(argument.trim_prefix("distance="))
	preview.set("viewing_distance_m", _distance_m)
	root.add_child.call_deferred(preview)
	_capture.call_deferred()


func _capture() -> void:
	await process_frame
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty():
		printerr("Silhouette capture returned an empty image")
		quit(1)
		return
	var output_path: String = "res://.godot/nau_silhouette_%dm.png" % int(_distance_m)
	var save_error: Error = image.save_png(output_path)
	if save_error != OK:
		printerr("Unable to save silhouette capture: %s" % error_string(save_error))
		quit(1)
		return
	print("Wrote %dx%d silhouette capture to %s" % [image.get_width(), image.get_height(), output_path])
	quit(0)
