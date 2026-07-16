class_name ItemStack
extends RefCounted
## A runtime stack of one item id (M5). Definitions live in ItemDef
## resources; this is just id + count with save round-trip helpers.

var id: StringName = &""
var count: int = 0


func _init(item_id: StringName = &"", item_count: int = 0) -> void:
	id = item_id
	count = item_count


func to_dict() -> Dictionary:
	return {"id": String(id), "count": count}


static func from_dict(data: Dictionary) -> ItemStack:
	return ItemStack.new(StringName(str(data.get("id", ""))), int(data.get("count", 0)))
