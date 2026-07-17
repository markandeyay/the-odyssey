extends SceneTree

const ValidatorScript: Script = preload("res://src/tools/terrain_pipeline/lanka_district_validator.gd")


func _initialize() -> void:
	var validator: RefCounted = ValidatorScript.new() as RefCounted
	var district_ids: PackedStringArray = OS.get_cmdline_user_args()
	var issues: Array[String] = validator.validate_all() if district_ids.is_empty() else validator.validate_districts(district_ids)
	if issues.is_empty():
		print("PASS: Lanka M5 district contract: %s" % ("all" if district_ids.is_empty() else ", ".join(district_ids)))
		quit(0)
		return
	for issue: String in issues:
		printerr("VALIDATION ERROR: %s" % issue)
	printerr("FAIL: %d Lanka M5 district validation error(s)" % issues.size())
	quit(1)
