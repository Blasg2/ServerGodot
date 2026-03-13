extends Node

var sql: SQLite
var player:Dictionary = {}
var playerName:Dictionary = {}

func _ready():
	sql = SQLite.new()
	sql.path = "res://data/game_data.db"
	sql.verbosity_level = SQLite.QUIET
	sql.open_db()

func _exit_tree():
	sql.close_db()

func t(time: float)->void:
	await get_tree().create_timer(time).timeout
