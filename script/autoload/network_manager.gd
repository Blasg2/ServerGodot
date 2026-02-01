# res://script/autoload/network_manager.gd
extends Node

## Configuration
@export var default_port: int = 7777
@export var max_players: int = 10

## Network state
var peer := ENetMultiplayerPeer.new()
var is_server: bool = false
var player_id: int = -1

## Pending login credentials (for scene change before connection)
var pending_username: String = ""
var pending_password: String = ""

## Authentication state (SERVER ONLY)
var authenticated_players: Dictionary = {}
var online_usernames: Dictionary = {}  # {username: peer_id}


## Signals
signal player_connected(id: int)
signal player_disconnected(id: int)
signal server_disconnected()
signal login_successful(account_data: Dictionary)
signal login_failed(reason: String)
signal player_authenticated(id: int)

	
func _ready() -> void:
	var args = OS.get_cmdline_args()
	
	if "--server" in args:
		start_server()
	elif "--host" in args:
		start_server()



## CLIENT: Tell server we're ready in game world
func notify_ready_in_world() -> void:
	rpc_id(1, "_client_ready_in_world")

## SERVER: Client is now ready for spawning
@rpc("any_peer", "reliable")
func _client_ready_in_world() -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	print(">>> Client ready in world: ", sender_id)
	
	if authenticated_players.has(sender_id):
		player_authenticated.emit(sender_id)  # NOW spawn



func start_server(port: int = default_port) -> void:
	peer.create_server(port, max_players)
	multiplayer.multiplayer_peer = peer
	is_server = true
	player_id = 1
	
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	print("Server started on port ", port)


func connect_to_server(address: String = "localhost", port: int = default_port) -> void:
	peer.create_client(address, port)
	multiplayer.multiplayer_peer = peer
	is_server = false
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	print("Connecting to ", address, ":", port)

func _on_player_connected(id: int) -> void:
	print("Player connected: ", id)
	player_connected.emit(id)

func _on_player_disconnected(id: int) -> void:
	print("Player disconnected: ", id)
	
	if authenticated_players.has(id):
		var username = authenticated_players[id].get("username", "unknown")
		authenticated_players.erase(id)
		online_usernames.erase(username)  # Remove from online list
		print("Removed ", username, " from authenticated players")
	
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	player_id = multiplayer.get_unique_id()
	print("Connected to server! My peer ID: ", player_id)

func _on_connection_failed() -> void:
	print("Connection failed!")

func _on_server_disconnected() -> void:
	print("Disconnected from server")
	server_disconnected.emit()

func get_player_count() -> int:
	return multiplayer.get_peers().size() + (1 if is_server else 0)

## CLIENT: Send login credentials to server
func send_login(username: String, password: String) -> void:
	print("Sending login request for: ", username)
	rpc_id(1, "_receive_login", username, password)

## SERVER: Receive and validate login
@rpc("any_peer", "reliable")
func _receive_login(username: String, password: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	print("\n=== LOGIN REQUEST ===")
	print("From peer: ", sender_id)
	print("Username: ", username)
	
	var account = Authentication.validate_login(username, password)
	
	if account.is_empty():
		print("❌ Authentication failed for ", username)
		rpc_id(sender_id, "_login_response", false, {}, "Invalid credentials")
		return
	
	# Check if user is already online
	if online_usernames.has(username):
		print("❌ User already online: ", username)
		rpc_id(sender_id, "_login_response", false, {}, "User already logged in")
		return
	
	authenticated_players[sender_id] = account
	online_usernames[username] = sender_id
	print("✓ Player authenticated: ", username, " (peer ", sender_id, ")")
	print("Total authenticated players: ", authenticated_players.size())
	print("=====================\n")
	
	rpc_id(sender_id, "_login_response", true, account, "")
	
	player_authenticated.emit(sender_id)
	
## CLIENT: Receive login response from server
@rpc("authority", "reliable")
func _login_response(success: bool, account_data: Dictionary, error_message: String) -> void:
	if success:
		print("✓ Login successful!")
		login_successful.emit(account_data)
	else:
		print("❌ Login failed: ", error_message)
		login_failed.emit(error_message)

func get_account_data(peer_id: int) -> Dictionary:
	if not is_server:
		push_warning("get_account_data called on client!")
		return {}
	
	return authenticated_players.get(peer_id, {})
