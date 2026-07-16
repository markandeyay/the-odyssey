extends SceneTree

const HttpClientScript: Script = preload("res://src/tools/asset_pipeline/http_client.gd")
const PolyHavenProvider: Script = preload("res://src/tools/asset_pipeline/poly_haven_provider.gd")
const AmbientCgProvider: Script = preload("res://src/tools/asset_pipeline/ambient_cg_provider.gd")
const MaterialLibrary: Script = preload("res://src/tools/asset_pipeline/material_library.gd")
const AttributionLedger: Script = preload("res://src/tools/asset_pipeline/attribution_ledger.gd")
const SUPPORTED_RESOLUTIONS: PackedStringArray = ["1k", "2k", "4k"]
const SUPPORTED_GRIP_CLASSES: PackedStringArray = ["solid", "crumbling", "slick", "hot"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options: Dictionary = _parse_options(OS.get_cmdline_user_args())
	if bool(options.get("help", false)):
		_print_usage()
		quit(0)
		return
	var validation_error: String = _validate_options(options)
	if not validation_error.is_empty():
		printerr("ERROR: %s" % validation_error)
		_print_usage()
		quit(2)
		return

	var http_client: Node = HttpClientScript.new() as Node
	root.add_child(http_client)
	var provider: String = str(options["provider"])
	var asset_id: String = str(options["asset"])
	var resolution: String = str(options["resolution"])
	print("Fetching legal metadata for %s:%s..." % [provider, asset_id])
	var manifest: Dictionary
	if provider == "poly_haven":
		manifest = await PolyHavenProvider.build_manifest(asset_id, resolution, http_client)
	else:
		manifest = await AmbientCgProvider.build_manifest(asset_id, resolution, http_client)
	if not bool(manifest.get("ok", false)):
		printerr("ERROR: %s" % str(manifest.get("error", "Provider metadata request failed")))
		quit(1)
		return

	print("Installing %s under the CC0-only policy..." % str(manifest.get("name", asset_id)))
	var library: RefCounted = MaterialLibrary.new() as RefCounted
	var install_result: Dictionary = await library.install(manifest, str(options["grip"]), http_client)
	if not bool(install_result.get("ok", false)):
		printerr("ERROR: %s" % str(install_result.get("error", "Material installation failed")))
		quit(1)
		return

	var ledger: RefCounted = AttributionLedger.new() as RefCounted
	var attribution_result: Dictionary = ledger.append(manifest, install_result, str(options["usage"]))
	if not bool(attribution_result.get("ok", false)):
		library.rollback(str(install_result.get("asset_path", "")))
		printerr("ERROR: Material rolled back because attribution failed: %s" % str(attribution_result.get("error", "Unknown error")))
		quit(1)
		return

	print("Installed material: %s" % str(install_result.get("material_path", "")))
	print("Attribution recorded in docs/ATTRIBUTIONS.md")
	quit(0)


func _parse_options(arguments: PackedStringArray) -> Dictionary:
	var options: Dictionary = {
		"provider": "",
		"asset": "",
		"resolution": "2k",
		"grip": "solid",
		"usage": "Lanka material library; placement to be determined during district authoring.",
		"help": false,
	}
	for argument: String in arguments:
		if argument in ["--help", "-h"]:
			options["help"] = true
			continue
		if not argument.begins_with("--") or "=" not in argument:
			continue
		var separator: int = argument.find("=")
		var key: String = argument.substr(2, separator - 2)
		var value: String = argument.substr(separator + 1)
		if options.has(key):
			options[key] = value
	return options


func _validate_options(options: Dictionary) -> String:
	var provider: String = str(options.get("provider", ""))
	if provider not in ["poly_haven", "ambient_cg"]:
		return "--provider must be poly_haven or ambient_cg"
	if str(options.get("asset", "")).is_empty():
		return "--asset is required"
	if str(options.get("resolution", "")) not in SUPPORTED_RESOLUTIONS:
		return "--resolution must be 1k, 2k, or 4k"
	if str(options.get("grip", "")) not in SUPPORTED_GRIP_CLASSES:
		return "--grip must be solid, crumbling, slick, or hot"
	if str(options.get("usage", "")).strip_edges().is_empty():
		return "--usage cannot be empty"
	return ""


func _print_usage() -> void:
	print("Usage:")
	print("  godot --headless --path . --script src/tools/asset_pipeline/material_pipeline.gd -- \\")
	print("    --provider=<poly_haven|ambient_cg> --asset=<provider_id> \\")
	print("    [--resolution=<1k|2k|4k>] [--grip=<solid|crumbling|slick|hot>] \\")
	print("    [--usage=\"intended Lanka usage\"]")
