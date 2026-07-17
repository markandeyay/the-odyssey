extends SceneTree

const ValidatorScript: Script = preload("res://src/tools/terrain_pipeline/lanka_performance_validator.gd")


func _initialize() -> void:
	var validator: RefCounted = ValidatorScript.new() as RefCounted
	var issues: Array[String] = validator.validate_repository()
	if issues.is_empty():
		print("PASS: Lanka M8 LOD, batching, occlusion, light, VFX, and texture budgets")
		quit(0)
		return
	for issue: String in issues:
		printerr("VALIDATION ERROR: %s" % issue)
	printerr("FAIL: %d Lanka M8 performance validation error(s)" % issues.size())
	quit(1)
