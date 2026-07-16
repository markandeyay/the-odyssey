extends Node
## Single-slot autosave (ARCHITECTURE §7). No manual save slots. M6: the
## full payload — progression from GameState, the reserved element unlock
## table (M9), the inventory, and the player's position and hearts — plus
## the death rule: death is a hard reset to the last autosave. Nothing
## lost, nothing dropped, no run-back penalty.

const SAVE_VERSION: int = 2

## A var, not a const, so tests can redirect to a scratch file.
var save_path: String = "user://autosave.json"


func _ready() -> void:
	EventBus.autosave_requested.connect(_on_autosave_requested)
	EventBus.player_died.connect(_on_player_died)


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(save_path)


func save_game(reason: StringName = &"unspecified") -> void:
	var data: Dictionary = _collect_save_data(reason)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot open %s for writing (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: cannot open %s for reading (%s)" % [save_path, error_string(FileAccess.get_open_error())])
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		push_error("SaveSystem: %s is corrupt" % save_path)
		return false
	var data: Dictionary = parsed as Dictionary
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("SaveSystem: save version %s != %d, loading best-effort" % [data.get("version", 0), SAVE_VERSION])
	_apply_save_data(data)
	return true


func _collect_save_data(reason: StringName) -> Dictionary:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"reason": String(reason),
		"game_state": GameState.get_save_data(),
		"elements": ElementSystem.get_save_data(),
		"inventory": Inventory.get_save_data(),
	}
	var player: Player = _find_player()
	if player != null:
		data["player"] = {
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"health": player.health.get_save_data(),
		}
	return data


func _apply_save_data(data: Dictionary) -> void:
	GameState.apply_save_data(data.get("game_state", {}))
	ElementSystem.apply_save_data(data.get("elements", {}))
	Inventory.apply_save_data(data.get("inventory", {}))
	var player: Player = _find_player()
	var player_data: Variant = data.get("player", {})
	if player == null or not player_data is Dictionary:
		return
	var position: Variant = (player_data as Dictionary).get("position", [])
	if position is Array and (position as Array).size() == 3:
		player.global_position = Vector3(float(position[0]), float(position[1]), float(position[2]))
		player.velocity = Vector3.ZERO
	player.health.apply_save_data((player_data as Dictionary).get("health", {}))


func _find_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _on_autosave_requested(reason: StringName) -> void:
	save_game(reason)


func _on_player_died() -> void:
	# Deferred so the killing frame's physics finishes before the reset.
	_respawn.call_deferred()


func _respawn() -> void:
	if load_game():
		return
	# Death before the first autosave trigger ever fired: nothing to load,
	# so just put Nau back on his feet where he stands.
	var player: Player = _find_player()
	if player != null:
		player.health.refill()
