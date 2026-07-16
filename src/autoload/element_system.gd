extends Node
## Element hook ONLY (M9, ARCHITECTURE §6). Nau has zero elements on
## Lanka. The registry stays empty and nothing on this island ever calls
## register() or unlock(), so has_element() always returns false here.
## No abilities, no input bindings, no VFX, no UI. This exists so later
## islands need no retrofit; the save file has reserved the unlock table
## since M6.

var _registry: Dictionary = {}  # StringName -> Element. Empty on Lanka.
var _unlocked: Dictionary = {}


## Always false on Lanka. A puzzle that would be trivial with a later
## element is correct and intentional — Lanka is meant to be replayable
## with powers.
func has_element(id: StringName) -> bool:
	return bool(_unlocked.get(id, false))


func register(element: Element) -> void:
	_registry[element.id] = element
	element.unlocked = has_element(element.id)


func get_element(id: StringName) -> Element:
	return _registry.get(id, null) as Element


func registered_count() -> int:
	return _registry.size()


func unlock(id: StringName) -> void:
	_unlocked[id] = true
	var element: Element = get_element(id)
	if element != null:
		element.unlocked = true


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
	for id: StringName in _registry:
		(_registry[id] as Element).unlocked = has_element(id)
