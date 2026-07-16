extends Node
## Run state: current district and progression flags (ARCHITECTURE §19).

var current_district: StringName = &""
var flags: Dictionary = {}


func _ready() -> void:
	EventBus.district_entered.connect(_on_district_entered)


func set_flag(flag: StringName, value: bool = true) -> void:
	flags[flag] = value


func get_flag(flag: StringName) -> bool:
	return bool(flags.get(flag, false))


func _on_district_entered(district_id: StringName) -> void:
	current_district = district_id
