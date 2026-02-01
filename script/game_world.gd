extends Node3D

## Fired when a playable level is present under $Levels.
signal level_ready(level: Node3D)

@onready var levels: Node3D = $Levels
@onready var level_spawner: MultiplayerSpawner = $LevelSpawn

var current_level: Node3D
var character_scene: PackedScene = load("uid://t04xmkgtd7i8") # character.tscn
var default_level_scene: PackedScene = load("uid://uaj1iyaf1711") # level_1.tscn

var game_started: bool = false

func _ready() -> void:
	print("=== GAME WORLD READY ===")
	print("Has peer: ", multiplayer.multiplayer_peer != null)
	print("Is server: ", multiplayer.is_server())

	# Safe to connect even before a peer exists.
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	NetworkManager.player_authenticated.connect(_on_player_authenticated)

	# Watch for level instances being spawned under $Levels.
	if level_spawner:
		level_spawner.spawned.connect(_on_level_spawned)
		level_spawner.despawned.connect(_on_level_despawned)
		print("✓ Level spawner connected")

	# Only autostart when you explicitly run with args.
	var args := OS.get_cmdline_args()
	if "--server" in args or "--host" in args:
		game_started = true
		_hide_main_menu()
		if not multiplayer.multiplayer_peer:
			NetworkManager.start_server()
		_ensure_level_spawned()

	print("========================")

## Called by MainMenu when pressing "server".
func start_host_game() -> void:
	game_started = true
	_hide_main_menu()

	if not multiplayer.multiplayer_peer:
		NetworkManager.start_server()

	_ensure_level_spawned()
	await _wait_for_level_ready()

## Called by MainMenu when pressing "client".
func start_client_game(username: String, password: String, address: String = "localhost") -> void:
	game_started = true
	_hide_main_menu()

	NetworkManager.pending_username = username
	NetworkManager.pending_password = password
	NetworkManager.connect_to_server(address)
	_handle_client_authentication()

func _handle_client_authentication() -> void:
	print("Client waiting for connection...")

	if not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		await multiplayer.connected_to_server

	# Connect signals BEFORE sending login
	if not NetworkManager.login_successful.is_connected(_on_login_success):
		NetworkManager.login_successful.connect(_on_login_success)
	if not NetworkManager.login_failed.is_connected(_on_login_fail):
		NetworkManager.login_failed.connect(_on_login_fail)

	print("Connected! Sending login...")
	NetworkManager.send_login(NetworkManager.pending_username, NetworkManager.pending_password)

func _on_login_success(account_data: Dictionary) -> void:
	print("Authenticated! Notifying server we're ready...")
	NetworkManager.notify_ready_in_world()
	var menu = levels.get_node_or_null("MainMenu")
	if menu:
		menu.queue_free()

func _on_login_fail(reason: String) -> void:
	print("Login failed: ", reason)
	game_started = false
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	var menu = levels.get_node_or_null("MainMenu")
	if menu:
		menu.visible = true

func _ensure_level_spawned() -> void:
	if not multiplayer.multiplayer_peer:
		print(">>> Can't spawn level: no multiplayer peer yet.")
		return

	if not multiplayer.is_server():
		return

	if current_level and is_instance_valid(current_level):
		return

	# If you already placed a level under $Levels in the editor, adopt it.
	for c in levels.get_children():
		if c is Node3D and c.name != "MainMenu":
			_on_level_spawned(c)
			return

	print(">>> Spawning default level...")
	var level_instance := default_level_scene.instantiate()
	level_instance.name = "Level1"
	levels.add_child(level_instance)

	# Server adopts immediately; clients adopt via LevelSpawn.
	_on_level_spawned(level_instance)

func _wait_for_level_ready() -> void:
	if current_level and is_instance_valid(current_level):
		return
	await level_ready

func _on_level_spawned(node: Node) -> void:
	if not (node is Node3D):
		return
	if current_level == node:
		return

	current_level = node
	print(">>> LEVEL READY: ", current_level.name)

	# IMPORTANT: only hide menu if the player actually started the game.
	if game_started:
		_hide_main_menu()

	level_ready.emit(current_level)

func _on_level_despawned(node: Node) -> void:
	if node == current_level:
		current_level = null

func _hide_main_menu() -> void:
	var menu := levels.get_node_or_null("MainMenu")
	if menu:
		menu.visible = false

func _on_player_connected(id: int) -> void:
	print(">>> PEER CONNECTED: ", id)

func _on_player_authenticated(id: int) -> void:
	if multiplayer.is_server():
		await _wait_for_level_ready()
		
		# Tell the current level to spawn this player
		if current_level and current_level.has_method("spawn_player"):
			current_level.spawn_player(id, character_scene)
		else:
			push_error("Current level doesn't have spawn_player method!")

func _on_player_disconnected(id: int) -> void:
	print(">>> PEER DISCONNECTED: ", id)
	
	# Tell the current level to remove this player
	if current_level and current_level.has_method("remove_player"):
		current_level.remove_player(id)
