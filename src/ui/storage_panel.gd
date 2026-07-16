class_name StoragePanel
extends PanelContainer
## Toggled 30-slot storage plus the hotbar row (M5). Clicking a slot
## quick-transfers it to the other area. NOT a pause menu — the game keeps
## running (ARCHITECTURE §8). While open, the mouse is freed and the camera
## rig holds still via the modal_ui group.

const MODAL_GROUP: StringName = &"modal_ui"

var _storage_buttons: Array[Button] = []
var _hotbar_buttons: Array[Button] = []
var _key_label: Label = null


func _ready() -> void:
	add_theme_stylebox_override("panel", UIPalette.panel_style())
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	root.add_child(_header("Storage"))
	root.add_child(_build_grid(Inventory.STORAGE_SIZE, _storage_buttons, Inventory.Area.STORAGE))
	root.add_child(_header("Hotbar"))
	root.add_child(_build_grid(Inventory.HOTBAR_SIZE, _hotbar_buttons, Inventory.Area.HOTBAR))
	_key_label = Label.new()
	_key_label.add_theme_font_size_override("font_size", 12)
	_key_label.add_theme_color_override("font_color", Color(UIPalette.ASH_GREY, 0.95))
	root.add_child(_key_label)
	Inventory.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_storage"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	add_to_group(MODAL_GROUP)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	visible = false
	if is_in_group(MODAL_GROUP):
		remove_from_group(MODAL_GROUP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _header(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UIPalette.BONE_WHITE)
	return label


func _build_grid(count: int, into: Array[Button], area: Inventory.Area) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var normal: StyleBoxFlat = UIPalette.slot_style(false)
	var hover: StyleBoxFlat = UIPalette.slot_style(true)
	for i: int in count:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(56, 56)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_color_override("font_color", Color(UIPalette.BONE_WHITE, 0.9))
		button.pressed.connect(_on_slot_pressed.bind(area, i))
		grid.add_child(button)
		into.append(button)
	return grid


func _on_slot_pressed(area: Inventory.Area, index: int) -> void:
	Inventory.quick_transfer(area, index)


func _refresh() -> void:
	if _key_label == null:
		return
	for i: int in _storage_buttons.size():
		_set_button(_storage_buttons[i], Inventory.storage[i])
	for i: int in _hotbar_buttons.size():
		_set_button(_hotbar_buttons[i], Inventory.hotbar[i])
	if Inventory.key_items.is_empty():
		_key_label.text = ""
	else:
		var names: PackedStringArray = PackedStringArray()
		for id: StringName in Inventory.key_items:
			var def: ItemDef = ItemRegistry.get_def(id)
			names.append(def.display_name if def != null else String(id))
		_key_label.text = "Setu components: %s" % ", ".join(names)


static func _set_button(button: Button, stack: ItemStack) -> void:
	if stack == null:
		button.text = ""
		return
	var def: ItemDef = ItemRegistry.get_def(stack.id)
	var display: String = def.display_name if def != null else String(stack.id)
	button.text = "%s\n%d" % [display.substr(0, 8), stack.count]
