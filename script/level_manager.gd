# res://script/level_manager.gd
extends Node3D

@onready var Game_world := get_node("/root/World")
@onready var MpSync = $MultiplayerSynchronizer

var playersOnLevel: Dictionary = {}


func _ready() -> void:
	if not multiplayer.is_server():
		Game_world.rpc_id(1, "client_level_ready", self.name)
	NetworkManager.unspawn_player.connect(remove_player)
	
	
	#if not multiplayer.is_server():
		#Game_world.level_spawner.clear_spawnable_scenes()
		#for c in Game_world.allLevels:
			#Game_world.level_spawner.add_spawnable_scene(c)

## Server: Remove player from this level
func remove_player(id: int, username: String) -> void:
	if playersOnLevel.has(id):
		print("[LevelManager] Removing player ", id)
		var body = playersOnLevel[id].get_node("Body")
		var p = body.global_position
		var sql = SQLite.new()
		sql.path = "res://data/game_data.db"
		sql.open_db()
		sql.query_with_bindings(
			"UPDATE charStats SET CurrentLevel = ?, X = ?, Y = ?, Z = ? WHERE Username = ?;",
			[self.name, p.x, p.y, p.z, username]
		)
		sql.close_db()
		
		playersOnLevel[id].queue_free()
		playersOnLevel.erase(id)
		
