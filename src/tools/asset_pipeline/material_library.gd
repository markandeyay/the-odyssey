extends RefCounted

const LIBRARY_ROOT: String = "res://assets/materials/library"
const STAGING_ROOT: String = "user://odyssey_asset_pipeline"
const REQUIRED_MAPS: PackedStringArray = ["albedo", "roughness", "normal"]
const GRIP_CLASSES: PackedStringArray = ["solid", "crumbling", "slick", "hot"]
const IMAGE_EXTENSIONS: PackedStringArray = ["png", "jpg", "jpeg", "webp", "exr"]


func install(manifest: Dictionary, grip_class: String, http_client: Node) -> Dictionary:
	if grip_class not in GRIP_CLASSES:
		return _failure("Invalid grip class: %s" % grip_class)
	if str(manifest.get("license", "")) != "CC0 1.0":
		return _failure("Refusing asset without an explicit CC0 1.0 manifest")
	var provider: String = str(manifest.get("provider", ""))
	var asset_id: String = str(manifest.get("asset_id", ""))
	var slug: String = _slugify(asset_id)
	if slug.is_empty():
		return _failure("Unable to derive a safe asset slug from %s" % asset_id)
	var target_path: String = LIBRARY_ROOT.path_join(provider).path_join(slug)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target_path)):
		return _failure("Asset already exists and will not be overwritten: %s" % target_path)

	var staging_path: String = STAGING_ROOT.path_join("%s_%s_%d" % [provider, slug, Time.get_ticks_msec()])
	var prepare_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(staging_path))
	if prepare_error != OK:
		return _failure("Unable to create staging directory: %s" % error_string(prepare_error))

	var maps: Dictionary = {}
	var stage_result: Dictionary
	if provider == "poly_haven":
		stage_result = await _stage_poly_haven(manifest, staging_path, http_client)
	elif provider == "ambient_cg":
		stage_result = await _stage_ambient_cg(manifest, staging_path, http_client)
	else:
		_cleanup_directory(staging_path, STAGING_ROOT)
		return _failure("Unsupported material provider: %s" % provider)
	if not bool(stage_result.get("ok", false)):
		_cleanup_directory(staging_path, STAGING_ROOT)
		return stage_result
	maps = stage_result.get("maps", {}) as Dictionary
	for required_map: String in REQUIRED_MAPS:
		if not maps.has(required_map):
			_cleanup_directory(staging_path, STAGING_ROOT)
			return _failure("Downloaded material is missing required %s map" % required_map)

	var target_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_path))
	if target_error != OK:
		_cleanup_directory(staging_path, STAGING_ROOT)
		return _failure("Unable to create material directory: %s" % error_string(target_error))
	var installed_maps: Dictionary = {}
	for map_name: String in maps:
		var source_path: String = str(maps[map_name])
		var extension: String = source_path.get_extension().to_lower()
		var destination_path: String = target_path.path_join("%s_%s.%s" % [slug, map_name, extension])
		var copy_error: Error = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(source_path),
			ProjectSettings.globalize_path(destination_path)
		)
		if copy_error != OK:
			_cleanup_directory(staging_path, STAGING_ROOT)
			_cleanup_directory(target_path, LIBRARY_ROOT)
			return _failure("Unable to install %s map: %s" % [map_name, error_string(copy_error)])
		installed_maps[map_name] = destination_path

	var material_name: String = material_name_for(slug, grip_class)
	var material_path: String = target_path.path_join(material_name + ".tres")
	var material_error: Error = _write_material(material_path, material_name, installed_maps)
	if material_error != OK:
		_cleanup_directory(staging_path, STAGING_ROOT)
		_cleanup_directory(target_path, LIBRARY_ROOT)
		return _failure("Unable to build Godot material: %s" % error_string(material_error))
	var manifest_path: String = target_path.path_join("asset_manifest.json")
	var manifest_error: Error = _write_manifest(manifest_path, manifest, installed_maps, material_path)
	if manifest_error != OK:
		_cleanup_directory(staging_path, STAGING_ROOT)
		_cleanup_directory(target_path, LIBRARY_ROOT)
		return _failure("Unable to write asset manifest: %s" % error_string(manifest_error))
	_cleanup_directory(staging_path, STAGING_ROOT)
	return {
		"ok": true,
		"asset_path": target_path,
		"material_path": material_path,
		"maps": installed_maps,
	}


func rollback(asset_path: String) -> void:
	_cleanup_directory(asset_path, LIBRARY_ROOT)


static func material_name_for(slug: String, grip_class: String) -> String:
	return "mat_%s_grip_%s" % [_slugify(slug), grip_class]


static func classify_map(filename: String) -> String:
	var lower: String = filename.get_basename().to_lower().replace("-", "_")
	if "normaldx" in lower or "normal_dx" in lower or "nor_dx" in lower:
		return ""
	if "normalgl" in lower or "normal_gl" in lower or "nor_gl" in lower:
		return "normal"
	if "basecolor" in lower or "base_color" in lower or "diffuse" in lower or "albedo" in lower or "_color" in lower:
		return "albedo"
	if "roughness" in lower or "_rough" in lower:
		return "roughness"
	if "ambientocclusion" in lower or "ambient_occlusion" in lower or lower.ends_with("_ao"):
		return "ao"
	if "metalness" in lower or "metallic" in lower or lower.ends_with("_metal"):
		return "metallic"
	if "displacement" in lower or "_height" in lower or lower.ends_with("_disp"):
		return "height"
	return ""


func _stage_poly_haven(manifest: Dictionary, staging_path: String, http_client: Node) -> Dictionary:
	var maps: Dictionary = {}
	var files: Array = manifest.get("files", []) as Array
	for value: Variant in files:
		if not value is Dictionary:
			continue
		var file_record: Dictionary = value as Dictionary
		var map_name: String = str(file_record.get("map", ""))
		var extension: String = str(file_record.get("extension", "png"))
		var destination_path: String = staging_path.path_join("%s.%s" % [map_name, extension])
		var download_result: Dictionary = await http_client.download(str(file_record.get("url", "")), destination_path)
		if not bool(download_result.get("ok", false)):
			return download_result
		var expected_md5: String = str(file_record.get("md5", ""))
		if not expected_md5.is_empty():
			var actual_md5: String = FileAccess.get_md5(destination_path)
			if actual_md5.to_lower() != expected_md5.to_lower():
				return _failure("MD5 mismatch for %s map" % map_name)
		maps[map_name] = destination_path
	return {"ok": true, "maps": maps}


func _stage_ambient_cg(manifest: Dictionary, staging_path: String, http_client: Node) -> Dictionary:
	var archive: Dictionary = manifest.get("archive", {}) as Dictionary
	var archive_path: String = staging_path.path_join("material.zip")
	var download_result: Dictionary = await http_client.download(str(archive.get("url", "")), archive_path)
	if not bool(download_result.get("ok", false)):
		return download_result
	var zip: ZIPReader = ZIPReader.new()
	var open_error: Error = zip.open(archive_path)
	if open_error != OK:
		return _failure("Unable to open ambientCG archive: %s" % error_string(open_error))
	var maps: Dictionary = {}
	for archived_path: String in zip.get_files():
		if archived_path.ends_with("/") or ".." in archived_path:
			continue
		var basename: String = archived_path.get_file()
		var extension: String = basename.get_extension().to_lower()
		if extension not in IMAGE_EXTENSIONS:
			continue
		var map_name: String = classify_map(basename)
		if map_name.is_empty() or maps.has(map_name):
			continue
		var contents: PackedByteArray = zip.read_file(archived_path)
		if contents.is_empty():
			continue
		var destination_path: String = staging_path.path_join("%s.%s" % [map_name, extension])
		var output: FileAccess = FileAccess.open(destination_path, FileAccess.WRITE)
		if output == null:
			zip.close()
			return _failure("Unable to extract %s" % basename)
		output.store_buffer(contents)
		output.close()
		maps[map_name] = destination_path
	zip.close()
	return {"ok": true, "maps": maps}


func _write_material(path: String, material_name: String, maps: Dictionary) -> Error:
	var ordered_maps: PackedStringArray = ["albedo", "roughness", "normal", "ao", "metallic"]
	var resource_ids: Dictionary = {}
	var external_resources: PackedStringArray = PackedStringArray()
	var next_id: int = 1
	for map_name: String in ordered_maps:
		if maps.has(map_name):
			resource_ids[map_name] = next_id
			external_resources.append(
				"[ext_resource type=\"Texture2D\" path=\"%s\" id=\"%d_%s\"]"
				% [str(maps[map_name]), next_id, map_name]
			)
			next_id += 1
	var lines: PackedStringArray = PackedStringArray([
		"[gd_resource type=\"StandardMaterial3D\" load_steps=%d format=3]" % next_id,
		"",
		"\n\n".join(external_resources),
		"",
		"[resource]",
		"resource_name = \"%s\"" % material_name,
	])
	if resource_ids.has("albedo"):
		lines.append("albedo_texture = ExtResource(\"%d_albedo\")" % int(resource_ids["albedo"]))
	if resource_ids.has("roughness"):
		lines.append("roughness_texture = ExtResource(\"%d_roughness\")" % int(resource_ids["roughness"]))
		lines.append("roughness_texture_channel = 0")
	if resource_ids.has("normal"):
		lines.append("normal_enabled = true")
		lines.append("normal_texture = ExtResource(\"%d_normal\")" % int(resource_ids["normal"]))
	if resource_ids.has("ao"):
		lines.append("ao_enabled = true")
		lines.append("ao_texture = ExtResource(\"%d_ao\")" % int(resource_ids["ao"]))
		lines.append("ao_texture_channel = 0")
	if resource_ids.has("metallic"):
		lines.append("metallic = 1.0")
		lines.append("metallic_texture = ExtResource(\"%d_metallic\")" % int(resource_ids["metallic"]))
		lines.append("metallic_texture_channel = 0")
	lines.append("")
	var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		return FileAccess.get_open_error()
	output.store_string("\n".join(lines))
	output.close()
	return OK


func _write_manifest(path: String, provider_manifest: Dictionary, maps: Dictionary, material_path: String) -> Error:
	var stored_manifest: Dictionary = provider_manifest.duplicate(true)
	stored_manifest.erase("files")
	stored_manifest.erase("archive")
	stored_manifest["installed_maps"] = maps
	stored_manifest["material_path"] = material_path
	stored_manifest["date_pulled"] = Time.get_date_string_from_system()
	var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		return FileAccess.get_open_error()
	output.store_string(JSON.stringify(stored_manifest, "\t", false) + "\n")
	output.close()
	return OK


static func _slugify(value: String) -> String:
	var lower: String = value.to_lower()
	var slug: String = ""
	var previous_was_separator: bool = false
	for character: String in lower:
		var is_alphanumeric: bool = (character >= "a" and character <= "z") or (character >= "0" and character <= "9")
		if is_alphanumeric:
			slug += character
			previous_was_separator = false
		elif not previous_was_separator:
			slug += "_"
			previous_was_separator = true
	return slug.trim_prefix("_").trim_suffix("_")


func _cleanup_directory(path: String, allowed_root: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(path).simplify_path()
	var global_root: String = ProjectSettings.globalize_path(allowed_root).simplify_path()
	if global_path == global_root or not global_path.begins_with(global_root + "/"):
		push_error("Refusing cleanup outside pipeline root: %s" % path)
		return
	_remove_tree(global_path)


func _remove_tree(global_path: String) -> void:
	var directory: DirAccess = DirAccess.open(global_path)
	if directory == null:
		return
	for filename: String in directory.get_files():
		DirAccess.remove_absolute(global_path.path_join(filename))
	for child: String in directory.get_directories():
		_remove_tree(global_path.path_join(child))
	DirAccess.remove_absolute(global_path)


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
