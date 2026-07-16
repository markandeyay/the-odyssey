extends Node
## 10-slot hotbar + 30-slot storage + reserved Setu key items (ARCHITECTURE §8).
## M1 skeleton: slot arrays and constants only. Stacking, item Resources,
## transfer, and the salvage types land in M5.

const HOTBAR_SIZE: int = 10
const STORAGE_SIZE: int = 30
const STACK_MAX: int = 20

## Slots hold null when empty. The slot type becomes an ItemStack in M5.
var hotbar: Array = []
var storage: Array = []
## Setu components live here, outside the 40 slots. They never stack.
var key_items: Array[StringName] = []
var selected_hotbar_index: int = 0


func _ready() -> void:
	hotbar.resize(HOTBAR_SIZE)
	storage.resize(STORAGE_SIZE)
