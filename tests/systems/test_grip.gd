extends GutTest
## M3 grip derivation (ARCHITECTURE §19): grip class comes from the material
## name, never from a per-node property. Fire overrides via scene groups.


func test_grip_class_from_material_name_table() -> void:
	var cases: Dictionary = {
		"mat_stone_grip_solid": Grip.Class.SOLID,
		"mat_unburnt_timber_grip_solid": Grip.Class.SOLID,
		"mat_rope_grip_solid": Grip.Class.SOLID,
		"mat_root_grip_solid": Grip.Class.SOLID,
		"mat_charred_timber_grip_crumbling": Grip.Class.CRUMBLING,
		"mat_fire_cracked_stone_grip_crumbling": Grip.Class.CRUMBLING,
		"mat_soot_grip_slick": Grip.Class.SLICK,
		"mat_wet_stone_grip_slick": Grip.Class.SLICK,
		"mat_algae_grip_slick": Grip.Class.SLICK,
		"mat_burning_beam_grip_hot": Grip.Class.HOT,
		"MAT_SHOUTING_GRIP_HOT": Grip.Class.HOT,
	}
	for material_name: String in cases:
		assert_eq(
			Grip.class_from_material_name(material_name), cases[material_name],
			"derivation of %s" % material_name
		)


func test_nonconforming_names_default_to_solid() -> void:
	for material_name: String in ["", "mat_mystery", "stone", "grip_hot", "mat_thing_grip_wet"]:
		assert_eq(
			Grip.class_from_material_name(material_name), Grip.Class.SOLID,
			"'%s' should default to SOLID" % material_name
		)


func _body_with_material(material_name: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = material_name
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	add_child_autofree(body)
	return body


func test_class_from_collision_reads_mesh_material() -> void:
	var body: StaticBody3D = _body_with_material("mat_a_grip_hot")
	assert_eq(Grip.class_from_collision(body), Grip.Class.HOT)


func test_burning_group_overrides_material_name() -> void:
	var body: StaticBody3D = _body_with_material("mat_stone_grip_solid")
	body.add_to_group(Grip.BURNING_GROUP)
	assert_eq(Grip.class_from_collision(body), Grip.Class.HOT, "burning overrides the material")


func test_charred_group_reports_crumbling() -> void:
	var body: StaticBody3D = _body_with_material("mat_stone_grip_solid")
	body.add_to_group(Grip.CHARRED_GROUP)
	assert_eq(Grip.class_from_collision(body), Grip.Class.CRUMBLING, "charred surfaces crumble")


func test_collider_under_mesh_instance_parent() -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = "mat_b_grip_slick"
	mesh_instance.material_override = material
	var body: StaticBody3D = StaticBody3D.new()
	mesh_instance.add_child(body)
	add_child_autofree(mesh_instance)
	assert_eq(Grip.class_from_collision(body), Grip.Class.SLICK)


func test_surface_override_material_is_read() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = "mat_c_grip_crumbling"
	mesh_instance.set_surface_override_material(0, material)
	body.add_child(mesh_instance)
	add_child_autofree(body)
	assert_eq(Grip.class_from_collision(body), Grip.Class.CRUMBLING)
