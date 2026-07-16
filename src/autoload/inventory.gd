extends Node
## 10-slot hotbar + 30-slot storage + reserved Setu key items
## (ARCHITECTURE §8). M5: data-driven ItemDefs, ItemStack slots, stacking,
## splitting, transfer, quick transfer, hotbar selection, and save
## round-trip data. Key items (Setu components) live outside the 40 slots
## and never stack.

signal changed()
signal selection_changed(index: int)

enum Area { HOTBAR, STORAGE }

const HOTBAR_SIZE: int = 10
const STORAGE_SIZE: int = 30
const STACK_MAX: int = 20  # default cap for items without a definition

var hotbar: Array[ItemStack] = []
var storage: Array[ItemStack] = []
var key_items: Array[StringName] = []
var selected_hotbar_index: int = 0


func _ready() -> void:
	hotbar.resize(HOTBAR_SIZE)
	storage.resize(STORAGE_SIZE)


## Adds `count` of `item_id`, topping up existing stacks first, then filling
## empty slots, hotbar before storage. Returns the leftover that did not
## fit. KEY-category items route to the reserved key item area instead.
func add_item(item_id: StringName, count: int = 1) -> int:
	var def: ItemDef = ItemRegistry.get_def(item_id)
	if def != null and def.category == ItemDef.Category.KEY:
		add_key_item(item_id)
		return 0
	var cap: int = ItemRegistry.stack_max_of(item_id)
	var remaining: int = count
	for slots: Array in [hotbar, storage]:
		for i: int in slots.size():
			if remaining <= 0:
				break
			var stack: ItemStack = slots[i]
			if stack != null and stack.id == item_id and stack.count < cap:
				var moved: int = mini(cap - stack.count, remaining)
				stack.count += moved
				remaining -= moved
	for slots: Array in [hotbar, storage]:
		for i: int in slots.size():
			if remaining <= 0:
				break
			if slots[i] == null:
				var moved: int = mini(cap, remaining)
				slots[i] = ItemStack.new(item_id, moved)
				remaining -= moved
	if remaining != count:
		changed.emit()
	return remaining


## Removes up to `count` of `item_id` (hotbar first). Returns how many
## were actually removed.
func remove_item(item_id: StringName, count: int = 1) -> int:
	var remaining: int = count
	for slots: Array in [hotbar, storage]:
		for i: int in slots.size():
			if remaining <= 0:
				break
			var stack: ItemStack = slots[i]
			if stack != null and stack.id == item_id:
				var taken: int = mini(stack.count, remaining)
				stack.count -= taken
				remaining -= taken
				if stack.count == 0:
					slots[i] = null
	var removed: int = count - remaining
	if removed > 0:
		changed.emit()
	return removed


func count_of(item_id: StringName) -> int:
	var total: int = 0
	for slots: Array in [hotbar, storage]:
		for stack: Variant in slots:
			if stack != null and (stack as ItemStack).id == item_id:
				total += (stack as ItemStack).count
	return total


## Move a whole slot: into an empty slot, merge onto the same id (partial
## merges leave the remainder behind), or swap different ids.
func transfer(from_area: Area, from_index: int, to_area: Area, to_index: int) -> bool:
	var from_slots: Array[ItemStack] = _area(from_area)
	var to_slots: Array[ItemStack] = _area(to_area)
	if from_index < 0 or from_index >= from_slots.size():
		return false
	if to_index < 0 or to_index >= to_slots.size():
		return false
	if from_area == to_area and from_index == to_index:
		return false
	var src: ItemStack = from_slots[from_index]
	if src == null:
		return false
	var dst: ItemStack = to_slots[to_index]
	if dst == null:
		to_slots[to_index] = src
		from_slots[from_index] = null
	elif dst.id == src.id:
		var moved: int = mini(ItemRegistry.stack_max_of(src.id) - dst.count, src.count)
		if moved <= 0:
			return false
		dst.count += moved
		src.count -= moved
		if src.count == 0:
			from_slots[from_index] = null
	else:
		to_slots[to_index] = src
		from_slots[from_index] = dst
	changed.emit()
	return true


## Split `amount` off a stack into an empty slot or onto a same-id stack
## with room for all of it. Must leave at least one behind (a full move
## is transfer()).
func split_stack(from_area: Area, from_index: int, amount: int, to_area: Area, to_index: int) -> bool:
	var from_slots: Array[ItemStack] = _area(from_area)
	var to_slots: Array[ItemStack] = _area(to_area)
	if from_index < 0 or from_index >= from_slots.size():
		return false
	if to_index < 0 or to_index >= to_slots.size():
		return false
	if from_area == to_area and from_index == to_index:
		return false
	var src: ItemStack = from_slots[from_index]
	if src == null or amount <= 0 or amount >= src.count:
		return false
	var dst: ItemStack = to_slots[to_index]
	if dst == null:
		to_slots[to_index] = ItemStack.new(src.id, amount)
	elif dst.id == src.id and dst.count + amount <= ItemRegistry.stack_max_of(src.id):
		dst.count += amount
	else:
		return false
	src.count -= amount
	changed.emit()
	return true


## One-click move of a whole slot to the other area: merge into existing
## stacks first, then the first empty slot.
func quick_transfer(from_area: Area, from_index: int) -> bool:
	var from_slots: Array[ItemStack] = _area(from_area)
	if from_index < 0 or from_index >= from_slots.size():
		return false
	var stack: ItemStack = from_slots[from_index]
	if stack == null:
		return false
	var to_slots: Array[ItemStack] = _area(Area.STORAGE if from_area == Area.HOTBAR else Area.HOTBAR)
	var cap: int = ItemRegistry.stack_max_of(stack.id)
	var moved_any: bool = false
	for other: ItemStack in to_slots:
		if stack.count <= 0:
			break
		if other != null and other.id == stack.id and other.count < cap:
			var moved: int = mini(cap - other.count, stack.count)
			other.count += moved
			stack.count -= moved
			moved_any = true
	if stack.count == 0:
		from_slots[from_index] = null
	else:
		for i: int in to_slots.size():
			if to_slots[i] == null:
				to_slots[i] = stack
				from_slots[from_index] = null
				moved_any = true
				break
	if moved_any:
		changed.emit()
	return moved_any


func select_hotbar(index: int) -> void:
	var clamped: int = clampi(index, 0, HOTBAR_SIZE - 1)
	if clamped == selected_hotbar_index:
		return
	selected_hotbar_index = clamped
	selection_changed.emit(selected_hotbar_index)


func select_next() -> void:
	selected_hotbar_index = (selected_hotbar_index + 1) % HOTBAR_SIZE
	selection_changed.emit(selected_hotbar_index)


func select_prev() -> void:
	selected_hotbar_index = (selected_hotbar_index + HOTBAR_SIZE - 1) % HOTBAR_SIZE
	selection_changed.emit(selected_hotbar_index)


func selected_stack() -> ItemStack:
	return hotbar[selected_hotbar_index]


## Setu components and other uniques. Never in the 40 slots, never stacked.
func add_key_item(item_id: StringName) -> void:
	if key_items.has(item_id):
		return
	key_items.append(item_id)
	changed.emit()


func has_key_item(item_id: StringName) -> bool:
	return key_items.has(item_id)


func clear() -> void:
	hotbar = []
	storage = []
	hotbar.resize(HOTBAR_SIZE)
	storage.resize(STORAGE_SIZE)
	key_items.clear()
	selected_hotbar_index = 0
	changed.emit()


func get_save_data() -> Dictionary:
	var keys: Array = []
	for k: StringName in key_items:
		keys.append(String(k))
	return {
		"hotbar": _serialize(hotbar),
		"storage": _serialize(storage),
		"key_items": keys,
		"selected": selected_hotbar_index,
	}


func apply_save_data(data: Dictionary) -> void:
	clear()
	_deserialize_into(hotbar, data.get("hotbar", []))
	_deserialize_into(storage, data.get("storage", []))
	for k: Variant in data.get("key_items", []):
		var id: StringName = StringName(str(k))
		if not key_items.has(id):
			key_items.append(id)
	selected_hotbar_index = clampi(int(data.get("selected", 0)), 0, HOTBAR_SIZE - 1)
	changed.emit()


func _area(area: Area) -> Array[ItemStack]:
	return hotbar if area == Area.HOTBAR else storage


static func _serialize(slots: Array) -> Array:
	var out: Array = []
	for stack: Variant in slots:
		out.append((stack as ItemStack).to_dict() if stack != null else null)
	return out


static func _deserialize_into(slots: Array, entries: Array) -> void:
	for i: int in mini(slots.size(), entries.size()):
		var entry: Variant = entries[i]
		if entry is Dictionary:
			slots[i] = ItemStack.from_dict(entry)
