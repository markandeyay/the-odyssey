class_name ItemRegistry
extends RefCounted
## Loads every ItemDef under src/inventory/items/ and serves them by id
## (M5). Data driven: add a .tres and the item exists. No hardcoded tables.

const ITEMS_DIR: String = "res://src/inventory/items/"
const DEFAULT_STACK_MAX: int = 20

static var _defs: Dictionary = {}
static var _loaded: bool = false


static func get_def(id: StringName) -> ItemDef:
	_ensure_loaded()
	return _defs.get(id, null)


static func stack_max_of(id: StringName) -> int:
	var def: ItemDef = get_def(id)
	return def.stack_max if def != null else DEFAULT_STACK_MAX


static func all_defs() -> Array[ItemDef]:
	_ensure_loaded()
	var out: Array[ItemDef] = []
	for id: StringName in _defs:
		out.append(_defs[id])
	return out


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir: DirAccess = DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_error("ItemRegistry: cannot open %s" % ITEMS_DIR)
		return
	for file_name: String in dir.get_files():
		# Exported builds list remapped resources as <name>.tres.remap.
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var def: ItemDef = load(ITEMS_DIR + clean) as ItemDef
		if def == null:
			push_warning("ItemRegistry: %s is not an ItemDef" % clean)
			continue
		if def.id == &"":
			push_warning("ItemRegistry: %s has an empty id" % clean)
			continue
		if _defs.has(def.id):
			push_warning("ItemRegistry: duplicate item id %s (%s)" % [def.id, clean])
		_defs[def.id] = def
