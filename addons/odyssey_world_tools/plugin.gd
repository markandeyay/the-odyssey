@tool
extends EditorPlugin

const ScatterScript: Script = preload("res://addons/odyssey_world_tools/scatter_3d.gd")
const TerrainScript: Script = preload("res://addons/odyssey_world_tools/terrain_3d.gd")
const DockScript: Script = preload("res://addons/odyssey_world_tools/world_tools_dock.gd")
const SceneBudgetChecker: Script = preload("res://src/tools/world_tooling/scene_budget_checker.gd")

var _dock: VBoxContainer
var _heightmap_dialog: EditorFileDialog
var _selected_node: Node
var _budget_checker: RefCounted
var _sculpting: bool = false
var _sculpt_before: PackedFloat32Array = PackedFloat32Array()
var _scatter_painting: bool = false
var _scatter_before: Dictionary = {}
var _last_scatter_paint_position: Vector3 = Vector3.INF


func _enter_tree() -> void:
	_budget_checker = SceneBudgetChecker.new() as RefCounted
	_dock = DockScript.new() as VBoxContainer
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _dock)
	_dock.set_command_icons(get_editor_interface().get_base_control())
	_dock.set_budget_profiles(_budget_checker.available_profiles())
	_dock.add_scatter_requested.connect(_add_scatter_node)
	_dock.rebuild_scatter_requested.connect(_rebuild_scatter)
	_dock.clear_scatter_requested.connect(_clear_scatter)
	_dock.add_terrain_requested.connect(_add_terrain_node)
	_dock.import_heightmap_requested.connect(_show_heightmap_dialog)
	_dock.rebuild_terrain_requested.connect(_rebuild_terrain)
	_dock.analyze_budget_requested.connect(_analyze_budget)

	_heightmap_dialog = EditorFileDialog.new()
	_heightmap_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_heightmap_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_heightmap_dialog.filters = PackedStringArray([
		"*.png ; PNG Heightmaps",
		"*.exr ; OpenEXR Heightmaps",
		"*.hdr ; HDR Heightmaps",
	])
	_heightmap_dialog.file_selected.connect(_import_heightmap)
	get_editor_interface().get_base_control().add_child(_heightmap_dialog)
	get_editor_interface().get_selection().selection_changed.connect(_selection_changed)
	_selection_changed()


func _exit_tree() -> void:
	var selection: EditorSelection = get_editor_interface().get_selection()
	if selection.selection_changed.is_connected(_selection_changed):
		selection.selection_changed.disconnect(_selection_changed)
	if _heightmap_dialog != null:
		_heightmap_dialog.queue_free()
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()


func _handles(object: Object) -> bool:
	return object is OdysseyTerrain3D or object is OdysseyScatter3D


func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if _selected_node is OdysseyScatter3D and _dock.scatter_paint_toggle.button_pressed:
		return _forward_scatter_paint(viewport_camera, event, _selected_node as OdysseyScatter3D)
	if not _selected_node is OdysseyTerrain3D or not _dock.sculpt_toggle.button_pressed:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var terrain: OdysseyTerrain3D = _selected_node as OdysseyTerrain3D
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if mouse_button.pressed:
			var hit_position: Variant = _terrain_hit(viewport_camera, mouse_button.position, terrain)
			if hit_position == null:
				return EditorPlugin.AFTER_GUI_INPUT_PASS
			_sculpt_before = terrain.height_data.duplicate()
			_sculpting = true
			_apply_sculpt(terrain, hit_position as Vector3)
		else:
			_commit_sculpt(terrain)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion and _sculpting:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
			_commit_sculpt(terrain)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		var hit_position: Variant = _terrain_hit(viewport_camera, mouse_motion.position, terrain)
		if hit_position != null:
			_apply_sculpt(terrain, hit_position as Vector3)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _selection_changed() -> void:
	var selected_nodes: Array[Node] = get_editor_interface().get_selection().get_selected_nodes()
	_selected_node = selected_nodes[0] if not selected_nodes.is_empty() else null
	_dock.set_selection(_selected_node)


func _add_scatter_node() -> void:
	_add_authored_node(ScatterScript.new() as Node, "Scatter3D")


func _add_terrain_node() -> void:
	var terrain: OdysseyTerrain3D = TerrainScript.new() as OdysseyTerrain3D
	_add_authored_node(terrain, "Terrain3D")
	terrain.rebuild()


func _add_authored_node(node: Node, node_name: String) -> void:
	var scene_root: Node = get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		_dock.show_status("Open a WORLD-owned scene first", true)
		node.free()
		return
	node.name = node_name
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Add %s" % node_name)
	undo_redo.add_do_method(scene_root, "add_child", node)
	undo_redo.add_do_property(node, "owner", scene_root)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(scene_root, "remove_child", node)
	undo_redo.commit_action()
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(node)


func _rebuild_scatter() -> void:
	if not _selected_node is OdysseyScatter3D:
		return
	var scatter: OdysseyScatter3D = _selected_node as OdysseyScatter3D
	var before: Dictionary = scatter.capture_generated_state()
	var result: Dictionary = scatter.rebuild()
	if bool(result.get("ok", false)):
		_commit_scatter_change(scatter, before, "Rebuild Scatter")
		_dock.show_status(
			"Scatter: %d / %d placed" % [int(result.get("placed", 0)), int(result.get("requested", 0))]
		)
	else:
		_dock.show_status(str(result.get("error", "Scatter rebuild failed")), true)


func _clear_scatter() -> void:
	if _selected_node is OdysseyScatter3D:
		var scatter: OdysseyScatter3D = _selected_node as OdysseyScatter3D
		var before: Dictionary = scatter.capture_generated_state()
		scatter.clear_generated()
		_commit_scatter_change(scatter, before, "Clear Scatter")
		_dock.show_status("Scatter output cleared")


func _show_heightmap_dialog() -> void:
	if _selected_node is OdysseyTerrain3D:
		_heightmap_dialog.popup_file_dialog()


func _import_heightmap(path: String) -> void:
	if not _selected_node is OdysseyTerrain3D:
		return
	var terrain: OdysseyTerrain3D = _selected_node as OdysseyTerrain3D
	var before: PackedFloat32Array = terrain.height_data.duplicate()
	var result: Dictionary = terrain.import_heightmap(path)
	if not bool(result.get("ok", false)):
		_dock.show_status(str(result.get("error", "Heightmap import failed")), true)
		return
	var after: PackedFloat32Array = terrain.height_data.duplicate()
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Import Terrain Heightmap")
	undo_redo.add_do_method(terrain, "replace_height_data", after)
	undo_redo.add_undo_method(terrain, "replace_height_data", before)
	undo_redo.commit_action(false)
	_dock.show_status("Imported heightmap: %s" % path.get_file())


func _rebuild_terrain() -> void:
	if not _selected_node is OdysseyTerrain3D:
		return
	var result: Dictionary = (_selected_node as OdysseyTerrain3D).rebuild()
	if bool(result.get("ok", false)):
		_dock.show_status(
			"Terrain: %d vertices, %d triangles"
			% [int(result.get("vertices", 0)), int(result.get("triangles", 0))]
		)
	else:
		_dock.show_status(str(result.get("error", "Terrain rebuild failed")), true)


func _analyze_budget() -> void:
	var scene_root: Node = get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		_dock.show_status("Open a scene before running its budget", true)
		return
	var profile: String = _dock.selected_budget_profile()
	var metrics: Dictionary = _budget_checker.analyze_root(scene_root)
	var budget: Dictionary = _budget_checker.budget_for_profile(profile)
	var issues: Array[String] = _budget_checker.validate_metrics(metrics, profile)
	_dock.show_budget(metrics, budget, issues)


func _terrain_hit(camera: Camera3D, screen_position: Vector2, terrain: OdysseyTerrain3D) -> Variant:
	if terrain.get_world_3d() == null:
		return null
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_end: Vector3 = ray_origin + camera.project_ray_normal(screen_position) * 10000.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1)
	var hit: Dictionary = terrain.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider: Object = hit.get("collider") as Object
	if not collider is Node or not terrain.is_ancestor_of(collider as Node):
		return null
	return terrain.to_local(hit.get("position", Vector3.ZERO) as Vector3)


func _forward_scatter_paint(
	camera: Camera3D,
	event: InputEvent,
	scatter: OdysseyScatter3D
) -> int:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if mouse_button.pressed:
			var hit_position: Variant = _scatter_hit(camera, mouse_button.position, scatter)
			if hit_position == null:
				return EditorPlugin.AFTER_GUI_INPUT_PASS
			_scatter_before = scatter.capture_generated_state()
			_scatter_painting = true
			_last_scatter_paint_position = Vector3.INF
			_apply_scatter_brush(scatter, hit_position as Vector3)
		else:
			_commit_scatter_stroke(scatter)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion and _scatter_painting:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
			_commit_scatter_stroke(scatter)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		var hit_position: Variant = _scatter_hit(camera, mouse_motion.position, scatter)
		if hit_position != null:
			var brush_position: Vector3 = hit_position as Vector3
			var spacing: float = float(_dock.scatter_brush_radius.value) * 0.5
			if _last_scatter_paint_position == Vector3.INF or _last_scatter_paint_position.distance_to(brush_position) >= spacing:
				_apply_scatter_brush(scatter, brush_position)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _scatter_hit(camera: Camera3D, screen_position: Vector2, scatter: OdysseyScatter3D) -> Variant:
	if scatter.get_world_3d() == null:
		return null
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_end: Vector3 = ray_origin + camera.project_ray_normal(screen_position) * 10000.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ray_origin, ray_end, scatter.surface_collision_mask
	)
	var hit: Dictionary = scatter.get_world_3d().direct_space_state.intersect_ray(query)
	return null if hit.is_empty() else hit.get("position", Vector3.ZERO)


func _apply_scatter_brush(scatter: OdysseyScatter3D, world_position: Vector3) -> void:
	_last_scatter_paint_position = world_position
	var result: Dictionary
	if _dock.selected_scatter_brush_mode() == "erase":
		result = scatter.erase_at(world_position, float(_dock.scatter_brush_radius.value))
		if bool(result.get("ok", false)):
			_dock.show_status("Scatter: %d removed" % int(result.get("removed", 0)))
	else:
		result = scatter.paint_at(world_position, float(_dock.scatter_brush_radius.value))
		if bool(result.get("ok", false)):
			_dock.show_status("Scatter: %d painted" % int(result.get("placed", 0)))
	if not bool(result.get("ok", false)):
		_dock.show_status(str(result.get("error", "Scatter paint failed")), true)


func _commit_scatter_stroke(scatter: OdysseyScatter3D) -> void:
	if not _scatter_painting:
		return
	_scatter_painting = false
	_commit_scatter_change(scatter, _scatter_before, "Paint Scatter")


func _commit_scatter_change(
	scatter: OdysseyScatter3D,
	before: Dictionary,
	action_name: String
) -> void:
	var after: Dictionary = scatter.capture_generated_state()
	if after == before:
		return
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(scatter, "restore_generated_state", after)
	undo_redo.add_undo_method(scatter, "restore_generated_state", before)
	undo_redo.commit_action(false)


func _apply_sculpt(terrain: OdysseyTerrain3D, local_position: Vector3) -> void:
	terrain.sculpt(
		local_position,
		float(_dock.brush_radius.value),
		float(_dock.brush_strength.value),
		_dock.selected_sculpt_mode()
	)


func _commit_sculpt(terrain: OdysseyTerrain3D) -> void:
	if not _sculpting:
		return
	_sculpting = false
	var after: PackedFloat32Array = terrain.height_data.duplicate()
	if after == _sculpt_before:
		return
	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	undo_redo.create_action("Sculpt Terrain")
	undo_redo.add_do_method(terrain, "replace_height_data", after)
	undo_redo.add_undo_method(terrain, "replace_height_data", _sculpt_before)
	undo_redo.commit_action(false)
