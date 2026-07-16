extends SceneTree

const LankaTerrainValidator: Script = preload("res://src/tools/terrain_pipeline/lanka_terrain_validator.gd")


func _initialize() -> void:
	var validator: RefCounted = LankaTerrainValidator.new() as RefCounted
	var issues: Array[String] = validator.validate_repository()
	if issues.is_empty():
		print("PASS: Odyssey M4 Lanka terrain scenes and streaming contract")
		quit(0)
		return
	for issue: String in issues:
		printerr("VALIDATION ERROR: %s" % issue)
	printerr("FAIL: %d Odyssey M4 terrain validation error(s)" % issues.size())
	quit(1)
