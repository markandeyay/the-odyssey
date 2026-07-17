extends SceneTree

const MixamoBoneMap: Script = preload("res://src/tools/character_pipeline/mixamo_bone_map.gd")
const OUTPUT_PATH: String = "res://src/tools/character_pipeline/mixamo_humanoid_bone_map.tres"


func _initialize() -> void:
	var manifest: Dictionary = MixamoBoneMap.load_manifest()
	if manifest.is_empty():
		printerr("Unable to load Mixamo manifest")
		quit(1)
		return
	var result: Error = ResourceSaver.save(MixamoBoneMap.create(manifest), OUTPUT_PATH)
	if result != OK:
		printerr("Unable to save %s: %s" % [OUTPUT_PATH, error_string(result)])
		quit(1)
		return
	print("Wrote %s" % OUTPUT_PATH)
	quit(0)
