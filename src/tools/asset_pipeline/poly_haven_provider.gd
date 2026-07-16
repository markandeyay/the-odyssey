extends RefCounted

const API_ROOT: String = "https://api.polyhaven.com"
const SOURCE_ROOT: String = "https://polyhaven.com/a/"
const LICENSE_URL: String = "https://polyhaven.com/license"
const MAP_CANDIDATES: Dictionary = {
	"albedo": ["Diffuse", "diff", "Albedo"],
	"roughness": ["Rough", "rough", "Roughness"],
	"normal": ["nor_gl", "Normal GL", "NormalGL"],
	"ao": ["AO", "ao", "Ambient Occlusion"],
	"metallic": ["Metal", "metal", "Metalness", "metallic"],
	"height": ["Displacement", "disp", "Height"],
}
const REQUIRED_MAPS: PackedStringArray = ["albedo", "roughness", "normal"]


static func build_manifest(asset_id: String, resolution: String, http_client: Node) -> Dictionary:
	if not is_safe_asset_id(asset_id):
		return _failure("Invalid Poly Haven asset id: %s" % asset_id)
	var files_response: Dictionary = await http_client.get_json("%s/files/%s" % [API_ROOT, asset_id])
	if not bool(files_response.get("ok", false)):
		return files_response
	var info_response: Dictionary = await http_client.get_json("%s/info/%s" % [API_ROOT, asset_id])
	if not bool(info_response.get("ok", false)):
		return info_response
	var file_data: Dictionary = files_response.get("data", {}) as Dictionary
	var selected_files: Array[Dictionary] = select_files(file_data, resolution)
	for required_map: String in REQUIRED_MAPS:
		if not _contains_map(selected_files, required_map):
			return _failure("Poly Haven asset %s has no %s map at %s" % [asset_id, required_map, resolution])
	var info: Dictionary = info_response.get("data", {}) as Dictionary
	return {
		"ok": true,
		"provider": "poly_haven",
		"asset_id": asset_id,
		"name": str(info.get("name", asset_id.replace("_", " ").capitalize())),
		"author": _author_from_info(info),
		"license": "CC0 1.0",
		"license_url": LICENSE_URL,
		"source_url": SOURCE_ROOT + asset_id,
		"resolution": resolution,
		"files": selected_files,
	}


static func select_files(file_data: Dictionary, resolution: String) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for normalized_map: String in MAP_CANDIDATES:
		var source_map: Dictionary = _first_dictionary(file_data, MAP_CANDIDATES[normalized_map] as Array)
		if source_map.is_empty():
			continue
		var resolution_data: Dictionary = source_map.get(resolution, {}) as Dictionary
		if resolution_data.is_empty():
			continue
		var format: String = "png" if resolution_data.has("png") else "jpg"
		var file_record: Dictionary = resolution_data.get(format, {}) as Dictionary
		var url: String = str(file_record.get("url", ""))
		if url.is_empty():
			continue
		selected.append({
			"map": normalized_map,
			"extension": format,
			"url": url,
			"md5": str(file_record.get("md5", "")),
			"size": int(file_record.get("size", 0)),
		})
	return selected


static func is_safe_asset_id(asset_id: String) -> bool:
	if asset_id.is_empty():
		return false
	for character: String in asset_id:
		if not (character >= "a" and character <= "z") and not (character >= "0" and character <= "9") and character != "_":
			return false
	return true


static func _first_dictionary(source: Dictionary, candidates: Array) -> Dictionary:
	for candidate: Variant in candidates:
		var key: String = str(candidate)
		if source.get(key) is Dictionary:
			return source[key] as Dictionary
	return {}


static func _contains_map(files: Array[Dictionary], map_name: String) -> bool:
	for file_record: Dictionary in files:
		if str(file_record.get("map", "")) == map_name:
			return true
	return false


static func _author_from_info(info: Dictionary) -> String:
	var authors: Variant = info.get("authors", null)
	if authors is Dictionary:
		var names: PackedStringArray = PackedStringArray()
		for name: Variant in (authors as Dictionary).keys():
			names.append(str(name))
		if not names.is_empty():
			return ", ".join(names)
	if authors is Array:
		var names: PackedStringArray = PackedStringArray()
		for author: Variant in authors:
			if author is Dictionary:
				names.append(str((author as Dictionary).get("name", "Poly Haven")))
			else:
				names.append(str(author))
		if not names.is_empty():
			return ", ".join(names)
	return "Poly Haven"


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
