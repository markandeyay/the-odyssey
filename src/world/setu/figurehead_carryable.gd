class_name FigureheadCarryable
extends RigidBody3D
## The Figurehead as a physical burden (M14 rework). Not a pickup: taking
## it is not the end — carrying it home is. It rides the M4 carry system
## (blocks climbing and the glider, slows Nau), so the walk out of The
## Dark and across the island is the last beat of the build. Setu accepts
## it: mounting at the boat emits `component_acquired(&"figurehead")` and
## the ending plays there, in the Shallows. Once acquired it removes
## itself on ready, so a loaded save never shows a duplicate.


func _ready() -> void:
	if GameState.components_acquired.has(&"figurehead"):
		queue_free()
