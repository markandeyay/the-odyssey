class_name ItemDef
extends Resource
## Data-driven item definition (M5). One .tres per item under
## src/inventory/items/; the ItemRegistry serves them by id. Cooking (M10)
## extends food behavior without touching this class.

enum Category { FOOD, SALVAGE, KEY, MISC }

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: Category = Category.MISC
@export var stack_max: int = 20
@export_multiline var description: String = ""
