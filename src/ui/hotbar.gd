class_name HotbarUI
extends VBoxContainer
## Always-visible 10-slot hotbar (M5, styled in M12). Number keys 1-0 and
## the scroll wheel select, Minecraft-style. The selected slot carries a
## bone-white border; the item's full name appears above the bar and fades
## — the permanent footprint stays small (ARCHITECTURE §2: diegetic
## wherever possible, quiet where not).

const SLOT_SIZE: float = 52.0
const NAME_FADE_DELAY: float = 1.4
const NAME_FADE_TIME: float = 0.5

var _slots: Array[PanelContainer] = []
var _name_labels: Array[Label] = []
var _count_labels: Array[Label] = []
var _readout: Label = null
var _readout_timer: float = 0.0

static var _style_normal: StyleBoxFlat = null
static var _style_selected: StyleBoxFlat = null


func _ready() -> void:
	if _style_normal == null:
		_style_normal = UIPalette.slot_style(false)
		_style_selected = UIPalette.slot_style(true)
	add_theme_constant_override("separation", 6)
	_readout = Label.new()
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.add_theme_font_size_override("font_size", 14)
	_readout.add_theme_color_override("font_color", UIPalette.BONE_WHITE)
	_readout.add_theme_color_override("font_outline_color", Color(UIPalette.WET_BLACK, 0.8))
	_readout.add_theme_constant_override("outline_size", 6)
	_readout.modulate.a = 0.0
	add_child(_readout)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for i: int in Inventory.HOTBAR_SIZE:
		row.add_child(_build_slot(i))
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


func _process(delta: float) -> void:
	if _readout_timer <= 0.0:
		return
	_readout_timer = maxf(0.0, _readout_timer - delta)
	_readout.modulate.a = clampf(_readout_timer / NAME_FADE_TIME, 0.0, 1.0)


func slot_count() -> int:
	return _slots.size()


func _build_slot(index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style_normal)
	var inner: Control = Control.new()
	inner.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.add_child(inner)
	var hint: Label = Label.new()
	hint.text = str((index + 1) % 10)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(UIPalette.ASH_GREY, 0.8))
	hint.position = Vector2(4, 1)
	inner.add_child(hint)
	var name_label: Label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(UIPalette.BONE_WHITE, 0.9))
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_child(name_label)
	var count_label: Label = Label.new()
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", UIPalette.BONE_WHITE)
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count_label.position = Vector2(SLOT_SIZE - 18, SLOT_SIZE - 18)
	inner.add_child(count_label)
	_slots.append(panel)
	_name_labels.append(name_label)
	_count_labels.append(count_label)
	return panel


func _on_selection_changed(_index: int) -> void:
	_refresh()
	_show_readout()


func _refresh() -> void:
	for i: int in _slots.size():
		var stack: ItemStack = Inventory.hotbar[i]
		if stack == null:
			_name_labels[i].text = ""
			_count_labels[i].text = ""
		else:
			_name_labels[i].text = _short_name(stack.id)
			_count_labels[i].text = str(stack.count) if stack.count > 1 else ""
		var selected: bool = i == Inventory.selected_hotbar_index
		_slots[i].add_theme_stylebox_override(
			"panel", _style_selected if selected else _style_normal
		)


## Flashes the selected item's full name above the bar, then fades.
func _show_readout() -> void:
	var stack: ItemStack = Inventory.selected_stack()
	if stack == null:
		_readout.modulate.a = 0.0
		_readout_timer = 0.0
		return
	var def: ItemDef = ItemRegistry.get_def(stack.id)
	_readout.text = def.display_name if def != null else String(stack.id)
	_readout.modulate.a = 1.0
	_readout_timer = NAME_FADE_DELAY + NAME_FADE_TIME


static func _short_name(id: StringName) -> String:
	var def: ItemDef = ItemRegistry.get_def(id)
	var display: String = def.display_name if def != null else String(id)
	return display.substr(0, 8)
