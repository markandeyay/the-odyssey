class_name FragmentRegistry
extends RefCounted
## Serves FragmentDefs by id (M12). Data driven like the ItemRegistry:
## WORLD drops a .tres under assets/fragments/ and the fragment exists.
## A missing directory is fine — the reader falls back to a waterlogged
## placeholder until the content is authored.

const FRAGMENTS_DIR: String = "res://assets/fragments/"

static var _defs: Dictionary = {}
static var _loaded: bool = false


static func get_def(id: StringName) -> FragmentDef:
	_ensure_loaded()
	return _defs.get(id, null)


static func count() -> int:
	_ensure_loaded()
	return _defs.size()


## Drops the cache and loads from `dir` instead. Tests point this at a
## fixture directory; production code never calls it.
static func reset(dir: String = FRAGMENTS_DIR) -> void:
	_defs = {}
	_loaded = false
	_load_from(dir)
	_loaded = true


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_from(FRAGMENTS_DIR)


static func _load_from(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return  # not authored yet; the reader has a fallback
	for file_name: String in dir.get_files():
		# Exported builds list remapped resources as <name>.tres.remap.
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var def: FragmentDef = load(dir_path + clean) as FragmentDef
		if def == null:
			push_warning("FragmentRegistry: %s is not a FragmentDef" % clean)
			continue
		if def.id == &"":
			push_warning("FragmentRegistry: %s has an empty id" % clean)
			continue
		if _defs.has(def.id):
			push_warning("FragmentRegistry: duplicate fragment id %s (%s)" % [def.id, clean])
		_defs[def.id] = def
