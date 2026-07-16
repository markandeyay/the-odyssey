extends Node
## Element hook ONLY (ARCHITECTURE §6). Nau has zero elements on Lanka.
## The registry stays empty and nothing on this island ever calls unlock(),
## so has_element() always returns false here. No abilities, no input
## bindings, no VFX, no UI. This exists so later islands need no retrofit.

var _unlocked: Dictionary = {}


func has_element(id: StringName) -> bool:
	return bool(_unlocked.get(id, false))


func unlock(id: StringName) -> void:
	_unlocked[id] = true


func get_unlocked() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in _unlocked:
		if _unlocked[id]:
			out.append(id)
	return out


func get_save_data() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in _unlocked:
		out[String(id)] = bool(_unlocked[id])
	return out


func apply_save_data(data: Dictionary) -> void:
	_unlocked = {}
	for key: Variant in data:
		_unlocked[StringName(str(key))] = bool(data[key])
