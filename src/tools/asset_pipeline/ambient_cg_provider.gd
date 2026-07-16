extends RefCounted

const API_URL: String = "https://ambientcg.com/api/v2/full_json"
const SOURCE_ROOT: String = "https://ambientcg.com/a/"
const LICENSE_URL: String = "https://docs.ambientcg.com/license/"


static func build_manifest(asset_id: String, resolution: String, http_client: Node) -> Dictionary:
	if not is_safe_asset_id(asset_id):
		return _failure("Invalid ambientCG asset id: %s" % asset_id)
	var query_url: String = (
		"%s?type=Material&id=%s&limit=1&include=downloadData" % [API_URL, asset_id.uri_encode()]
	)
	var response: Dictionary = await http_client.get_json(query_url)
	if not bool(response.get("ok", false)):
		return response
	var response_data: Dictionary = response.get("data", {}) as Dictionary
	var asset: Dictionary = find_asset(response_data, asset_id)
	if asset.is_empty():
		return _failure("ambientCG did not return material %s" % asset_id)
	var archive: Dictionary = select_archive(asset, resolution)
	if archive.is_empty():
		return _failure("ambientCG material %s has no PNG archive at %s" % [asset_id, resolution])
	return {
		"ok": true,
		"provider": "ambient_cg",
		"asset_id": asset_id,
		"name": str(asset.get("displayName", asset_id)),
		"author": "ambientCG (Lennart Demes)",
		"license": "CC0 1.0",
		"license_url": LICENSE_URL,
		"source_url": str(asset.get("shortLink", SOURCE_ROOT + asset_id)),
		"resolution": resolution,
		"archive": archive,
	}


static func find_asset(response_data: Dictionary, asset_id: String) -> Dictionary:
	var assets: Array = response_data.get("foundAssets", response_data.get("assets", [])) as Array
	for item: Variant in assets:
		if item is Dictionary:
			var asset: Dictionary = item as Dictionary
			if str(asset.get("assetId", asset.get("id", ""))).to_lower() == asset_id.to_lower():
				return asset
	return {}


static func select_archive(asset: Dictionary, resolution: String) -> Dictionary:
	var desired_attribute: String = resolution.to_upper() + "-PNG"
	var folders: Dictionary = asset.get("downloadFolders", {}) as Dictionary
	for folder_value: Variant in folders.values():
		if not folder_value is Dictionary:
			continue
		var categories: Dictionary = (folder_value as Dictionary).get("downloadFiletypeCategories", {}) as Dictionary
		for category_value: Variant in categories.values():
			if not category_value is Dictionary:
				continue
			var downloads: Array = (category_value as Dictionary).get("downloads", []) as Array
			for download_value: Variant in downloads:
				if not download_value is Dictionary:
					continue
				var download: Dictionary = download_value as Dictionary
				if str(download.get("attribute", "")).to_upper() == desired_attribute:
					var url: String = str(download.get("fullDownloadPath", download.get("downloadLink", "")))
					if not url.is_empty():
						return {
							"url": url,
							"filename": str(download.get("fileName", asset.get("assetId", "material"))) + ".zip" if not str(download.get("fileName", "")).ends_with(".zip") else str(download.get("fileName", "")),
							"size": int(download.get("size", 0)),
						}
	return {}


static func is_safe_asset_id(asset_id: String) -> bool:
	if asset_id.is_empty():
		return false
	for character: String in asset_id:
		if not (character >= "a" and character <= "z") and not (character >= "A" and character <= "Z") and not (character >= "0" and character <= "9") and character != "_":
			return false
	return true


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
