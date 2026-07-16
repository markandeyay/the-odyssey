class_name FoodDef
extends ItemDef
## Food behavior (M10, ARCHITECTURE §7). Extends ItemDef without touching
## it: heal on eat, optional heat resistance (the only non-heal effect on
## Lanka), what it cooks into, and the real-flame requirement. No recipes,
## no combining, no buff stacking: one ingredient, one fire, one result.

## Hearts restored when eaten.
@export var heal_hearts: float = 0.5
## Seconds of heat resistance granted when eaten. Only cooked charwood
## fruit sets this. Grants never stack — a fresh bite extends, not adds.
@export var grants_heat_resistance: float = 0.0
## The item this becomes on the fire. Empty means it does not cook
## (cooked results do not cook again — burnt is reached on the fire).
@export var cooked_id: StringName = &""
## Blind fish only cook on a real flame, not on embers (§7).
@export var requires_real_flame: bool = false
