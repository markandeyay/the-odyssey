class_name DialogueBox
extends PanelContainer
## One spoken line at a time (M15). Dialogue on Lanka is people
## muttering at Nau, not trees: sequential, non-branching, no choices.
## Follows the FragmentReader's conventions — the reader itself stays
## coupled to FragmentDef and `fragment_found`, so speech gets its own
## small panel. Joins the modal_ui group while open so the camera holds
## still; the interact key puts the line away. Who speaks and what is
## said next is the caller's business.

const MODAL_GROUP: StringName = &"modal_ui"
const GROUP: StringName = &"dialogue_box"

var _speaker_label: Label = null
var _line_label: Label = null
var _opened_frame: int = -1


func _ready() -> void:
	visible = false
	add_to_group(GROUP)
	add_theme_stylebox_override("panel", UIPalette.panel_style())
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	_speaker_label = _make_label(13, Color(UIPalette.ASH_GREY, 0.9))
	_line_label = _make_label(15, Color(UIPalette.BONE_WHITE, 0.92))
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.custom_minimum_size = Vector2(480, 0)
	var hint: Label = _make_label(11, Color(UIPalette.ASH_GREY, 0.7))
	hint.text = "%s  step away" % InteractPromptLabel.interact_key_name()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_speaker_label)
	root.add_child(_line_label)
	root.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# The interact press that opened the box must not also close it.
	if Engine.get_process_frames() == _opened_frame:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func show_line(speaker: String, line: String) -> void:
	_speaker_label.text = speaker
	_speaker_label.visible = speaker != ""
	_line_label.text = line
	_opened_frame = Engine.get_process_frames()
	visible = true
	if not is_in_group(MODAL_GROUP):
		add_to_group(MODAL_GROUP)


func close() -> void:
	visible = false
	if is_in_group(MODAL_GROUP):
		remove_from_group(MODAL_GROUP)


static func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
