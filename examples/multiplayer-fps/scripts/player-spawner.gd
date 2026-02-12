# res://.../player_spawner.gd  (your script that currently extends Node)
extends Node

@export var player_scene: PackedScene
@export var spawn_points: Array[Marker3D] = []

var avatars: Dictionary = {} # { peer_id: Node }
var _login_flow_started := false

signal auth_done(success: bool)


func _ready() -> void:
	# Netfox / your events
	NetworkManager.server_disconnected.connect(func():
		_login_flow_started = false
	)
	NetworkEvents.on_client_start.connect(_handle_connected)
	#NetworkEvents.on_server_start.connect(_handle_host)
	#NetworkEvents.on_peer_join.connect(_handle_new_peer)
	#NetworkEvents.on_peer_leave.connect(_handle_leave)
	#NetworkEvents.on_client_stop.connect(_handle_stop)
	#NetworkEvents.on_server_stop.connect(_handle_stop)

	# Connect auth signals ONCE (do not reconnect every time)
	if not NetworkManager.login_successful.is_connected(_on_login_success):
		NetworkManager.login_successful.connect(_on_login_success)
	if not NetworkManager.login_failed.is_connected(_on_login_fail):
		NetworkManager.login_failed.connect(_on_login_fail)


func _handle_connected(id: int) -> void:
	# Prevent running twice (netfox / scene reloads / duplicate signals)
	if _login_flow_started:
		return
	_login_flow_started = true

	# Ensure we're actually connected before sending RPCs
	if not multiplayer.multiplayer_peer \
	or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		await multiplayer.connected_to_server

	# Send login (credentials were stored in NetworkManager by main_menu.gd)
	NetworkManager.send_login(NetworkManager.pending_username, NetworkManager.pending_password)

	# Wait for either success OR fail
	var ok: bool = await auth_done
	if not ok:
		# Wrong password etc -> do NOT spawn a dummy player
		return

	# Tell server we're ready (server uses this to allow spawning / bookkeeping)
	NetworkManager.notify_ready_in_world()

	# Spawn locally only after success
	_spawn(id)


func _on_login_success(_account_data: Dictionary) -> void:
	auth_done.emit(true)


func _on_login_fail(reason: String) -> void:
	print("❌ Login failed: ", reason)

	# remove any accidental spawns
	for a in avatars.values():
		if is_instance_valid(a):
			a.queue_free()
	avatars.clear()

	# Disconnect
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	# IMPORTANT: allow trying again
	_login_flow_started = false

	auth_done.emit(false)



func _spawn(id: int) -> void:
	var avatar := player_scene.instantiate() as Node
	avatars[id] = avatar

	avatar.name += " #%d" % id
	add_child(avatar)

	avatar.global_position = get_next_spawn_point(id)

	# Remove UI if present
	if is_instance_valid($"../../Control"):
		$"../../Control".queue_free()

	# Avatar is always owned by server (your current approach)
	avatar.set_multiplayer_authority(1)

	print("Spawned avatar %s at %s" % [avatar.name, multiplayer.get_unique_id()])

	# Avatar's input object is owned by player
	var input := avatar.find_child("Input")
	if input != null:
		input.set_multiplayer_authority(id)
		print("Set input(%s) ownership to %s" % [input.name, id])

	# Swap cameras
	$"../../Environment/Camera3D".current = false
	avatar.get_node("Head/Camera3D").current = true


func get_next_spawn_point(peer_id: int, spawn_idx: int = 0) -> Vector3:
	if spawn_points.is_empty():
		return Vector3.ZERO

	var idx := peer_id * 37 + spawn_idx * 19
	idx = hash(idx)
	idx = idx % spawn_points.size()
	return spawn_points[idx].global_position
