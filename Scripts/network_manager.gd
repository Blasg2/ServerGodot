extends Node

@export var default_port: int = 7777
@export var max_players: int = 99
@export var server_ip := "201.17.248.223"

var peer := ENetMultiplayerPeer.new()

var pending_username: String = ""
var pending_password: String = ""

var authenticated_players: Dictionary = {}
var online_usernames: Dictionary = {}

signal login_successful(account_data: Dictionary)
signal login_failed(reason: String)
signal player_authenticated(id: int)

func _ready() -> void:
	NetworkEvents.on_peer_leave.connect(_on_peer_leave)

func start_server(port: int = default_port) -> void:
	peer.create_server(port, max_players)
	multiplayer.multiplayer_peer = peer
	print("Server started on port ", port)

func connect_to_server(address: String = server_ip, port: int = default_port) -> void:
	peer.create_client(address, port)
	multiplayer.multiplayer_peer = peer

func notify_ready_in_world() -> void:
	rpc_id(1, "_client_ready_in_world")

@rpc("any_peer", "reliable")
func _client_ready_in_world() -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if authenticated_players.has(sender_id):
		player_authenticated.emit(sender_id)

func send_login(username: String, password: String) -> void:
	rpc_id(1, "_receive_login", username, password)

@rpc("any_peer", "reliable")
func _receive_login(username: String, password: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	var account = Authentication.validate_login(username, password)
	if account.is_empty():
		rpc_id(sender_id, "_login_response", false, {}, "Senha incorreta.")
		return
	if online_usernames.has(username):
		rpc_id(sender_id, "_login_response", false, {}, "Player já está logado.")
		return
	authenticated_players[sender_id] = account
	online_usernames[username] = sender_id
	rpc_id(sender_id, "_login_response", true, account, "")

@rpc("authority", "reliable")
func _login_response(success: bool, account_data: Dictionary, error_message: String) -> void:
	if success:
		login_successful.emit(account_data)
	else:
		login_failed.emit(error_message)

func get_account_data(peer_id: int) -> Dictionary:
	if multiplayer.is_server():
		return authenticated_players.get(peer_id, {})
	return {}

func _on_peer_leave(id: int) -> void:
	if authenticated_players.has(id):
		var username = authenticated_players[id].get("username", "unknown")
		authenticated_players.erase(id)
		online_usernames.erase(username)
