class_name HotbarUI
extends HBoxContainer
## Always-visible 10-slot hotbar (M5). Number keys 1-0 and the scroll
## wheel select, Minecraft-style. M12 gives this real art; behavior final.

var _slots: Array[PanelContainer] = []


func _ready() -> void:
	for i: int in Inventory.HOTBAR_SIZE:
		var panel: PanelContainer = PanelContainer.new()
		panel.custom_minimum_size = Vector2(56, 56)
		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		panel.add_child(label)
		add_child(panel)
		_slots.append(panel)
	Inventory.changed.connect(_refresh)
	Inventory.selection_changed.connect(_on_selection_changed)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	for i: int in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			Inventory.select_hotbar(i)
			return
	if event.is_action_pressed(&"hotbar_next"):
		Inventory.select_next()
	elif event.is_action_pressed(&"hotbar_prev"):
		Inventory.select_prev()


func _on_selection_changed(_index: int) -> void:
	_refresh()


func _refresh() -> void:
	for i: int in _slots.size():
		var label: Label = _slots[i].get_child(0) as Label
		var stack: ItemStack = Inventory.hotbar[i]
		if stack == null:
			label.text = ""
		else:
			label.text = "%s\n%d" % [_short_name(stack.id), stack.count]
		var selected: bool = i == Inventory.selected_hotbar_index
		_slots[i].modulate = Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.5)


static func _short_name(id: StringName) -> String:
	var def: ItemDef = ItemRegistry.get_def(id)
	var display: String = def.display_name if def != null else String(id)
	return display.substr(0, 8)
