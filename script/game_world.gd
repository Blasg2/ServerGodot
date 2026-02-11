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
var allLevels := ["res://scenes/world/level_1.tscn", "res://bola.tscn"]

var pending_level_changes: Dictionary = {}

func _ready() -> void:
	NetworkManager.player_authenticated.connect(_on_player_authenticated)
	level_spawner.spawn_function = Callable(self, "spawn_level")

# Only server actually instances/adds the levels
	var args := OS.get_cmdline_args()
	if "--server" in args:
		NetworkManager.start_server()
		for c in allLevels:
			level_spawner.spawn(c)
		for lv in levels.get_children():
			loadedLevels[lv.name] = lv
			##lv.process_mode = Node.PROCESS_MODE_DISABLED

func spawn_level(data: Variant)->Node:
	var ps: PackedScene = load(data)
	var lv = ps.instantiate()
	return lv
	
	
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

	


func _on_player_authenticated(id: int) -> void:
	if not multiplayer.is_server():
		return
	var username = NetworkManager.get_account_data(id)["username"]
	var sql = SQLite.new()
	sql.path = database
	sql.verbosity_level = SQLite.QUIET
	sql.open_db()
	var rows = sql.select_rows("charStats", "Username = '%s'" % username, ["CurrentLevel"])
	var level = str(rows[0]["CurrentLevel"])
	sql.close_db()
	loadedLevels[level].MpSync.set_visibility_for(id, true)

func _spawn_new_player(id: int, levelName: String) -> void:
	var account = NetworkManager.get_account_data(id)
	var username = account.get("username", "")

	# Create character
	var character = character_scene.instantiate()
	character.name = str(id)
	character.set_meta("level", levelName)

	var body = character.get_node("Body")
	body.username = username
	
	Players.add_child(character, true)

	# Load position from DB
	var sql = SQLite.new()
	sql.path = database
	sql.open_db()
	sql.query_with_bindings("SELECT X, Y, Z FROM charStats WHERE Username = ? LIMIT 1;", [username])
	if sql.query_result.size() > 0:
		var r = sql.query_result[0]
		body.global_position = Vector3(float(r["X"]), float(r["Y"]), float(r["Z"]))
	sql.close_db()
	
	loadedLevels[levelName].playersOnLevel[id] = character
	_setup_visibility(id, character, levelName, true)

@rpc("any_peer", "reliable")
func change_player_level(player_id: int, to_level: String) -> void:
	var character = Players.get_node_or_null(str(player_id))
	if not character:
		return
	var from_level = character.get_meta("level")
	if from_level == to_level:
		return
	
	var old_peers = _get_peers_on_level(from_level, player_id)
	var body = character.get_node("Body")
	
	# Freeze character during transition
	body.set_physics_process(false)
	body.velocity = Vector3.ZERO
	#body.global_position = spawn_pos
	
	# Remove from old level
	_setup_visibility(player_id, character, from_level, false)
	loadedLevels[from_level].MpSync.set_visibility_for(player_id, false)
	loadedLevels[from_level].playersOnLevel.erase(player_id)
	
	# Store pending - wait for handshake to complete
	pending_level_changes[player_id] = {
		"to_level": to_level,
		"old_peers": old_peers
	}
	
	# Show new level (client starts loading)
	character.set_meta("level", to_level)
	loadedLevels[to_level].MpSync.set_visibility_for(player_id, true)


@rpc("any_peer", "reliable")
func client_level_ready(levelName: String) -> void:
	if not multiplayer.is_server():
		return
	
	var id := multiplayer.get_remote_sender_id()
	
	if pending_level_changes.has(id):
		var pending = pending_level_changes[id]
		if pending.to_level == levelName:
			_complete_level_change(id, pending)
			pending_level_changes.erase(id)
			return
	
	# Initial spawn
	_spawn_new_player(id, levelName)


func _complete_level_change(player_id: int, pending: Dictionary) -> void:
	var character = Players.get_node_or_null(str(player_id))
	if not character:
		return
	
	var body = character.get_node("Body")
	
	# Unfreeze
	body.set_physics_process(true)
	
	# Set up visibility
	loadedLevels[pending.to_level].playersOnLevel[player_id] = character
	_setup_visibility(player_id, character, pending.to_level, true, pending.old_peers)


func _setup_visibility(player_id: int, character: Node3D, levelName: String, Isvisible: bool, old_peers: Array[int] = []) -> void:
	var server_sync = character.get_node("ServerSync")
	var peers = _get_peers_on_level(levelName, player_id)
	
	if Isvisible:
		server_sync.set_visibility_for(1, true)
		server_sync.set_visibility_for(player_id, true)
	
	for peer_id in peers:
		server_sync.set_visibility_for(peer_id, Isvisible)
		Players.get_node(str(peer_id)).get_node("ServerSync").set_visibility_for(player_id, Isvisible)
		_update_statesync.rpc_id(peer_id, player_id, Isvisible)
	
	if Isvisible:
		_set_statesync_peers.rpc_id(player_id, peers, old_peers)


func _get_peers_on_level(levelName: String, exclude_id: int = -1) -> Array[int]:
	var peers: Array[int] = []
	for c in Players.get_children():
		var id = int(c.name)
		if id != exclude_id and c.get_meta("level") == levelName:
			peers.append(id)
	return peers


@rpc("authority", "reliable")
func _update_statesync(peer_id: int, Isvisible: bool) -> void:
	for c in Players.get_children():
		var body = c.get_node("Body")
		if body.get_multiplayer_authority() == multiplayer.get_unique_id():
			body.get_node("StateSync").set_visibility_for(peer_id, Isvisible)


@rpc("authority", "reliable")
func _set_statesync_peers(peer_ids: Array, old_peer_ids: Array = []) -> void:
	for c in Players.get_children():
		var body = c.get_node("Body")
		if body.get_multiplayer_authority() == multiplayer.get_unique_id():
			body.get_node("StateSync").set_visibility_for(1, true)
			
			# Remove old peers
			for peer_id in old_peer_ids:
				body.get_node("StateSync").set_visibility_for(peer_id, false)
			
			# Add new peers
			for peer_id in peer_ids:
				body.get_node("StateSync").set_visibility_for(peer_id, true)



##THIS nedds CHANGE NOTE NOTE NOTE
func _on_things_child_entered_tree(node: Node) -> void:
	if multiplayer.is_server():
		for c in multiplayer.get_peers():
			node.get_node("MultiplayerSynchronizer").set_visibility_for(c, true)


			
	#await get_tree().create_timer(3).timeout
	#var bol = load("res://bola.tscn")
	#var bola = bol.instantiate()
	#bola.global_position = Vector3(0,0,0)
	#Things.add_child(bola, true)
