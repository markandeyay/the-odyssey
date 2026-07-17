class_name Setu
extends StaticBody3D
## The boat (M14, ARCHITECTURE §4/§9). A scene in the Shallows with five
## component slots and three salvage counters. Components mount visibly
## the moment they are acquired anywhere on the island — the boat
## assembles in front of the player over the course of Lanka. Salvage is
## stowed here and the counters display it; on Lanka it does nothing, and
## that is correct. No voyage, no crossing, no upgrades — the ending it
## triggers lives in EndingSequence, not here.

const COMPONENT_IDS: Array[StringName] = [
	&"hull", &"mast", &"sail", &"keel", &"figurehead",
]
const SALVAGE_IDS: Array[StringName] = [&"timber", &"iron", &"canvas"]

var _mounts: Dictionary = {}

@onready var _interactable: Interactable = $Interactable
@onready var _tally: Label3D = $SalvageTally


func _ready() -> void:
	for id: StringName in COMPONENT_IDS:
		_mounts[id] = get_node("Mounts/%s" % String(id).capitalize()) as Node3D
	_refresh_mounts()
	_refresh_salvage()
	EventBus.component_acquired.connect(_on_component_acquired)
	Inventory.changed.connect(_refresh_prompt)
	_interactable.interacted.connect(_on_interacted)
	_refresh_prompt()


## True when the player is holding any salvage the boat could stow.
static func has_salvage_to_stow() -> bool:
	for id: StringName in SALVAGE_IDS:
		if Inventory.count_of(id) > 0:
			return true
	return false


func is_mounted(component_id: StringName) -> bool:
	var mount: Node3D = _mounts.get(component_id, null)
	return mount != null and mount.visible


## Stowing moves every piece of salvage from the inventory into the
## boat's stores (§9: collected and stored on Setu). The stores persist
## through GameState and are spent on nothing here.
func _on_interacted(_player: Player) -> void:
	for id: StringName in SALVAGE_IDS:
		var moved: int = Inventory.remove_item(id, Inventory.count_of(id))
		GameState.add_setu_salvage(id, moved)
	_refresh_salvage()
	_refresh_prompt()


func _on_component_acquired(_component_id: StringName) -> void:
	_refresh_mounts()


## Mount visibility mirrors GameState, so a loaded save and a live
## acquisition render the same boat.
func _refresh_mounts() -> void:
	for id: StringName in COMPONENT_IDS:
		(_mounts[id] as Node3D).visible = GameState.components_acquired.has(id)


func _refresh_salvage() -> void:
	var lines: PackedStringArray = []
	for id: StringName in SALVAGE_IDS:
		lines.append("%s  %d" % [String(id), GameState.setu_salvage_count(id)])
	_tally.text = "\n".join(lines)


func _refresh_prompt() -> void:
	_interactable.prompt = "Stow salvage" if has_salvage_to_stow() else "Setu"
