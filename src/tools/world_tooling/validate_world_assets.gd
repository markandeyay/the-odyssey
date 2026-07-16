extends SceneTree

const GripMaterialValidator: Script = preload("res://src/tools/world_tooling/grip_material_validator.gd")
const AttributionValidator: Script = preload("res://src/tools/world_tooling/attribution_validator.gd")
const SceneBudgetChecker: Script = preload("res://src/tools/world_tooling/scene_budget_checker.gd")


func _initialize() -> void:
	var issues: Array[String] = []
	var grip_validator: RefCounted = GripMaterialValidator.new() as RefCounted
	issues.append_array(grip_validator.validate_world_scenes())
	var attribution_validator: RefCounted = AttributionValidator.new() as RefCounted
	issues.append_array(attribution_validator.validate_repository())
	var budget_checker: RefCounted = SceneBudgetChecker.new() as RefCounted
	issues.append_array(budget_checker.validate_lanka_scenes())
	if issues.is_empty():
		print("PASS: WORLD materials, attributions, and scene budgets are valid")
		quit(0)
		return
	for issue: String in issues:
		printerr("VALIDATION ERROR: %s" % issue)
	printerr("FAIL: %d WORLD validation error(s)" % issues.size())
	quit(1)
