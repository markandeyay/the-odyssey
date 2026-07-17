extends Node3D


func _ready() -> void:
	_activate_authored_fires.call_deferred()


func _activate_authored_fires() -> void:
	await get_tree().physics_frame
	var fire_grid: Node = get_node_or_null("GameplaySockets/FireGrid")
	var sockets: Node = get_node_or_null("GameplaySockets")
	if fire_grid == null or sockets == null or not fire_grid.has_method("ignite_at"):
		push_error("Ember Quarter M9 fire integration is incomplete")
		return
	for socket: Node in sockets.get_children():
		if socket.get_meta(&"socket_type", &"") == &"fire_source" and socket is Node3D:
			fire_grid.call("ignite_at", (socket as Node3D).global_position)
