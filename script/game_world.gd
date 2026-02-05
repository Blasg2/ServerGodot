# res://script/game_world.gd
extends Node3D

@onready var levels: Node3D = $Levels
@onready var level_spawner: MultiplayerSpawner = $LevelSpawn
@onready var menu := $Levels/MainMenu
@onready var database := "res://data/game_data.db"
@onready var Players := $Players
@onready var Things := $Things

var character_scene: PackedScene = load("res://scenes/characters/character.tscn")

var loadedLevels = {}
var allLevels := ["res://scenes/world/level_1.tscn"]

func _ready() -> void:	
	# Connect network signals
	NetworkManager.player_authenticated.connect(_on_player_authenticated)
	# Watch for level spawns
	level_spawner.despawned.connect(_on_level_despawned)
	

# Only server actually instances/adds the levels
	var args := OS.get_cmdline_args()
	if "--server" in args:
		NetworkManager.start_server()

		for c in allLevels:
			var ps:PackedScene = load(c)
			var lv := ps.instantiate()
			#lv.name = l["name"]
			#lv.process_mode = Node.PROCESS_MODE_DISABLED
			levels.add_child(lv)
			loadedLevels[lv.name] = lv
	
	
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
	NetworkManager.notify_ready_in_world()
	
	# Clean up menu after successful login
	menu.queue_free()

func _on_login_fail(reason: String) -> void:
	print("❌ Login failed: ", reason)
	
	# Disconnect
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	
func _on_level_despawned(node: Node) -> void:
	pass ## later addlogic here to despawn levels. NOTE NOTE NOTE NOTE




##SPAWN ON LEVEL
func _on_player_authenticated(id: int) -> void:
	if multiplayer.is_server():
		var username = NetworkManager.get_account_data(id)["username"]
		var sql = SQLite.new()
		sql.path = database
		sql.verbosity_level = SQLite.QUIET
		sql.open_db()
		var rows = sql.select_rows("charStats","Username = '%s'" % username,["CurrentLevel"]) 
		var level = str(rows[0]["CurrentLevel"])
		sql.close_db()
		
		loadedLevels[level].MpSync.set_visibility_for(id,true)
		
@rpc("any_peer", "reliable")
func server_level_ready_ack(levelName: String) -> void:
	if not multiplayer.is_server():
		return

	var id := multiplayer.get_remote_sender_id()

	# --- build server-side character node (server copy) ---
	var character = character_scene.instantiate()
	character.name = str(id)
	character.player_id = id
	character.set_meta("level", levelName)

	var account = NetworkManager.get_account_data(id)
	character.username = account.get("username", "")
	#character.get_node("MultiplayerSynchronizer").set_multiplayer_authority(id, true)

	Players.add_child(character, true)


	# --- SQL load position ---
	var username = account.get("username", "")
	var pos := Vector3.ZERO

	var sql = SQLite.new()
	sql.path = database
	sql.open_db()
	sql.query_with_bindings(
		"SELECT X, Y, Z FROM charStats WHERE Username = ? LIMIT 1;",
		[username]
	)
	if sql.query_result.size() > 0:
		var r = sql.query_result[0]
		pos = Vector3(float(r["X"]), float(r["Y"]), float(r["Z"]))
	sql.close_db()
	
	character.global_position = pos

	$Controls.show()
	for c in Players.get_children():
		c.serverSync.set_visibility_for(id,true)

	#await get_tree().create_timer(3).timeout
	#var bol = load("res://bola.tscn")
	#var bola = bol.instantiate()
	#bola.global_position = Vector3(0,0,0)
	#Things.add_child(bola, true)

	loadedLevels[levelName].players[id] = character


func _on_things_child_entered_tree(node: Node) -> void:
	if multiplayer.is_server():
		for c in multiplayer.get_peers():
			node.get_node("MultiplayerSynchronizer").set_visibility_for(c,true)
			
