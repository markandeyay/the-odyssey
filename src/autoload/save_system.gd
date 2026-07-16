extends Node
## Single-slot autosave (ARCHITECTURE §7). No manual save slots.
## M1 skeleton: the full payload (hearts, inventory, position, counters)
## lands in M6. The element unlock table is reserved from day one.

const SAVE_PATH: String = "user://autosave.json"
const SAVE_VERSION: int = 1


func _ready() -> void:
	EventBus.autosave_requested.connect(_on_autosave_requested)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(reason: StringName = &"unspecified") -> void:
	var data: Dictionary = _collect_save_data(reason)
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot open %s for writing (%s)" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: cannot open %s for reading (%s)" % [SAVE_PATH, error_string(FileAccess.get_open_error())])
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		push_error("SaveSystem: %s is corrupt" % SAVE_PATH)
		return false
	_apply_save_data(parsed as Dictionary)
	return true


func _collect_save_data(reason: StringName) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"reason": String(reason),
		"district": String(GameState.current_district),
		"flags": GameState.flags.duplicate(),
		"elements": ElementSystem.get_save_data(),
	}


func _apply_save_data(data: Dictionary) -> void:
	GameState.current_district = StringName(str(data.get("district", "")))
	GameState.flags = data.get("flags", {})
	ElementSystem.apply_save_data(data.get("elements", {}))


func _on_autosave_requested(reason: StringName) -> void:
	save_game(reason)
