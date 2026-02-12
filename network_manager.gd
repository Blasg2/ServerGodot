# res://script/autoload/network_manager.gd
extends Node

## Network configuration
@export var default_port: int = 7777
@export var max_players: int = 99

## Network state
var peer := ENetMultiplayerPeer.new()
var player_id: int = -1

## Pending login credentials (stored before scene change)
var pending_username: String = ""
var pending_password: String = ""

## Authentication state (SERVER ONLY)
var authenticated_players: Dictionary = {}  # {peer_id: account_data}
var online_usernames: Dictionary = {}  # {username: peer_id} - prevents duplicate logins

## Signals
signal server_disconnected()
signal login_successful(account_data: Dictionary)
signal login_failed(reason: String)
signal player_authenticated(id: int)  # Server tells game_world to spawn player
signal unspawn_player



## CLIENT: Tell server we're ready in game world
func notify_ready_in_world() -> void:
	rpc_id(1, "_client_ready_in_world")

## SERVER: Client is now ready for spawning
@rpc("any_peer", "reliable")
func _client_ready_in_world() -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	
	if authenticated_players.has(sender_id):
		print(">>> Client ready in world: ", sender_id)
		player_authenticated.emit(sender_id)  # Tell game_world to spawn
		
## Start server
func start_server(port: int = default_port) -> void:
	peer.create_server(port, max_players)
	multiplayer.multiplayer_peer = peer
	player_id = 1
	
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	print("Server started on port ", port)
	

## Connect to server
func connect_to_server(address: String = "201.17.248.223", port: int = default_port) -> void:
	peer.create_client(address, port)
	multiplayer.multiplayer_peer = peer
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	

## CLIENT: Send login credentials to server
func send_login(username: String, password: String) -> void:
	rpc_id(1, "_receive_login", username, password)

## SERVER: Receive and validate login
@rpc("any_peer", "reliable")
func _receive_login(username: String, password: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	print("\n=== LOGIN REQUEST ===")
	print("Peer: ", sender_id, " | Username: ", username)
	
	# Validate credentials
	var account = Authentication.validate_login(username, password)
	if account.is_empty():
		rpc_id(sender_id, "_login_response", false, {}, "Invalid credentials")
		return
	
	# Check if already online
	if online_usernames.has(username):
		print("❌ User already online: ", username)
		rpc_id(sender_id, "_login_response", false, {}, "User already logged in")
		return
	
	# Success - store authentication
	authenticated_players[sender_id] = account
	online_usernames[username] = sender_id
	print("✓ Authenticated: ", username)
	
	rpc_id(sender_id, "_login_response", true, account, "")

## CLIENT: Receive login response from server
@rpc("authority", "reliable")
func _login_response(success: bool, account_data: Dictionary, error_message: String) -> void:
	if success:
		print("✓ Login successful! --message to player")
		login_successful.emit(account_data)
	else:
		print("❌ Login failed: ", error_message)
		login_failed.emit(error_message)

## Get account data for a peer (SERVER ONLY)
func get_account_data(peer_id: int) -> Dictionary:
	if multiplayer.is_server():
		return authenticated_players.get(peer_id, {})
	return {}

## Network event handlers
func _on_player_connected(id: int) -> void:
	print("Player connected: ", id)

func _on_player_disconnected(id: int) -> void:
	print("Player disconnected: ", id)
	
	# Clean up authentication
	if authenticated_players.has(id):
		var username = authenticated_players[id].get("username", "unknown")
		authenticated_players.erase(id)
		online_usernames.erase(username)
		print("Removed ", username, " from authenticated players")
		unspawn_player.emit(id, username)

func _on_connected_to_server() -> void:
	player_id = multiplayer.get_unique_id()

func _on_connection_failed() -> void:
	print("Connection failed!")

func _on_server_disconnected() -> void:
	print("Disconnected from server")
	server_disconnected.emit()




## Utility  -may be wrong?
func get_player_count() -> int:
	return multiplayer.get_peers().size() + (1 if multiplayer.is_server() else 0)
	
	
