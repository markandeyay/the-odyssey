extends Node
## Global signal bus (ARCHITECTURE §19). The only cross-system coupling allowed.
## WORLD may connect to these signals. Nobody adds to them without a request
## in docs/INTERFACES.md and human approval.

signal district_entered(district_id: StringName)
signal trial_completed(trial_id: StringName)
signal component_acquired(component_id: StringName)
signal cairn_completed(cairn_id: StringName)
signal fragment_found(fragment_id: StringName)
signal autosave_requested(reason: StringName)
signal player_died()
signal fire_started(position: Vector3)
signal fire_extinguished(position: Vector3)
signal sound_emitted(position: Vector3, loudness: float)
