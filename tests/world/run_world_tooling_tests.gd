extends Node

const GripMaterialValidator: Script = preload("res://src/tools/world_tooling/grip_material_validator.gd")
const AttributionValidator: Script = preload("res://src/tools/world_tooling/attribution_validator.gd")
const SceneBudgetChecker: Script = preload("res://src/tools/world_tooling/scene_budget_checker.gd")

var _failures: int = 0


func _ready() -> void:
	_test_grip_material_validation()
	_test_attribution_validation()
	_test_budget_analysis()
	_test_terrain_generation_and_sculpting()
	_test_scatter_configuration()
	_test_terrain_shader()
	if _failures == 0:
		print("PASS: Odyssey M2 world tooling tests")
	else:
		printerr("FAIL: %d Odyssey M2 assertion(s)" % _failures)
	get_tree().quit(_failures)


func _test_grip_material_validation() -> void:
	var validator: RefCounted = GripMaterialValidator.new() as RefCounted
	var root: Node3D = Node3D.new()
	root.name = "GripFixture"
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ClimbableBody"
	body.collision_layer = 1 << 2
	root.add_child(body)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "CliffMesh"
	var mesh: BoxMesh = BoxMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = "mat_clean_stone_grip_solid"
	mesh.material = material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var valid_issues: Array[String] = validator.validate_root(root, "fixture")
	_expect(valid_issues.is_empty(), "valid climbable material passes")
	material.resource_name = "stone"
	var invalid_issues: Array[String] = validator.validate_root(root, "fixture")
	_expect(invalid_issues.size() == 1, "invalid climbable material fails once")
	_expect("mat_<name>_grip_<class>" in invalid_issues[0], "grip failure explains the contract")
	root.free()


func _test_attribution_validation() -> void:
	var ledger_file: FileAccess = FileAccess.open("res://docs/ATTRIBUTIONS.md", FileAccess.READ)
	_expect(ledger_file != null, "attribution ledger opens")
	if ledger_file == null:
		return
	var ledger_text: String = ledger_file.get_as_text()
	ledger_file.close()
	var validator: RefCounted = AttributionValidator.new() as RefCounted
	var covered_files: PackedStringArray = PackedStringArray([
		"res://assets/materials/library/ambient_cg/rock064/rock064_albedo.png",
		"res://assets/materials/library/poly_haven/aerial_rocks_04/aerial_rocks_04_normal.png",
	])
	var covered_issues: Array[String] = validator.validate(ledger_text, covered_files)
	_expect(covered_issues.is_empty(), "attributed asset package paths pass")
	covered_files.append("res://assets/unattributed.bin")
	var uncovered_issues: Array[String] = validator.validate(ledger_text, covered_files)
	_expect(uncovered_issues.size() == 1, "unattributed asset fails once")
	_expect("has no ATTRIBUTIONS.md entry" in uncovered_issues[0], "unattributed failure is actionable")


func _test_budget_analysis() -> void:
	var checker: RefCounted = SceneBudgetChecker.new() as RefCounted
	var root: Node3D = Node3D.new()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	root.add_child(mesh_instance)
	var light: OmniLight3D = OmniLight3D.new()
	root.add_child(light)
	var multimesh_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = 5
	multimesh_instance.multimesh = multimesh
	root.add_child(multimesh_instance)
	var metrics: Dictionary = checker.analyze_root(root)
	_expect(int(metrics.get("draw_calls", 0)) == 2, "budget checker counts mesh and MultiMesh surfaces")
	_expect(int(metrics.get("triangles", 0)) == 72, "budget checker counts MultiMesh triangle multiplicity")
	_expect(int(metrics.get("active_lights", 0)) == 1, "budget checker counts visible lights")
	var over_budget: Dictionary = {
		"draw_calls": 251,
		"triangles": 350001,
		"active_lights": 7,
	}
	var issues: Array[String] = checker.validate_metrics(over_budget, "cairn")
	_expect(issues.size() == 3, "scene budget fails every exceeded metric")
	root.free()


func _test_terrain_generation_and_sculpting() -> void:
	var terrain: OdysseyTerrain3D = OdysseyTerrain3D.new()
	terrain.grid_resolution = 9
	terrain.size_m = Vector2(8.0, 8.0)
	terrain.minimum_height_m = 0.0
	terrain.maximum_height_m = 10.0
	var result: Dictionary = terrain.rebuild()
	_expect(bool(result.get("ok", false)), "terrain rebuild succeeds")
	_expect(int(result.get("vertices", 0)) == 81, "terrain builds expected vertex grid")
	_expect(int(result.get("triangles", 0)) == 128, "terrain builds expected triangle grid")
	terrain.sculpt(Vector3.ZERO, 2.0, 1.0, "raise")
	_expect(terrain.sample_height_local(0.0, 0.0) > 0.9, "terrain raise brush changes stored height")
	var collision_body: StaticBody3D = terrain.get_node_or_null("TerrainCollisionBody") as StaticBody3D
	_expect(collision_body != null, "terrain creates collision body")
	if collision_body != null:
		_expect(collision_body.collision_layer == 1, "terrain collision stays on world layer 1")
	terrain.free()


func _test_scatter_configuration() -> void:
	var scatter: OdysseyScatter3D = OdysseyScatter3D.new()
	add_child(scatter)
	var result: Dictionary = scatter.rebuild()
	_expect(not bool(result.get("ok", true)), "scatter rejects missing prop sources")
	_expect(str(result.get("error", "")) == "Assign at least one prop scene", "scatter error identifies missing sources")
	var generated_state: Dictionary = {
		"paint_stroke_index": 3,
		"groups": [{
			"name": "Scatter_00",
			"mesh": BoxMesh.new(),
			"material": null,
			"source_path": "res://scenes/prefabs/props/test_prop.tscn",
			"transforms": [
				Transform3D(Basis.IDENTITY, Vector3.ZERO),
				Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0)),
			],
		}],
	}
	scatter.restore_generated_state(generated_state)
	var restored_state: Dictionary = scatter.capture_generated_state()
	var restored_groups: Array = restored_state.get("groups", []) as Array
	_expect(restored_groups.size() == 1, "scatter restores one generated MultiMesh group")
	var restored_transforms: Array = (restored_groups[0] as Dictionary).get("transforms", []) as Array
	_expect(restored_transforms.size() == 2, "scatter restores instance transforms")
	_expect(is_equal_approx((restored_transforms[1] as Transform3D).origin.x, 10.0), "scatter preserves restored transform positions")
	var erase_result: Dictionary = scatter.erase_at(Vector3.ZERO, 1.0)
	_expect(int(erase_result.get("removed", 0)) == 1, "scatter erase brush removes nearby instance")
	var erased_groups: Array = (scatter.capture_generated_state().get("groups", []) as Array)
	_expect(erased_groups.size() == 1, "scatter erase preserves nonempty groups")
	if not erased_groups.is_empty():
		_expect((erased_groups[0] as Dictionary).get("transforms", []).size() == 1, "scatter erase preserves distant instance")
	remove_child(scatter)
	scatter.free()


func _test_terrain_shader() -> void:
	var shader: Resource = ResourceLoader.load(
		"res://addons/odyssey_world_tools/shaders/lanka_terrain_triplanar.gdshader",
		"Shader"
	)
	_expect(shader is Shader, "triplanar terrain shader loads")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("ASSERTION FAILED: %s" % message)
