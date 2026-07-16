@tool
extends Node3D

const VISUAL_PATH: String = "res://assets/characters/nau/nau_visual.tscn"

@export_range(25.0, 250.0, 1.0, "suffix:m") var viewing_distance_m: float = 200.0:
	set(value):
		viewing_distance_m = value
		_update_camera()


func _ready() -> void:
	if get_node_or_null("NauVisual") == null:
		_load_visual()
	_update_camera()


func _load_visual() -> void:
	if not ResourceLoader.exists(VISUAL_PATH, "PackedScene"):
		push_warning("M3 silhouette preview is waiting for %s" % VISUAL_PATH)
		return
	var packed: PackedScene = load(VISUAL_PATH) as PackedScene
	var visual: Node = packed.instantiate()
	visual.name = "NauVisual"
	add_child(visual)


func _update_camera() -> void:
	var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	camera.position = Vector3(0.0, 1.05, -viewing_distance_m)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)
