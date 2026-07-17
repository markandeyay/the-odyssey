extends SceneTree

const LOOK_PATH: String = "res://scenes/levels/lanka/look/lanka_look.tscn"
const OCEAN_SHADER: Shader = preload("res://addons/odyssey_world_tools/shaders/lanka_ocean_scenery.gdshader")


func _initialize() -> void:
	var look_error: Error = _build_persistent_look()
	if look_error != OK:
		_fail("Unable to build Lanka persistent look: %s" % error_string(look_error))
		return
	print("Wrote Lanka M7 persistent look")
	quit(0)


func _build_persistent_look() -> Error:
	var root_node: Node3D = Node3D.new()
	root_node.name = "LankaLook"
	root_node.set_meta(&"m7_visual_system", true)
	root_node.set_meta(&"budget_profile", "default")
	root_node.set_meta(&"palette", PackedStringArray(["ash_grey", "wet_black", "bone_white", "ember_orange", "sea_green"]))

	var environment_node: WorldEnvironment = WorldEnvironment.new()
	environment_node.name = "SmokeEnvironment"
	environment_node.environment = _make_environment()
	root_node.add_child(environment_node)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "LowSmokeSun"
	sun.rotation_degrees = Vector3(-12.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.90, 0.78)
	sun.light_energy = 1.48
	sun.light_volumetric_fog_energy = 1.55
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 460.0
	sun.directional_shadow_fade_start = 0.68
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	root_node.add_child(sun)

	var ocean: MeshInstance3D = MeshInstance3D.new()
	ocean.name = "PatientOceanScenery"
	ocean.position.y = -2.5
	ocean.set_meta(&"scenery_only", true)
	ocean.set_meta(&"simulation", false)
	var ocean_mesh: PlaneMesh = PlaneMesh.new()
	ocean_mesh.size = Vector2(2800.0, 2800.0)
	ocean_mesh.subdivide_width = 96
	ocean_mesh.subdivide_depth = 96
	var ocean_material: ShaderMaterial = ShaderMaterial.new()
	ocean_material.resource_name = "mat_lanka_ocean_scenery_grip_slick"
	ocean_material.shader = OCEAN_SHADER
	ocean_mesh.material = ocean_material
	ocean.mesh = ocean_mesh
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean.extra_cull_margin = 18.0
	root_node.add_child(ocean)

	var notifier: VisibleOnScreenNotifier3D = VisibleOnScreenNotifier3D.new()
	notifier.name = "OceanVisibilityNotifier"
	notifier.aabb = AABB(Vector3(-1400.0, -6.0, -1400.0), Vector3(2800.0, 14.0, 2800.0))
	ocean.add_child(notifier)
	return _save_scene(root_node, LOOK_PATH)


func _make_environment() -> Environment:
	var environment: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.038, 0.068, 0.066)
	sky_material.sky_horizon_color = Color(0.30, 0.34, 0.31)
	sky_material.ground_bottom_color = Color(0.018, 0.026, 0.025)
	sky_material.ground_horizon_color = Color(0.15, 0.19, 0.17)
	sky_material.sky_curve = 0.22
	sky_material.ground_curve = 0.18
	sky_material.sun_angle_max = 7.0
	sky_material.sun_curve = 0.08
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_energy_multiplier = 0.48
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.34, 0.43, 0.40)
	environment.ambient_light_energy = 0.46
	environment.ambient_light_sky_contribution = 0.58
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.34, 0.39, 0.36)
	environment.fog_light_energy = 0.26
	environment.fog_density = 0.0009
	environment.fog_sky_affect = 0.72
	environment.fog_height = 28.0
	environment.fog_height_density = 0.004
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0034
	environment.volumetric_fog_albedo = Color(0.32, 0.39, 0.36)
	environment.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	environment.volumetric_fog_emission_energy = 0.0
	environment.volumetric_fog_length = 760.0
	environment.volumetric_fog_detail_spread = 1.35
	environment.volumetric_fog_ambient_inject = 0.28
	environment.volumetric_fog_sky_affect = 0.48
	environment.glow_enabled = true
	environment.glow_intensity = 0.66
	environment.glow_bloom = 0.08
	return environment


func _save_scene(scene_root: Node3D, path: String) -> Error:
	_set_owner_recursive(scene_root, scene_root)
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(scene_root)
	if pack_error != OK:
		scene_root.free()
		return pack_error
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var save_error: Error = ResourceSaver.save(packed, path)
	scene_root.free()
	return save_error


func _set_owner_recursive(node: Node, scene_owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_owner
		_set_owner_recursive(child, scene_owner)


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
