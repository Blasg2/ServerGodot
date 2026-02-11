# res://script/game_world.gd
# MIGRATED TO NETFOX - Updated visibility management for RollbackSynchronizer
extends Node3D

var character_scene: PackedScene = load("res://scenes/characters/character.tscn")
@onready var menu := $Levels/MainMenu

@onready var Players := %Players
@onready var Levels := %Levels
@onready var Things := %Things
@onready var level_spawner := %LevelSpawn

var loadedLevels: Dictionary = {}
var pending_level_changes: Dictionary = {}

var allLevels := [
	"res://scenes/world/level_1.tscn",
	"res://bola.tscn",
]

var database: String = "res://data/game_data.db"
func _ready() -> void:
	NetworkManager.player_authenticated.connect(_on_player_authenticated)
	NetworkManager.unspawn_player.connect(_on_unspawn_player)
	level_spawner.spawn_function = Callable(self, "spawn_level")

	var args := OS.get_cmdline_args()
	if "--server" in args:
		NetworkManager.start_server()
		for c in allLevels:
			level_spawner.spawn(c)
		for lv in Levels.get_children():
			loadedLevels[lv.name] = lv
			print("[World] Loaded level: ", lv.name)

# ADD THIS BACK
func spawn_level(data: Variant) -> Node:
	var ps: PackedScene = load(data)
	var lv = ps.instantiate()
	return lv

func _load_all_levels() -> void:
	for level_path in allLevels:
		var level_scene = load(level_path)
		var level_instance = level_scene.instantiate()
		Levels.add_child(level_instance, true)
		loadedLevels[level_instance.name] = level_instance
		print("[World] Loaded level: ", level_instance.name)




func start_client_game(username: String, password: String, address: String) -> void:
	NetworkManager.pending_username = username
	NetworkManager.pending_password = password
	NetworkManager.connect_to_server(address)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_connected_to_server() -> void:
	NetworkManager.send_login(
		NetworkManager.pending_username,
		NetworkManager.pending_password
	)
	NetworkManager.login_successful.connect(_on_login_success)

func _on_login_success(_account_data: Dictionary) -> void:
	NetworkManager.notify_ready_in_world()
	menu.queue_free()


func _on_unspawn_player(id: int, username: String) -> void:
	# Find and clean up the player from the level they were on
	for level_name in loadedLevels:
		loadedLevels[level_name].remove_player(id, username)
	
	# Remove the character node
	var character = Players.get_node_or_null(str(id))
	if character:
		character.queue_free()

func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func _on_player_authenticated(id: int) -> void:
	if not multiplayer.is_server():
		return
	
	# Store data but DON'T spawn yet - wait for client time sync + level ready
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

	# Set PlayerInput authority to owning player
	body.get_node("PlayerInput").set_multiplayer_authority(id)

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
	body.velocity = Vector3.ZERO

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
	
	# Make sure client has synced time before spawning
	if not NetworkTime.is_client_synced(id):
		# Wait for sync, then spawn
		await NetworkTime.after_client_sync
	
	if pending_level_changes.has(id):
		var pending = pending_level_changes[id]
		if pending.to_level == levelName:
			_complete_level_change(id, pending)
			pending_level_changes.erase(id)
			return
	_spawn_new_player(id, levelName)
func _complete_level_change(player_id: int, pending: Dictionary) -> void:
	var character = Players.get_node_or_null(str(player_id))
	if not character:
		return

	# Set up visibility
	loadedLevels[pending.to_level].playersOnLevel[player_id] = character
	_setup_visibility(player_id, character, pending.to_level, true, pending.old_peers)

## MIGRATED: Now uses RollbackSynchronizer's visibility_filter
func _setup_visibility(player_id: int, character: Node3D, levelName: String, Isvisible: bool, old_peers: Array[int] = []) -> void:
	var server_sync = character.get_node("ServerSync")
	var peers = _get_peers_on_level(levelName, player_id)

	if Isvisible:
		server_sync.set_visibility_for(1, true)
		server_sync.set_visibility_for(player_id, true)

	for peer_id in peers:
		server_sync.set_visibility_for(peer_id, Isvisible)

		var peer_char = Players.get_node(str(peer_id))
		peer_char.get_node("ServerSync").set_visibility_for(player_id, Isvisible)

	if Isvisible:
		for old_peer_id in old_peers:
			if old_peer_id not in peers:
				server_sync.set_visibility_for(old_peer_id, false)
				
				var old_peer_char = Players.get_node_or_null(str(old_peer_id))
				if old_peer_char:
					old_peer_char.get_node("ServerSync").set_visibility_for(player_id, false)
func _get_peers_on_level(levelName: String, exclude_id: int = -1) -> Array[int]:
	var peers: Array[int] = []
	for c in Players.get_children():
		var id = int(c.name)
		if id != exclude_id and c.get_meta("level") == levelName:
			peers.append(id)
	return peers

func _on_things_child_entered_tree(node: Node) -> void:
	if multiplayer.is_server():
		for c in multiplayer.get_peers():
			node.get_node("MultiplayerSynchronizer").set_visibility_for(c, true)
