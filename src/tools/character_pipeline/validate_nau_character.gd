extends SceneTree

const NauCharacterValidator: Script = preload("res://src/tools/character_pipeline/nau_character_validator.gd")


func _initialize() -> void:
	var validator: RefCounted = NauCharacterValidator.new() as RefCounted
	var issues: Array[String] = validator.validate_sources()
	issues.append_array(validator.validate_visual_scene())
	if issues.is_empty():
		print("PASS: Nau M3 character contract is valid")
		quit(0)
		return
	for issue: String in issues:
		printerr("CHARACTER VALIDATION ERROR: %s" % issue)
	printerr("FAIL: %d Nau character validation error(s)" % issues.size())
	quit(1)
