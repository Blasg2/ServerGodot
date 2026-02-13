extends Node

@export var player_scene: PackedScene


var avatars: Dictionary = {}  # { peer_id: Node }
var _login_flow_started := false

signal auth_done(success: bool)


func _ready() -> void:
	NetworkManager.server_disconnected.connect(func():
		_login_flow_started = false
	)

	# Client auth flow
	NetworkEvents.on_client_start.connect(_handle_connected)

	# Connect auth signals ONCE
	if not NetworkManager.login_successful.is_connected(_on_login_success):
		NetworkManager.login_successful.connect(_on_login_success)
	if not NetworkManager.login_failed.is_connected(_on_login_fail):
		NetworkManager.login_failed.connect(_on_login_fail)

	# When any peer's player node gets added as a child (by spawner replication),
	# we need to configure it locally
	child_entered_tree.connect(_on_child_added)


# ── CLIENT AUTH FLOW (unchanged) ─────────────────────────────

func _handle_connected(_id: int) -> void:
	if _login_flow_started:
		return
	_login_flow_started = true

	if not multiplayer.multiplayer_peer \
	or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		await multiplayer.connected_to_server

	NetworkManager.send_login(NetworkManager.pending_username, NetworkManager.pending_password)

	var ok: bool = await auth_done
	if not ok:
		return

	# Server will handle spawning via MultiplayerSpawner
	NetworkManager.notify_ready_in_world()


func _on_login_success(_account_data: Dictionary) -> void:
	auth_done.emit(true)


func _on_login_fail(reason: String) -> void:
	print("❌ Login failed: ", reason)
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_login_flow_started = false
	auth_done.emit(false)


# ── SERVER-ONLY: Spawn player (MultiplayerSpawner replicates it) ──

func spawn_player(peer_id: int) -> void:
	# Only server should call this
	if not multiplayer.is_server():
		return

	if avatars.has(peer_id):
		print("⚠️ Avatar for peer %d already exists" % peer_id)
		return

	var avatar := player_scene.instantiate() as Node
	# Name MUST be the peer_id string for multiplayer to work properly
	avatar.name = str(peer_id)

	# Set authority BEFORE adding to tree
	# (MultiplayerSpawner reads this when replicating)
	avatar.set_multiplayer_authority(1)

	# Add as child — MultiplayerSpawner detects this and replicates to all peers
	add_child(avatar, true)

	avatar.global_position = Vector3.ZERO

	print("Server spawned avatar for peer %d" % peer_id)


func despawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	if avatars.has(peer_id):
		var avatar = avatars[peer_id]
		if is_instance_valid(avatar):
			avatar.queue_free()  # MultiplayerSpawner auto-removes on all peers
		avatars.erase(peer_id)
		print("Server despawned peer %d" % peer_id)


# ── RUNS ON ALL PEERS when MultiplayerSpawner replicates a child ──

func _on_child_added(node: Node) -> void:
	# Ignore non-player nodes (like the MultiplayerSpawner itself)
	if not node.has_method("_rollback_tick"):
		return

	# The node name is the peer_id (set by the server before add_child)
	var peer_id := node.name.to_int()
	if peer_id == 0:
		return

	avatars[peer_id] = node
	print("Player node appeared for peer %d (on peer %d)" % [peer_id, multiplayer.get_unique_id()])

	# Set Input authority to the owning player
	var input := node.find_child("Input")
	if input != null:
		input.set_multiplayer_authority(peer_id)

	# If this is OUR player, activate camera/HUD
	if peer_id == multiplayer.get_unique_id():
		var control = get_node_or_null("../../Control")
		if is_instance_valid(control):
			control.queue_free()





	
