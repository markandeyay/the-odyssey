extends Node
## Debug-only viewport capture for the MCP review loop. An external agent can
## launch the game via godot-mcp but cannot otherwise see a rendered frame, so
## when enabled this writes periodic PNGs of the live viewport to
## user://review/frames/ and drives a short scripted movement/locomotion
## sequence so every locomotion state gets a frame without a human at the
## keyboard.
## Double-gated so it never runs outside that loop: OS.is_debug_build() keeps
## it out of exported builds, and the ODYSSEY_CAPTURE_FRAMES env var (set only
## on the godot-mcp server registration, not present in a normal editor run)
## keeps it from firing during ordinary dev play.

const CAPTURE_DIR: String = "user://review/frames/"
const CAPTURE_ENV_VAR: String = "ODYSSEY_CAPTURE_FRAMES"
const CAPTURE_INTERVAL_SEC: float = 0.25
const PROOF_LOCOMOTION_STATES: Array[StringName] = [
	&"sprint", &"swim_idle", &"swim_move", &"crouch_idle", &"climb_idle", &"climb_move",
]

var _enabled: bool = false
var _elapsed_since_capture: float = 0.0
var _frame_index: int = 0


func _ready() -> void:
	_enabled = OS.is_debug_build() and OS.get_environment(CAPTURE_ENV_VAR) == "1"
	printerr("FrameCapture: enabled=%s env_value=%s" % [_enabled, OS.get_environment(CAPTURE_ENV_VAR)])
	if not _enabled:
		set_process(false)
		return
	var absolute_dir: String = ProjectSettings.globalize_path(CAPTURE_DIR)
	if DirAccess.dir_exists_absolute(absolute_dir):
		_clear_directory(absolute_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	printerr("FrameCapture: writing frames to %s" % absolute_dir)
	_run_proof_sequence.call_deferred()


func _process(delta: float) -> void:
	if not _enabled:
		return
	_elapsed_since_capture += delta
	if _elapsed_since_capture < CAPTURE_INTERVAL_SEC:
		return
	_elapsed_since_capture = 0.0
	_frame_index += 1
	_capture_frame("frame_%04d" % _frame_index)


func _capture_frame(label: String) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return
	var path: String = "%s%s.png" % [CAPTURE_DIR, label]
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		printerr("FrameCapture: unable to save %s: %s" % [path, error_string(save_error)])
		return
	print("FrameCapture: wrote %s" % path)


func _run_proof_sequence() -> void:
	await get_tree().create_timer(2.5).timeout
	var players: Array[Node] = get_tree().root.find_children("*", "Player", true, false)
	if players.is_empty():
		printerr("FrameCapture: proof sequence found no Player node")
		return
	var player: Node3D = players[0] as Node3D
	var animator: Node = player.get_node_or_null("Animator")
	if animator == null:
		printerr("FrameCapture: proof sequence found no Animator child")
		return

	# The level's own camera does not track the player closely enough for a
	# review screenshot to show the mesh, so attach a temporary chase camera
	# for the duration of this sequence and hand control back afterward.
	var previous_camera: Camera3D = get_viewport().get_camera_3d()
	var review_camera: Camera3D = Camera3D.new()
	player.add_child(review_camera)
	review_camera.position = Vector3(0.0, 1.6, 2.6)
	review_camera.look_at(player.global_position + Vector3.UP * 1.0, Vector3.UP)
	review_camera.current = true
	# The spawn shore is nearly unlit, so light the mesh from the camera the
	# same way the terrain-pipeline capture tools do or the review frames
	# render silhouette-on-black.
	var inspection_light: OmniLight3D = OmniLight3D.new()
	inspection_light.light_energy = 3.0
	inspection_light.omni_range = 12.0
	review_camera.add_child(inspection_light)

	Input.action_press(&"move_forward")
	await get_tree().create_timer(2.0).timeout
	_capture_frame("proof_walk_forward")
	Input.action_release(&"move_forward")
	await get_tree().create_timer(1.0).timeout
	_capture_frame("proof_idle_at_rest")

	# Force each aliased state directly through the animator with physics
	# paused, so the real _update_animator() locomotion logic (which would
	# otherwise override these every physics tick) can't fight the forced
	# state before it gets captured.
	player.set_physics_process(false)
	for state_name: StringName in PROOF_LOCOMOTION_STATES:
		animator.call(&"set_locomotion", state_name)
		review_camera.look_at(player.global_position + Vector3.UP * 1.2, Vector3.UP)
		await get_tree().create_timer(0.4).timeout
		_capture_frame("proof_%s" % state_name)
	player.set_physics_process(true)

	review_camera.queue_free()
	if is_instance_valid(previous_camera):
		previous_camera.current = true


func _clear_directory(absolute_dir: String) -> void:
	var dir: DirAccess = DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
