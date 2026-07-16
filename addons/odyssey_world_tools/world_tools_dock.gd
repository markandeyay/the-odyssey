@tool
extends VBoxContainer

signal add_scatter_requested
signal rebuild_scatter_requested
signal clear_scatter_requested
signal add_terrain_requested
signal import_heightmap_requested
signal rebuild_terrain_requested
signal analyze_budget_requested

var selection_label: Label
var add_scatter_button: Button
var rebuild_scatter_button: Button
var clear_scatter_button: Button
var scatter_paint_toggle: CheckButton
var scatter_brush_mode: OptionButton
var scatter_brush_radius: SpinBox
var add_terrain_button: Button
var import_heightmap_button: Button
var rebuild_terrain_button: Button
var sculpt_toggle: CheckButton
var sculpt_mode: OptionButton
var brush_radius: SpinBox
var brush_strength: SpinBox
var budget_profile: OptionButton
var analyze_budget_button: Button
var budget_output: RichTextLabel


func _init() -> void:
	name = "Odyssey World"
	custom_minimum_size = Vector2(310.0, 420.0)
	_build_ui()


func set_command_icons(icon_source: Control) -> void:
	add_scatter_button.icon = icon_source.get_theme_icon(&"Add", &"EditorIcons")
	rebuild_scatter_button.icon = icon_source.get_theme_icon(&"Reload", &"EditorIcons")
	clear_scatter_button.icon = icon_source.get_theme_icon(&"Clear", &"EditorIcons")
	add_terrain_button.icon = icon_source.get_theme_icon(&"Add", &"EditorIcons")
	import_heightmap_button.icon = icon_source.get_theme_icon(&"Load", &"EditorIcons")
	rebuild_terrain_button.icon = icon_source.get_theme_icon(&"Reload", &"EditorIcons")
	analyze_budget_button.icon = icon_source.get_theme_icon(&"Search", &"EditorIcons")


func set_selection(node: Node) -> void:
	var is_scatter: bool = node is OdysseyScatter3D
	var is_terrain: bool = node is OdysseyTerrain3D
	selection_label.text = "Selected: %s" % node.name if node != null else "Selected: none"
	rebuild_scatter_button.disabled = not is_scatter
	clear_scatter_button.disabled = not is_scatter
	scatter_paint_toggle.disabled = not is_scatter
	if not is_scatter:
		scatter_paint_toggle.button_pressed = false
	import_heightmap_button.disabled = not is_terrain
	rebuild_terrain_button.disabled = not is_terrain
	sculpt_toggle.disabled = not is_terrain
	if not is_terrain:
		sculpt_toggle.button_pressed = false


func set_budget_profiles(profiles: PackedStringArray) -> void:
	budget_profile.clear()
	for profile: String in profiles:
		budget_profile.add_item(profile)
	var default_index: int = profiles.find("default")
	if default_index >= 0:
		budget_profile.select(default_index)


func selected_budget_profile() -> String:
	if budget_profile.item_count == 0:
		return "default"
	return budget_profile.get_item_text(budget_profile.selected)


func selected_sculpt_mode() -> String:
	return sculpt_mode.get_item_text(sculpt_mode.selected).to_lower()


func selected_scatter_brush_mode() -> String:
	return scatter_brush_mode.get_item_text(scatter_brush_mode.selected).to_lower()


func show_status(message: String, is_error: bool = false) -> void:
	selection_label.text = message
	selection_label.modulate = Color(1.0, 0.55, 0.45) if is_error else Color.WHITE


func show_budget(metrics: Dictionary, budget: Dictionary, issues: Array[String]) -> void:
	var passed: bool = issues.is_empty()
	var lines: PackedStringArray = PackedStringArray([
		"[b]%s: %s[/b]" % [str(budget.get("profile", "default")).capitalize(), "PASS" if passed else "OVER BUDGET"],
		"Draw calls: %d / %d" % [int(metrics.get("draw_calls", 0)), int(budget.get("max_draw_calls", 0))],
		"Triangles: %d / %d" % [int(metrics.get("triangles", 0)), int(budget.get("max_triangles", 0))],
		"Active lights: %d / %d" % [int(metrics.get("active_lights", 0)), int(budget.get("max_active_lights", 0))],
	])
	for issue: String in issues:
		lines.append("[color=#ff806e]%s[/color]" % issue)
	budget_output.text = "\n".join(lines)


func _build_ui() -> void:
	var title: Label = Label.new()
	title.text = "Odyssey World Tools"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)
	selection_label = Label.new()
	selection_label.text = "Selected: none"
	selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(selection_label)

	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	_build_scatter_tab(tabs)
	_build_terrain_tab(tabs)
	_build_budget_tab(tabs)


func _build_scatter_tab(tabs: TabContainer) -> void:
	var panel: VBoxContainer = VBoxContainer.new()
	panel.name = "Scatter"
	tabs.add_child(panel)
	add_scatter_button = _command_button("Add Scatter Node", add_scatter_requested)
	rebuild_scatter_button = _command_button("Rebuild Selected", rebuild_scatter_requested)
	clear_scatter_button = _command_button("Clear Generated", clear_scatter_requested)
	panel.add_child(add_scatter_button)
	panel.add_child(rebuild_scatter_button)
	panel.add_child(clear_scatter_button)
	rebuild_scatter_button.disabled = true
	clear_scatter_button.disabled = true
	scatter_paint_toggle = CheckButton.new()
	scatter_paint_toggle.text = "Paint in 3D View"
	scatter_paint_toggle.disabled = true
	panel.add_child(scatter_paint_toggle)
	scatter_brush_mode = OptionButton.new()
	scatter_brush_mode.add_item("Add")
	scatter_brush_mode.add_item("Erase")
	panel.add_child(_labeled_control("Mode", scatter_brush_mode))
	scatter_brush_radius = SpinBox.new()
	scatter_brush_radius.min_value = 0.5
	scatter_brush_radius.max_value = 100.0
	scatter_brush_radius.step = 0.5
	scatter_brush_radius.value = 8.0
	scatter_brush_radius.suffix = " m"
	panel.add_child(_labeled_control("Radius", scatter_brush_radius))


func _build_terrain_tab(tabs: TabContainer) -> void:
	var panel: VBoxContainer = VBoxContainer.new()
	panel.name = "Terrain"
	tabs.add_child(panel)
	add_terrain_button = _command_button("Add Terrain Node", add_terrain_requested)
	import_heightmap_button = _command_button("Import Heightmap", import_heightmap_requested)
	rebuild_terrain_button = _command_button("Rebuild Selected", rebuild_terrain_requested)
	panel.add_child(add_terrain_button)
	panel.add_child(import_heightmap_button)
	panel.add_child(rebuild_terrain_button)
	import_heightmap_button.disabled = true
	rebuild_terrain_button.disabled = true

	sculpt_toggle = CheckButton.new()
	sculpt_toggle.text = "Sculpt in 3D View"
	sculpt_toggle.disabled = true
	panel.add_child(sculpt_toggle)
	sculpt_mode = OptionButton.new()
	sculpt_mode.add_item("Raise")
	sculpt_mode.add_item("Lower")
	sculpt_mode.add_item("Smooth")
	panel.add_child(_labeled_control("Mode", sculpt_mode))
	brush_radius = SpinBox.new()
	brush_radius.min_value = 0.5
	brush_radius.max_value = 100.0
	brush_radius.step = 0.5
	brush_radius.value = 8.0
	brush_radius.suffix = " m"
	panel.add_child(_labeled_control("Radius", brush_radius))
	brush_strength = SpinBox.new()
	brush_strength.min_value = 0.01
	brush_strength.max_value = 10.0
	brush_strength.step = 0.05
	brush_strength.value = 0.5
	brush_strength.suffix = " m"
	panel.add_child(_labeled_control("Strength", brush_strength))


func _build_budget_tab(tabs: TabContainer) -> void:
	var panel: VBoxContainer = VBoxContainer.new()
	panel.name = "Budgets"
	tabs.add_child(panel)
	budget_profile = OptionButton.new()
	panel.add_child(_labeled_control("Profile", budget_profile))
	analyze_budget_button = _command_button("Analyze Edited Scene", analyze_budget_requested)
	panel.add_child(analyze_budget_button)
	budget_output = RichTextLabel.new()
	budget_output.bbcode_enabled = true
	budget_output.fit_content = true
	budget_output.scroll_active = false
	budget_output.custom_minimum_size = Vector2(0.0, 150.0)
	panel.add_child(budget_output)


func _command_button(label: String, requested_signal: Signal) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(func() -> void: requested_signal.emit())
	return button


func _labeled_control(label_text: String, control: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 74.0
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	return row
