extends SceneTree

const GripMaterialValidator: Script = preload("res://src/tools/world_tooling/grip_material_validator.gd")
const AttributionValidator: Script = preload("res://src/tools/world_tooling/attribution_validator.gd")
const SceneBudgetChecker: Script = preload("res://src/tools/world_tooling/scene_budget_checker.gd")
const LankaTerrainValidator: Script = preload("res://src/tools/terrain_pipeline/lanka_terrain_validator.gd")
const LankaDistrictValidator: Script = preload("res://src/tools/terrain_pipeline/lanka_district_validator.gd")
const LankaContentValidator: Script = preload("res://src/tools/terrain_pipeline/lanka_content_validator.gd")


func _initialize() -> void:
	var issues: Array[String] = []
	var grip_validator: RefCounted = GripMaterialValidator.new() as RefCounted
	issues.append_array(grip_validator.validate_world_scenes())
	var attribution_validator: RefCounted = AttributionValidator.new() as RefCounted
	issues.append_array(attribution_validator.validate_repository())
	var budget_checker: RefCounted = SceneBudgetChecker.new() as RefCounted
	issues.append_array(budget_checker.validate_lanka_scenes())
	var terrain_validator: RefCounted = LankaTerrainValidator.new() as RefCounted
	issues.append_array(terrain_validator.validate_repository())
	var district_validator: RefCounted = LankaDistrictValidator.new() as RefCounted
	issues.append_array(district_validator.validate_all())
	var content_validator: RefCounted = LankaContentValidator.new() as RefCounted
	issues.append_array(content_validator.validate_repository())
	if issues.is_empty():
		print("PASS: WORLD materials, attributions, budgets, terrain, districts, and M6 content are valid")
		quit(0)
		return
	for issue: String in issues:
		printerr("VALIDATION ERROR: %s" % issue)
	printerr("FAIL: %d WORLD validation error(s)" % issues.size())
	quit(1)
