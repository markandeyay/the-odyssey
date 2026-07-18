class_name KefferInteraction
extends StaticBody3D
## Keffer (M15): the living scavenger under the overturned hull in the
## Shallows. Not a merchant, not a quest giver — a handful of lines on a
## loop, a food handout on a cooldown, and he is quietly terrified of
## Nau and never explains why. He is Captain Toad; do not grow him a
## quest chain.
##
## HARD RULE: Keffer never says Nau's name. The Figurehead spends it
## once at the very end (M14) and nothing else on the island may. Any
## authored replacement for `dialogue_lines` must keep that.

## Placeholder prose; the human owns the final words. WORLD may replace
## per placement. Sequential, wrapping — one line per talk.
@export var dialogue_lines: Array[String] = [
	"You— no. No trouble. There's food in the pot, take it.",
	"There's shellfish when there's shellfish. Just... stay over there.",
	"The stones with the marks. They open if you listen. That's all I know.",
	"I was here before. I'll be here after. That's all I am.",
	"Don't look at me like that. Please.",
	"The old ones cut doors under the hills. I never went in. I wouldn't.",
	"Eat. It's yours. It was always going to be yours.",
	"I know what you are. I'm not saying it.",
]
@export var handout_item_id: StringName = &"tidepool_shellfish_cooked"
@export var handout_count: int = 1
@export var handout_cooldown_s: float = 120.0

var _next_line: int = 0
var _handout_ready_at_s: float = 0.0

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	_interactable.prompt = "Talk"
	_interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: Player) -> void:
	GameState.set_flag(&"met_keffer")
	var box: DialogueBox = get_tree().get_first_node_in_group(DialogueBox.GROUP) as DialogueBox
	if box != null:
		box.show_line("Keffer", next_line())
	_try_handout()


func next_line() -> String:
	if dialogue_lines.is_empty():
		return ""
	var line: String = dialogue_lines[_next_line]
	_next_line = (_next_line + 1) % dialogue_lines.size()
	return line


func _try_handout() -> void:
	if handout_item_id == &"" or handout_count <= 0:
		return
	var now_s: float = Time.get_ticks_msec() / 1000.0
	if now_s < _handout_ready_at_s:
		return
	var leftover: int = Inventory.add_item(handout_item_id, handout_count)
	if leftover < handout_count:
		# Full hands don't burn the kindness; he offers again next talk.
		_handout_ready_at_s = now_s + handout_cooldown_s
