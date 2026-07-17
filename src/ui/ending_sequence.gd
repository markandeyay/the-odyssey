class_name EndingSequence
extends Control
## The stub ending (M14, ARCHITECTURE §0/§4). When the fifth component is
## acquired — always the Figurehead, since The Dark requires the Spine
## requires the rest — it mounts, it speaks exactly once with Vela's
## voice, and the screen goes to TO BE CONTINUED. That is the entire
## ending of the current build. No voyage, no crossing, no next island.
##
## The trigger is still `component_acquired`, but the Figurehead's is
## emitted only by Setu when the carried Figurehead is mounted (M14
## rework) — so the ending always plays at the boat in the Shallows.
## Lives on the HUD layer anyway; it costs nothing and survives whatever
## is streamed in or out around the beach. The voice audio is WORLD's,
## loaded from a conventional path if it exists; until then the line is
## a subtitle alone. The line text is a placeholder for
## the human to author.

const ENDING_FLAG: StringName = &"setu_ending_played"
const VOICE_STREAM_PATH: String = "res://assets/audio/vela/figurehead_line.ogg"
const MODAL_GROUP: StringName = &"modal_ui"

## Silence between the Figurehead mounting and Vela's voice.
@export var beat_delay: float = 2.5
## How long her line hangs before the world fades.
@export var line_hold: float = 5.0
@export var fade_duration: float = 4.0
## The only thing she says on Lanka. PLACEHOLDER — the human owns it.
@export var vela_line: String = "Come home."
## The final card freezes the tree. Tests turn this off.
@export var pause_on_card: bool = true

## How many times the ending has run. It must never pass 1.
var times_played: int = 0
var playing: bool = false

var _subtitle: Label = null
var _fade: ColorRect = null
var _card: Label = null
var _voice: AudioStreamPlayer = null


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	EventBus.component_acquired.connect(_on_component_acquired)


func _on_component_acquired(_component_id: StringName) -> void:
	if playing or GameState.get_flag(ENDING_FLAG):
		return
	for id: StringName in Setu.COMPONENT_IDS:
		if not GameState.components_acquired.has(id):
			return
	_play()


func _play() -> void:
	playing = true
	times_played += 1
	# Set immediately: the trial-completion autosave that follows the
	# Figurehead must record that she has already spoken.
	GameState.set_flag(ENDING_FLAG)
	add_to_group(MODAL_GROUP)
	_run_sequence()


func _run_sequence() -> void:
	await get_tree().create_timer(beat_delay).timeout
	_subtitle.text = "“%s”" % vela_line
	_subtitle.visible = true
	if ResourceLoader.exists(VOICE_STREAM_PATH):
		_voice.stream = load(VOICE_STREAM_PATH) as AudioStream
		_voice.play()
	await get_tree().create_timer(line_hold).timeout
	_fade.modulate.a = 0.0
	_fade.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "modulate:a", 1.0, fade_duration)
	await tween.finished
	_subtitle.visible = false
	_card.visible = true
	if pause_on_card:
		get_tree().paused = true


func _build_ui() -> void:
	_fade = ColorRect.new()
	_fade.color = UIPalette.WET_BLACK
	_fade.set_anchors_preset(PRESET_FULL_RECT)
	_fade.mouse_filter = MOUSE_FILTER_IGNORE
	_fade.visible = false
	add_child(_fade)

	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 24)
	_subtitle.add_theme_color_override("font_color", UIPalette.BONE_WHITE)
	_subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_subtitle.add_theme_constant_override("outline_size", 8)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_subtitle.offset_top = -120.0
	_subtitle.offset_left = -400.0
	_subtitle.offset_right = 400.0
	_subtitle.visible = false
	add_child(_subtitle)

	_card = Label.new()
	_card.text = "TO  BE  CONTINUED."
	_card.add_theme_font_size_override("font_size", 34)
	_card.add_theme_color_override("font_color", UIPalette.BONE_WHITE)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.set_anchors_preset(PRESET_FULL_RECT)
	_card.visible = false
	add_child(_card)

	_voice = AudioStreamPlayer.new()
	add_child(_voice)
