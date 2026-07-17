extends SceneTree

const ValidatorScript: Script = preload("res://src/tools/terrain_pipeline/lanka_content_validator.gd")


func _initialize() -> void:
	var validator: RefCounted = ValidatorScript.new() as RefCounted
	var issues: Array[String] = validator.validate_repository()
	if issues.is_empty():
		print("PASS: Lanka M6 exact content placement and Cairn contract")
		quit(0)
		return
	for issue: String in issues:
		printerr("VALIDATION ERROR: %s" % issue)
	printerr("FAIL: %d Lanka M6 content validation error(s)" % issues.size())
	quit(1)
