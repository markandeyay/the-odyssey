class_name PlayerAnimator
extends Node
## Thin animation driver for whatever mesh the character contract mounts
## (ARCHITECTURE §16). It addresses the mesh only through convention-named
## clips on its AnimationPlayer and plays nothing that does not exist, so the
## capsule fallback runs the exact same code path as a real rigged mesh.
## Expected clip names (any subset): idle, walk, run, sprint, jump, fall,
## land, crouch_idle, crouch_walk. Root motion is never used.

const BLEND_TIME: float = 0.2
const LAND_CLIP: StringName = &"land"

var _anim_player: AnimationPlayer = null
var _locomotion: StringName = &""


func bind_to(mesh_root: Node) -> void:
	var players: Array[Node] = mesh_root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("PlayerAnimator: mounted mesh has no AnimationPlayer")
		return
	_anim_player = players[0] as AnimationPlayer
	_anim_player.animation_finished.connect(_on_animation_finished)


func set_locomotion(state: StringName) -> void:
	if state == _locomotion:
		return
	_locomotion = state
	_play(state)


func play_landed() -> void:
	_play(LAND_CLIP)


func _play(clip: StringName) -> void:
	if _anim_player != null and _anim_player.has_animation(clip):
		_anim_player.play(clip, BLEND_TIME)


func _on_animation_finished(anim_name: StringName) -> void:
	# One-shots (land) hand control back to the current locomotion clip.
	if anim_name == LAND_CLIP:
		_play(_locomotion)
