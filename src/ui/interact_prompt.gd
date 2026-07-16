class_name InteractPromptLabel
extends Label
## Interact prompt (M4, styled in M12): "E  Carry", centered low on the
## screen, gone when there is nothing to do. The key hint is read from the
## InputMap so a rebind never lies.

var _key_hint: String = ""


func _ready() -> void:
	_key_hint = interact_key_name()
	add_theme_color_override("font_color", UIPalette.BONE_WHITE)


func set_prompt(prompt: String) -> void:
	if prompt == "":
		text = ""
		visible = false
		return
	text = "%s  %s" % [_key_hint, prompt]
	visible = true


## The FragmentReader borrows this for its "put it down" hint.
static func interact_key_name() -> String:
	for event: InputEvent in InputMap.action_get_events(&"interact"):
		var key: InputEventKey = event as InputEventKey
		if key == null:
			continue
		var keycode: Key = key.keycode
		if keycode == KEY_NONE:
			keycode = key.physical_keycode
			# Layout translation needs a real display server; headless
			# (tests, CI) falls back to the physical key's US label.
			if DisplayServer.get_name() != "headless":
				keycode = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
		return OS.get_keycode_string(keycode)
	return ""
