class_name FragmentReader
extends PanelContainer
## The fragment reader for the crew memories (M12, ARCHITECTURE §12).
## Opens whenever `fragment_found` fires — first find or a re-read at the
## remains — and shows the name, the memento, and what happened. The game
## does not pause; the reader joins the modal_ui group so the camera holds
## still, and the interact key puts the memory down. There is no journal,
## no list, no completion counter on screen: re-reading means returning to
## where he died.

const MODAL_GROUP: StringName = &"modal_ui"

var _name_label: Label = null
var _memento_label: Label = null
var _lines_label: Label = null
var _opened_frame: int = -1


func _ready() -> void:
	visible = false
	add_theme_stylebox_override("panel", UIPalette.panel_style())
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	_name_label = _make_label(19, UIPalette.BONE_WHITE)
	_memento_label = _make_label(13, Color(UIPalette.ASH_GREY, 0.9))
	_lines_label = _make_label(15, Color(UIPalette.BONE_WHITE, 0.92))
	_lines_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lines_label.custom_minimum_size = Vector2(480, 0)
	var hint: Label = _make_label(11, Color(UIPalette.ASH_GREY, 0.7))
	hint.text = "%s  put it down" % InteractPromptLabel.interact_key_name()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_name_label)
	root.add_child(_memento_label)
	root.add_child(_lines_label)
	root.add_child(hint)
	EventBus.fragment_found.connect(open_fragment)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# The interact press that opened the reader must not also close it.
	if Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open_fragment(fragment_id: StringName) -> void:
	var strings: Dictionary = display_strings(FragmentRegistry.get_def(fragment_id))
	_name_label.text = strings["name"]
	_memento_label.text = strings["memento"]
	_lines_label.text = strings["lines"]
	_memento_label.visible = strings["memento"] != ""
	_opened_frame = Engine.get_process_frames()
	visible = true
	if not is_in_group(MODAL_GROUP):
		add_to_group(MODAL_GROUP)


func close() -> void:
	visible = false
	if is_in_group(MODAL_GROUP):
		remove_from_group(MODAL_GROUP)


## What the reader shows for a def, or the waterlogged fallback when the
## content is not authored yet. Split out so it is testable headless.
static func display_strings(def: FragmentDef) -> Dictionary:
	if def == null:
		return {
			"name": "One of the crew",
			"memento": "",
			"lines": "The memory is waterlogged. Nothing resolves.",
		}
	return {
		"name": def.crew_name,
		"memento": def.memento,
		"lines": def.lines,
	}


static func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
