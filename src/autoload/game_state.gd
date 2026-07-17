extends Node
## Run state and progression (ARCHITECTURE §19): current district, flags,
## and the records the save file needs (M6) — fragments, Cairns, Setu
## components, trials, visited districts. Also the autosave trigger hub:
## trial completion, Cairn completion, and first entry to a district fire
## `autosave_requested` (M6). Campfires request their own on use (M10).
## Every Cairn yields exactly one heart piece (ARCHITECTURE §13); that
## grant lives here so WORLD's cairn scenes only emit `cairn_completed`.
## M14: also Setu's salvage stores — stowed at the boat, spent on nothing
## (§9), persisted here so the Setu scene stays stateless.

var current_district: StringName = &""
var flags: Dictionary = {}
var fragments_found: Array[StringName] = []
var cairns_completed: Array[StringName] = []
var components_acquired: Array[StringName] = []
var trials_completed: Array[StringName] = []
var visited_districts: Array[StringName] = []
var setu_salvage: Dictionary = {}


func _ready() -> void:
	EventBus.district_entered.connect(_on_district_entered)
	EventBus.trial_completed.connect(_on_trial_completed)
	EventBus.cairn_completed.connect(_on_cairn_completed)
	EventBus.fragment_found.connect(_on_fragment_found)
	EventBus.component_acquired.connect(_on_component_acquired)


func set_flag(flag: StringName, value: bool = true) -> void:
	flags[flag] = value


func get_flag(flag: StringName) -> bool:
	return bool(flags.get(flag, false))


func fragment_count() -> int:
	return fragments_found.size()


func add_setu_salvage(salvage_id: StringName, count: int) -> void:
	if count <= 0:
		return
	setu_salvage[salvage_id] = setu_salvage_count(salvage_id) + count


func setu_salvage_count(salvage_id: StringName) -> int:
	return int(setu_salvage.get(salvage_id, 0))


func reset() -> void:
	current_district = &""
	flags = {}
	fragments_found = []
	cairns_completed = []
	components_acquired = []
	trials_completed = []
	visited_districts = []
	setu_salvage = {}


func get_save_data() -> Dictionary:
	return {
		"district": String(current_district),
		"flags": flags.duplicate(),
		"fragments": _to_strings(fragments_found),
		"cairns": _to_strings(cairns_completed),
		"components": _to_strings(components_acquired),
		"trials": _to_strings(trials_completed),
		"visited": _to_strings(visited_districts),
		"setu_salvage": _salvage_to_save(),
	}


func apply_save_data(data: Dictionary) -> void:
	reset()
	current_district = StringName(str(data.get("district", "")))
	flags = data.get("flags", {})
	_from_strings(fragments_found, data.get("fragments", []))
	_from_strings(cairns_completed, data.get("cairns", []))
	_from_strings(components_acquired, data.get("components", []))
	_from_strings(trials_completed, data.get("trials", []))
	_from_strings(visited_districts, data.get("visited", []))
	var salvage: Variant = data.get("setu_salvage", {})
	if salvage is Dictionary:
		for key: Variant in (salvage as Dictionary):
			add_setu_salvage(StringName(str(key)), int((salvage as Dictionary)[key]))


func _on_district_entered(district_id: StringName) -> void:
	current_district = district_id
	if district_id != &"" and not visited_districts.has(district_id):
		visited_districts.append(district_id)
		EventBus.autosave_requested.emit(&"district_first_entry")


func _on_trial_completed(trial_id: StringName) -> void:
	if trials_completed.has(trial_id):
		return
	trials_completed.append(trial_id)
	EventBus.autosave_requested.emit(&"trial_completed")


func _on_cairn_completed(cairn_id: StringName) -> void:
	if cairns_completed.has(cairn_id):
		return
	cairns_completed.append(cairn_id)
	_grant_heart_piece()
	EventBus.autosave_requested.emit(&"cairn_completed")


func _on_fragment_found(fragment_id: StringName) -> void:
	if not fragments_found.has(fragment_id):
		fragments_found.append(fragment_id)


## Components are also unique key items (§8): whatever path emitted the
## signal, the reserved key item area stays in sync.
func _on_component_acquired(component_id: StringName) -> void:
	if not components_acquired.has(component_id):
		components_acquired.append(component_id)
	Inventory.add_key_item(component_id)


func _grant_heart_piece() -> void:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.health.add_heart_piece()


func _salvage_to_save() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in setu_salvage:
		out[String(id)] = int(setu_salvage[id])
	return out


static func _to_strings(ids: Array[StringName]) -> Array:
	var out: Array = []
	for id: StringName in ids:
		out.append(String(id))
	return out


static func _from_strings(into: Array[StringName], entries: Variant) -> void:
	if not entries is Array:
		return
	for entry: Variant in entries:
		var id: StringName = StringName(str(entry))
		if not into.has(id):
			into.append(id)
