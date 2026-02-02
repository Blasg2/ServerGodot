# res://script/game_world.gd
extends Node3D

## Fired when a playable level is present under $Levels
signal level_ready(level: Node3D)

@onready var levels: Node3D = $Levels
@onready var level_spawner: MultiplayerSpawner = $LevelSpawn
@onready var menu := $Levels/MainMenu
@onready var database := "res://data/game_data.db"

var loadedLevels = {}

var current_level: Node3D
var character_scene: PackedScene = load("uid://t04xmkgtd7i8")
var level1: PackedScene = load("uid://uaj1iyaf1711")


func _ready() -> void:	
	# Connect network signals
	NetworkManager.player_authenticated.connect(_on_player_authenticated)
	# Watch for level spawns
	level_spawner.despawned.connect(_on_level_despawned)
	
	# Command line auto-start
	var args := OS.get_cmdline_args()
	if "--server" in args:
		NetworkManager.start_server()
		var sql = SQLite.new()
		sql.path = database
		sql.open_db()
		var allLevels = sql.select_rows("levels", "", ["name", "path"])
		sql.close_db()
	
		for l in allLevels:
			level_spawner.add_spawnable_scene(l["path"])
			var ll = load(l["path"])
			var lv = ll.instantiate()
			lv.name = l["name"]
			#lv.process_mode = Node.PROCESS_MODE_DISABLED
			levels.add_child(lv)
			loadedLevels[l["name"]] = lv
	
	
## Called by MainMenu - Join as client
func start_client_game(username: String, password: String, address: String = "localhost") -> void:
	
	NetworkManager.pending_username = username
	NetworkManager.pending_password = password
	NetworkManager.connect_to_server(address)
	_handle_client_authentication()

func _handle_client_authentication() -> void:
	# Wait for connection
	if not multiplayer.multiplayer_peer or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		await multiplayer.connected_to_server
	
	# Connect auth signals
	if not NetworkManager.login_successful.is_connected(_on_login_success):
		NetworkManager.login_successful.connect(_on_login_success)
	if not NetworkManager.login_failed.is_connected(_on_login_fail):
		NetworkManager.login_failed.connect(_on_login_fail)
	
	# Send login
	NetworkManager.send_login(NetworkManager.pending_username, NetworkManager.pending_password)

func _on_login_success(account_data: Dictionary) -> void:
	print("✓ Authenticated! Notifying server...")
	NetworkManager.notify_ready_in_world()
	
	# Clean up menu after successful login
	menu.queue_free()

func _on_login_fail(reason: String) -> void:
	print("❌ Login failed: ", reason)
	
	# Disconnect
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


## Server: Ensure a level is spawned
func _ensure_level_spawned() -> void:
	
	level_ready.emit(current_level)
	
func _wait_for_level_ready() -> void:
	while not is_instance_valid(current_level):
		await get_tree().process_frame

	
func _on_level_despawned(node: Node) -> void:
	if node == current_level:
		current_level = null


func _on_player_authenticated(id: int) -> void:
	if multiplayer.is_server():
		print(loadedLevels)
		current_level = loadedLevels["level1"]
		current_level.MpSync.set_visibility_for(id,true)
		
		await _wait_for_level_ready()	
		await get_tree().create_timer(2).timeout
		# Tell level to spawn this player
		current_level.spawn_player(id, character_scene)
