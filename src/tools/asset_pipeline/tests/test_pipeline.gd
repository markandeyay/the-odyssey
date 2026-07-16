extends SceneTree

const PolyHavenProvider: Script = preload("res://src/tools/asset_pipeline/poly_haven_provider.gd")
const AmbientCgProvider: Script = preload("res://src/tools/asset_pipeline/ambient_cg_provider.gd")
const MaterialLibrary: Script = preload("res://src/tools/asset_pipeline/material_library.gd")

var _failures: int = 0


func _initialize() -> void:
	_test_poly_haven_file_selection()
	_test_ambient_cg_archive_selection()
	_test_map_classification()
	_test_grip_material_names()
	_test_import_contract()
	if _failures == 0:
		print("PASS: Odyssey M1 asset pipeline tests")
	else:
		printerr("FAIL: %d Odyssey M1 asset pipeline assertion(s)" % _failures)
	quit(_failures)


func _test_poly_haven_file_selection() -> void:
	var fixture: Dictionary = {
		"Diffuse": {"2k": {"png": {"url": "https://example.test/diff.png", "md5": "a", "size": 1}}},
		"Rough": {"2k": {"png": {"url": "https://example.test/rough.png", "md5": "b", "size": 2}}},
		"nor_gl": {"2k": {"png": {"url": "https://example.test/normal.png", "md5": "c", "size": 3}}},
		"nor_dx": {"2k": {"png": {"url": "https://example.test/wrong.png", "md5": "d", "size": 4}}},
	}
	var selected: Array[Dictionary] = PolyHavenProvider.select_files(fixture, "2k")
	_expect(selected.size() == 3, "Poly Haven selects the three required GL maps")
	_expect(str(selected[2].get("map", "")) == "normal", "Poly Haven selects OpenGL normals")
	_expect(PolyHavenProvider.is_safe_asset_id("burnt_stone_01"), "valid Poly Haven id accepted")
	_expect(not PolyHavenProvider.is_safe_asset_id("../escape"), "unsafe Poly Haven id rejected")


func _test_ambient_cg_archive_selection() -> void:
	var fixture: Dictionary = {
		"foundAssets": [{
			"assetId": "Rock001",
			"downloadFolders": {"default": {"downloadFiletypeCategories": {"zip": {"downloads": [
				{"attribute": "1K-PNG", "fullDownloadPath": "https://example.test/1k.zip", "fileName": "Rock001_1K-PNG.zip", "size": 1},
				{"attribute": "2K-PNG", "fullDownloadPath": "https://example.test/2k.zip", "fileName": "Rock001_2K-PNG.zip", "size": 2},
			]}}}},
		}],
	}
	var asset: Dictionary = AmbientCgProvider.find_asset(fixture, "Rock001")
	var archive: Dictionary = AmbientCgProvider.select_archive(asset, "2k")
	_expect(str(archive.get("url", "")) == "https://example.test/2k.zip", "ambientCG selects requested PNG resolution")
	_expect(not AmbientCgProvider.is_safe_asset_id("Rock001/../../bad"), "unsafe ambientCG id rejected")


func _test_map_classification() -> void:
	_expect(MaterialLibrary.classify_map("Rock001_2K-PNG_Color.png") == "albedo", "ambientCG color map normalized")
	_expect(MaterialLibrary.classify_map("Rock001_2K-PNG_NormalGL.png") == "normal", "OpenGL normal map normalized")
	_expect(MaterialLibrary.classify_map("Rock001_2K-PNG_NormalDX.png").is_empty(), "DirectX normal map rejected")
	_expect(MaterialLibrary.classify_map("Rock001_2K-PNG_Roughness.png") == "roughness", "roughness map normalized")


func _test_grip_material_names() -> void:
	_expect(
		MaterialLibrary.material_name_for("Burnt Stone 01", "crumbling") == "mat_burnt_stone_01_grip_crumbling",
		"material naming follows the grip contract"
	)


func _test_import_contract() -> void:
	var presets: ConfigFile = ConfigFile.new()
	var load_error: Error = presets.load("res://src/tools/asset_pipeline/import_presets.cfg")
	_expect(load_error == OK, "import preset file loads")
	_expect(is_equal_approx(float(presets.get_value("contract", "meters_per_unit", 0.0)), 1.0), "one unit equals one meter")
	_expect(is_equal_approx(float(presets.get_value("contract", "nau_height_m", 0.0)), 1.9), "Nau scale reference is 1.9m")
	_expect(bool(presets.get_value("scene", "meshes/generate_lods", false)), "scene LOD generation enabled")
	_expect(bool(presets.get_value("texture", "mipmaps/generate", false)), "texture mipmaps enabled")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("ASSERTION FAILED: %s" % message)
