class_name InteractPromptLabel
extends Label
## Minimal interact prompt readout (M4). M12 builds the real HUD; this
## exists so interaction is visible and testable before then.


func set_prompt(prompt: String) -> void:
	text = prompt
	visible = prompt != ""
