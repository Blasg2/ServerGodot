extends Node

@export var player_scene: PackedScene
@export var MainMenu: Control

@onready var level_spawner := $"../MapSpawn"
@onready var maps := $"../Maps"


var database = "res://data/game_data.db"
var avatars: Dictionary = {}
var _login_flow_started := false

var allLevels = ["res://Maps/level1.tscn", "res://Maps/casa.tscn"]
var loadedLevels = {}
var pending_positions: Dictionary = {}  # {peer_id: Vector3}


signal auth_done(success: bool)

func _ready() -> void:
	NetworkEvents.on_client_start.connect(_handle_client_start)
	NetworkEvents.on_client_stop.connect(_handle_stop)
	NetworkEvents.on_server_stop.connect(_handle_stop)
	NetworkEvents.on_peer_leave.connect(_handle_peer_leave)

	NetworkManager.login_successful.connect(_on_login_success)
	NetworkManager.login_failed.connect(_on_login_fail)
	NetworkManager.player_authenticated.connect(_on_player_authenticated)

	child_entered_tree.connect(_on_child_added)
	
	level_spawner.spawn_function = Callable(self, "spawn_level")
	var args := OS.get_cmdline_args()
	if "--server" in args:
		NetworkManager.start_server()
		for c in allLevels:
			level_spawner.spawn(c)
		for lv in maps.get_children():
			loadedLevels[lv.name] = lv
			##lv.process_mode = Node.PROCESS_MODE_DISABLED
		
func spawn_level(data: Variant)->Node:
	var ps: PackedScene = load(data)
	var lv = ps.instantiate()
	return lv

func _handle_client_start(_id: int) -> void:
	if _login_flow_started:
		return
	_login_flow_started = true
	NetworkManager.send_login(NetworkManager.pending_username, NetworkManager.pending_password)
	var ok: bool = await auth_done
	if not ok:
		return
	NetworkManager.notify_ready_in_world()

func _on_login_success(_account_data: Dictionary) -> void:
	auth_done.emit(true)

func _on_login_fail(reason: String) -> void:
	print("Login failed: ", reason)
	NetworkTime.stop()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_login_flow_started = false
	auth_done.emit(false)

func _handle_stop() -> void:
	_login_flow_started = false
	avatars.clear()

func _handle_peer_leave(id: int) -> void:
	if multiplayer.is_server():
		despawn_player(id)

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
	
@rpc("any_peer", "reliable")
func client_level_ready(levelName: String) -> void:
	if not multiplayer.is_server():
		return
	
	var id := multiplayer.get_remote_sender_id()
	
	if avatars.has(id):
		add_to_level(levelName, id, avatars[id])
		avatars[id].process_mode = Node.PROCESS_MODE_INHERIT
	else:
	# Initial spawn
		spawn_player(id, levelName)
	
func spawn_player(peer_id: int, levelName: String) -> void:
	if not multiplayer.is_server():
		return
	if avatars.has(peer_id):
		return
	var avatar := player_scene.instantiate() as Node
	avatar.name = str(peer_id)
	avatar.username = NetworkManager.get_account_data(peer_id)["username"]
	avatar.set_multiplayer_authority(1)
	avatar.CurrentLevel = levelName  # Store BEFORE add_child
	
	var globalPos: Vector3
	var sql = SQLite.new()
	sql.path = database
	sql.open_db()
	sql.query_with_bindings("SELECT X, Y, Z FROM charStats WHERE Username = ? LIMIT 1;", [avatar.username])
	if sql.query_result.size() > 0:
		var r = sql.query_result[0]
		globalPos = Vector3(float(r["X"]), float(r["Y"]), float(r["Z"]))
	sql.close_db()
	
	add_child(avatar, true)
	avatar.global_position = globalPos
	# REMOVED: add_to_level call — now happens in _on_child_added


func add_to_level(levelName: String, id: int, avatar: CharacterBody3D) -> void:
	avatar.CurrentLevel = levelName
	if pending_positions.has(id):
		avatar.server_teleport(pending_positions[id])
		pending_positions.erase(id)
	
	loadedLevels[levelName].playersOnLevel[id] = avatar
	# Loop 1: existing players send state TO new player
	for p in loadedLevels[levelName].playersOnLevel.values():
		p.MpSync.set_visibility_for(id, true)
		p.state_sync.visibility_filter.set_visibility_for(id, true)
		p.state_sync.visibility_filter.update_visibility()
	# Loop 2: new player sends state TO existing players
	for p in loadedLevels[levelName].playersOnLevel:
		if p != id:
			avatar.MpSync.set_visibility_for(p, true)
			avatar.state_sync.visibility_filter.set_visibility_for(p, true)
	avatar.state_sync.visibility_filter.update_visibility()

func remove_from_level(id: int, avatar: CharacterBody3D) -> void:
	for p in loadedLevels[avatar.CurrentLevel].playersOnLevel.values():
		p.state_sync.visibility_filter.set_visibility_for(id, false)
		p.state_sync.visibility_filter.update_visibility()
		p.MpSync.set_visibility_for(id, false)
	for p in loadedLevels[avatar.CurrentLevel].playersOnLevel:
		if p != id:
			avatar.state_sync.visibility_filter.set_visibility_for(p, false)
			avatar.MpSync.set_visibility_for(p, false)
	avatar.state_sync.visibility_filter.update_visibility()
	loadedLevels[avatar.CurrentLevel].playersOnLevel.erase(id)
	
	
@rpc("any_peer", "reliable")
func change_level(NextLevel: String, pos: Vector3)->void:
	var id = multiplayer.get_remote_sender_id()
	var avatar = avatars[id]
	remove_from_level(id, avatar)
	avatar.process_mode = Node.PROCESS_MODE_DISABLED
	loadedLevels[avatar.CurrentLevel].MpSync.set_visibility_for(id, false)
	pending_positions[id] = pos
	loadedLevels[NextLevel].MpSync.set_visibility_for(id, true)





func despawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if avatars.has(peer_id):
		var avatar = avatars[peer_id]
		loadedLevels[avatar.CurrentLevel].playersOnLevel.erase(peer_id)
		if is_instance_valid(avatar):
			var p = avatar.global_position
			var sql = SQLite.new()
			sql.path = "res://data/game_data.db"
			sql.open_db()
			sql.query_with_bindings(
				"UPDATE charStats SET CurrentLevel = ?, X = ?, Y = ?, Z = ? WHERE Username = ?;",
				[avatar.CurrentLevel, p.x, p.y, p.z, avatar.username]
			)
			sql.close_db()
			avatar.queue_free()
		avatars.erase(peer_id)
		

##Runs on enter_tree
func _on_child_added(node: Node) -> void:
	if not node is CharacterBody3D:
		return
	var peer_id := node.name.to_int()
	if peer_id == 0:
		return
	avatars[peer_id] = node

	var input := node.find_child("Input")
	if input != null:
		input.set_multiplayer_authority(peer_id)
		await get_tree().process_frame
		var state_sync = node.find_child("StateSynchronizer")
		if state_sync != null:
			state_sync.process_settings()
			state_sync.visibility_filter.default_visibility = false
			if multiplayer.is_server() and node.CurrentLevel != "":
				add_to_level(node.CurrentLevel, peer_id, node)

	if peer_id == multiplayer.get_unique_id():
		if is_instance_valid(MainMenu):
			MainMenu.queue_free()
