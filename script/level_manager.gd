# res://script/level_manager.gd
extends Node3D

@onready var entities: Node3D = $Entities
@onready var entity_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var MpSync: MultiplayerSynchronizer = $MultiplayerSynchronizer

var players: Dictionary = {}

func _ready() -> void:
	# Connect spawner signals
	NetworkManager.unspawn_player.connect(remove_player)
	entity_spawner.spawned.connect(_on_entity_spawned)
	entity_spawner.despawned.connect(_on_entity_despawned)
	print("[LevelManager] Ready: ", name)

## Server: Spawn a player in this level
func spawn_player(id: int, character_scene: PackedScene) -> void:
	## Error handling:
	if players.has(id):
		print("[LevelManager] Player ", id, " already in level")
		return
	if not multiplayer.is_server():
		return
	if not entities:
		push_error("[LevelManager] No Entities node in level: ", name)
		return
	
	print("[LevelManager] Spawning player ", id)
	
	# Create character
	var character = character_scene.instantiate()
	character.name = str(id)
	character.player_id = id
	
	# Set username from account data
	var account = NetworkManager.get_account_data(id)
	character.username = account.get("username", "")
	
	# Random spawn position
	character.global_position = Vector3(randf_range(-5, 5), 2, randf_range(-5, 5))
	
	# Add to level
	entities.add_child(character, true)
	players[id] = character
	print("[LevelManager] Total players: ", players.size())

## Server: Remove player from this level
func remove_player(id: int) -> void:
	if players.has(id):
		print("[LevelManager] Removing player ", id)
		players[id].queue_free()
		players.erase(id)

func _on_entity_spawned(node: Node) -> void:
	if node is Character:
		var character = node as Character
		if character.player_id == NetworkManager.player_id:
			print("[LevelManager] MY CHARACTER spawned!")

func _on_entity_despawned(node: Node) -> void:
	print("[LevelManager] Entity despawned: ", node.name)
