class_name FragmentDef
extends Resource
## One drowned-crew memory fragment (M12, ARCHITECTURE §12): a name, an
## object, one or two lines of what happened. Pure story — no stats, no
## gates. SYSTEMS defines the format; WORLD authors the 20 .tres files
## under assets/fragments/ and places the pickups.

@export var id: StringName = &""
## The crewman's name, e.g. "Adaro, the helmsman".
@export var crew_name: String = ""
## The object that remains of him, e.g. "a tin whistle, bent flat".
@export var memento: String = ""
## One or two lines of what happened. Keep it short; grief reads better
## unfinished.
@export_multiline var lines: String = ""
