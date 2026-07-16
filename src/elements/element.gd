class_name Element
extends Resource
## An element definition (M9, ARCHITECTURE §6). Hook ONLY. Nau bends
## nothing on Lanka; no Element resource is authored, registered, or
## unlocked in this entire build. This class exists so that four islands
## from now nobody retrofits an architecture: one element per island
## after Lanka, each later gaining a sub-element (metal from earth,
## lightning from fire, ice from water, flight from air).
##
## No abilities. No input bindings. No VFX. No UI. Those are content for
## islands that do not have design documents yet.

@export var id: StringName = &""
@export var display_name: String = ""
@export var sub_elements: Array[StringName] = []
@export var unlocked: bool = false
