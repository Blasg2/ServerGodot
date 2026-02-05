# res://script/level_manager.gd
extends Node3D

@onready var Game_world := get_node("/root/World")
@onready var MpSync = $MultiplayerSynchronizer

var character_scene: PackedScene = preload("res://scenes/characters/character.tscn")


var players: Dictionary = {}


func _ready() -> void:
	# Connect spawner signals
	if not multiplayer.is_server():
		Game_world.rpc_id(1, "server_level_ready_ack", self.name)

	NetworkManager.unspawn_player.connect(remove_player)
	print("[LevelManager] Ready: ", name)


## Server: Remove player from this level
func remove_player(id: int, username: String) -> void:
	if players.has(id):
		print("[LevelManager] Removing player ", id)
		var p = players[id].global_position
		var sql = SQLite.new()
		sql.path = "res://data/game_data.db"
		sql.open_db()
		sql.query_with_bindings(
			"UPDATE charStats SET CurrentLevel = ?, X = ?, Y = ?, Z = ? WHERE Username = ?;",
			[self.name, p.x, p.y, p.z, username]
		)
		sql.close_db()
		
		players[id].queue_free()
		players.erase(id)
