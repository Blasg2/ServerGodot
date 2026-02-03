# res://script/level_manager.gd
extends Node3D

@onready var entities: Node3D = $Entities
@onready var entity_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var MpSync: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var Game_world := get_node("/root/World")


var players: Dictionary = {}
var thingsToSync: Array = []

func _ready() -> void:
	# Connect spawner signals
	if not multiplayer.is_server():
		Game_world.rpc_id(1, "server_level_ready_ack", self.name)

	NetworkManager.unspawn_player.connect(remove_player)
	entity_spawner.spawned.connect(_on_entity_spawned)
	entity_spawner.despawned.connect(_on_entity_despawned)
	print("[LevelManager] Ready: ", name)

## Server: Spawn a player in this level
func spawn_player(id: int, character_scene: PackedScene) -> void:
	if players.has(id) or not multiplayer.is_server():
		return
	print("[LevelManager] Spawning player ", id)
	
	# Create character	
	var character = character_scene.instantiate()
	character.name = str(id)
	character.player_id = id
	
	# Set username from account data
	var account = NetworkManager.get_account_data(id)
	character.username = account.get("username", "")
	
	# Add to level
	#character.set_multiplayer_authority(id)
	character.global_position = Vector3(randf_range(-5, 5), 2, randf_range(-5, 5))
	entities.add_child(character, true)
	
	# Loop syncs
	#for sync in thingsToSync:
		#sync.set_visibility_for(id, true)
		#
		
	players[id] = character
	print("[LevelManager] Total players: ", players.size())
	
## Server: Remove player from this level
func remove_player(id: int) -> void:
	if players.has(id):
		print("[LevelManager] Removing player ", id)
		players[id].queue_free()
		players.erase(id)

func _on_entity_spawned(node: Node) -> void:
	pass
func _on_entity_despawned(node: Node) -> void:
	print("[LevelManager] Entity despawned: ", node.name)
