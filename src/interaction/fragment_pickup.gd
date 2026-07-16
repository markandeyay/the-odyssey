class_name FragmentPickup
extends StaticBody3D
## The remains of one of Nau's crew (M12, ARCHITECTURE §12). Interacting
## emits `fragment_found` — GameState records the first find (and only the
## first; duplicates are ignored) and the FragmentReader opens every time.
## The remains stay in the world: re-reading a memory means coming back to
## where he died, which is the whole journal.

@export var fragment_id: StringName = &""

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_interactable.prompt = "Remember"
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: Player) -> void:
	if fragment_id == &"":
		push_warning("FragmentPickup: no fragment_id set")
		return
	EventBus.fragment_found.emit(fragment_id)
