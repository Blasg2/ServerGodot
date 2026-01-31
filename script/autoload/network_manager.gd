extends Node

## Configuration
@export var default_port: int = 7777
@export var max_players: int = 10

## Network state
var peer := ENetMultiplayerPeer.new()
var is_server: bool = false
var player_id: int = -1

## Signals
signal player_connected(id: int)
signal player_disconnected(id: int)
signal server_disconnected()

func _ready() -> void:
	# Parse command line args
	var args = OS.get_cmdline_args()
	
	if "--server" in args:
		start_server()
	elif "--host" in args:
		start_server()  # Host is server that also has local player
	# Otherwise, wait for UI to call connect_to_server()

## Start as dedicated/listen server
func start_server(port: int = default_port) -> void:
	peer.create_server(port, max_players)
	multiplayer.multiplayer_peer = peer
	is_server = true
	player_id = 1
	
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	print("Server started on port ", port)

## Connect as client
func connect_to_server(address: String = "localhost", port: int = default_port) -> void:
	peer.create_client(address, port)
	multiplayer.multiplayer_peer = peer
	is_server = false
	
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	print("Connecting to ", address, ":", port)

## Server callbacks
func _on_player_connected(id: int) -> void:
	print("Player connected: ", id)
	player_connected.emit(id)

func _on_player_disconnected(id: int) -> void:
	print("Player disconnected: ", id)
	player_disconnected.emit(id)

## Client callbacks
func _on_connected_to_server() -> void:
	player_id = multiplayer.get_unique_id()
	print("Connected to server! My ID: ", player_id)

func _on_connection_failed() -> void:
	print("Connection failed!")

func _on_server_disconnected() -> void:
	print("Disconnected from server")
	server_disconnected.emit()

## Utility
func get_player_count() -> int:
	return multiplayer.get_peers().size() + (1 if is_server else 0)
