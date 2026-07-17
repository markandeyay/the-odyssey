extends SceneTree

const ValidatorScript: Script = preload("res://src/tools/terrain_pipeline/lanka_visual_validator.gd")


func _initialize() -> void:
	var validator: RefCounted = ValidatorScript.new() as RefCounted
	var issues: Array[String] = validator.validate_repository()
	if issues.is_empty():
		print("PASS: Lanka M7 stylized PBR, atmosphere, ocean, and bounded VFX contract")
		quit(0)
		return
	for issue: String in issues:
		printerr("VALIDATION ERROR: %s" % issue)
	printerr("FAIL: %d Lanka M7 visual validation error(s)" % issues.size())
	quit(1)
