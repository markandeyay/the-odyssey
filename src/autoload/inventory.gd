extends Node
## 10-slot hotbar + 30-slot storage + reserved Setu key items (ARCHITECTURE §8).
## M4 groundwork: add/count/clear with stacking so pickups work. M5 brings
## item Resources, slot transfer, splitting, and the hotbar selection UX.
## Slots are null or a Dictionary {"id": StringName, "count": int} until
## M5's item definitions replace them.

signal changed()

const HOTBAR_SIZE: int = 10
const STORAGE_SIZE: int = 30
const STACK_MAX: int = 20

var hotbar: Array = []
var storage: Array = []
## Setu components live here, outside the 40 slots. They never stack.
var key_items: Array[StringName] = []
var selected_hotbar_index: int = 0


func _ready() -> void:
	hotbar.resize(HOTBAR_SIZE)
	storage.resize(STORAGE_SIZE)


## Adds `count` of `item_id`, topping up existing stacks first, then filling
## empty slots, hotbar before storage. Returns the leftover that did not fit.
func add_item(item_id: StringName, count: int = 1) -> int:
	var remaining: int = count
	for slots: Array in [hotbar, storage]:
		for i: int in slots.size():
			if remaining <= 0:
				break
			var slot: Variant = slots[i]
			if slot != null and slot["id"] == item_id and slot["count"] < STACK_MAX:
				var moved: int = mini(STACK_MAX - slot["count"], remaining)
				slot["count"] += moved
				remaining -= moved
	for slots: Array in [hotbar, storage]:
		for i: int in slots.size():
			if remaining <= 0:
				break
			if slots[i] == null:
				var moved: int = mini(STACK_MAX, remaining)
				slots[i] = {"id": item_id, "count": moved}
				remaining -= moved
	if remaining != count:
		changed.emit()
	return remaining


func count_of(item_id: StringName) -> int:
	var total: int = 0
	for slots: Array in [hotbar, storage]:
		for slot: Variant in slots:
			if slot != null and slot["id"] == item_id:
				total += slot["count"]
	return total


func clear() -> void:
	hotbar = []
	storage = []
	hotbar.resize(HOTBAR_SIZE)
	storage.resize(STORAGE_SIZE)
	key_items.clear()
	selected_hotbar_index = 0
	changed.emit()
