class_name Brand
extends RigidBody3D
## A brand (M7): Nau carries fire as a physical object, never as a power
## (ARCHITECTURE §2). Carryable through the M4 carry system, flammable
## through a mobile Flammable child that moves its cell with the body, so
## a lit brand ignites what it comes near via normal grid spread.
## Carrying fire is loud and visible — while lit it emits light and
## periodic `sound_emitted`, which is exactly what makes it a terrible
## idea in The Dark (M11). When its fuel runs out it chars: a dead torch.

## Loudness handed to `sound_emitted` while lit. The drowned hear it.
@export var loudness: float = 8.0
@export var sound_interval: float = 1.0

var _sound_accum: float = 0.0

@onready var flammable: Flammable = $Flammable
@onready var _flame: CPUParticles3D = $Flame
@onready var _light: OmniLight3D = $Light


func _ready() -> void:
	flammable.ignited.connect(_refresh_visuals)
	flammable.extinguished.connect(_refresh_visuals)
	flammable.charred.connect(_refresh_visuals)
	_refresh_visuals()


func _physics_process(delta: float) -> void:
	if not is_lit():
		return
	_sound_accum += delta
	if _sound_accum >= sound_interval:
		_sound_accum = 0.0
		EventBus.sound_emitted.emit(global_position, loudness)


func is_lit() -> bool:
	return flammable.is_burning()


## Lights the brand from an existing fire (campfire interaction, M10).
func light() -> bool:
	return flammable.ignite()


func _refresh_visuals() -> void:
	var lit: bool = is_lit()
	_flame.emitting = lit
	_flame.visible = lit
	_light.visible = lit
