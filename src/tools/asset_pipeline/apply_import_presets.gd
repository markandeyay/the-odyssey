extends SceneTree

const PRESET_PATH: String = "res://src/tools/asset_pipeline/import_presets.cfg"
const WORLD_ROOTS: PackedStringArray = [
	"res://assets/audio",
	"res://assets/characters",
	"res://assets/materials",
	"res://assets/models",
	"res://assets/textures",
]
const SCENE_EXTENSIONS: PackedStringArray = ["fbx", "glb", "gltf", "obj", "blend"]
const TEXTURE_EXTENSIONS: PackedStringArray = ["png", "jpg", "jpeg", "webp", "exr", "hdr"]


func _initialize() -> void:
	var exit_code: int = _apply_presets()
	quit(exit_code)


func _apply_presets() -> int:
	var presets: ConfigFile = ConfigFile.new()
	var load_error: Error = presets.load(PRESET_PATH)
	if load_error != OK:
		push_error("Unable to load import presets: %s" % error_string(load_error))
		return 1

	var source_files: PackedStringArray = PackedStringArray()
	for root: String in WORLD_ROOTS:
		_collect_sources(root, source_files)

	var updated_count: int = 0
	var skipped_count: int = 0
	for source_path: String in source_files:
		var sidecar_path: String = source_path + ".import"
		if not FileAccess.file_exists(sidecar_path):
			printerr("SKIP: Godot has not imported %s yet" % source_path)
			skipped_count += 1
			continue
		var section: String = _preset_section_for(source_path)
		if section.is_empty():
			continue
		if _apply_section(sidecar_path, presets, section):
			updated_count += 1

	print("Import presets updated %d sidecar(s); %d source file(s) need an initial Godot import." % [updated_count, skipped_count])
	return 0


func _collect_sources(root_path: String, output: PackedStringArray) -> void:
	var directory: DirAccess = DirAccess.open(root_path)
	if directory == null:
		return
	for entry: String in directory.get_files():
		var extension: String = entry.get_extension().to_lower()
		if extension in SCENE_EXTENSIONS or extension in TEXTURE_EXTENSIONS:
			output.append(root_path.path_join(entry))
	for child: String in directory.get_directories():
		_collect_sources(root_path.path_join(child), output)


func _preset_section_for(source_path: String) -> String:
	var extension: String = source_path.get_extension().to_lower()
	if extension in SCENE_EXTENSIONS:
		return "scene"
	if extension in TEXTURE_EXTENSIONS:
		var filename: String = source_path.get_file().to_lower()
		if "normal" in filename or "nor_gl" in filename or "_nor_" in filename:
			return "normal_map"
		return "texture"
	return ""


func _apply_section(sidecar_path: String, presets: ConfigFile, section: String) -> bool:
	var sidecar: ConfigFile = ConfigFile.new()
	var load_error: Error = sidecar.load(sidecar_path)
	if load_error != OK:
		push_error("Unable to read %s: %s" % [sidecar_path, error_string(load_error)])
		return false
	for key: String in presets.get_section_keys(section):
		sidecar.set_value("params", key, presets.get_value(section, key))
	var save_error: Error = sidecar.save(sidecar_path)
	if save_error != OK:
		push_error("Unable to update %s: %s" % [sidecar_path, error_string(save_error)])
		return false
	print("UPDATED: %s (%s preset)" % [sidecar_path, section])
	return true
