class_name GameHUD
extends Control
## The whole HUD (M12). Hearts are the only permanent element
## (ARCHITECTURE §2); everything else earns its place: the hotbar is the
## inventory pillar, the breath ring exists only underwater, the storage
## panel and fragment reader are toggled, the interact prompt appears when
## something is in reach. No minimap, no quest log, no compass — the Spine
## is the compass. Heat resistance is diegetic: ember wisps rise off Nau
## in the world, not on this layer.

@onready var hearts: HeartsDisplay = $Hearts
@onready var breath: BreathMeter = $BreathMeter
@onready var _prompt: InteractPromptLabel = $InteractPrompt


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## The player wires itself in on ready. The HUD never reaches into the
## scene tree to find him.
func bind(player: Player) -> void:
	hearts.bind(player.health)
	breath.bind(player)


func set_interact_prompt(prompt: String) -> void:
	_prompt.set_prompt(prompt)
