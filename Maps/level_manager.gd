extends Node

@onready var MpSync := $MultiplayerSynchronizer
@onready var playerSpawn := get_node("/root/World/Players")

var playersOnLevel: Dictionary = {}

func _ready() -> void:
	if not multiplayer.is_server():
		playerSpawn.rpc_id(1, "client_level_ready", self.name)
