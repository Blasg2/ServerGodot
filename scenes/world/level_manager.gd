# res://scripts/LevelManager.gd
extends Node3D

@onready var entities: Node3D = $Entities
@onready var entity_spawner: MultiplayerSpawner = $MultiplayerSpawner

var players: Dictionary = {}

func _ready() -> void:
	if entity_spawner:
		entity_spawner.spawned.connect(_on_entity_spawned)
		entity_spawner.despawned.connect(_on_entity_despawned)
		print("[LevelManager] Spawner connected for level: ", name)

func spawn_player(id: int, character_scene: PackedScene) -> void:
	if players.has(id):
		print("[LevelManager] Player ", id, " already spawned in this level")
		return
	
	if not multiplayer.is_server():
		print("[LevelManager] Only server can spawn players")
		return
	
	if not entities:
		push_error("[LevelManager] No Entities node found in level: ", name)
		return
	
	print("[LevelManager] Spawning player ", id, " in level: ", name)
	var character = character_scene.instantiate()
	character.name = str(id)
	character.player_id = id
	character.global_position = Vector3(randf_range(-5, 5), 2, randf_range(-5, 5))
	
	entities.add_child(character, true)
	players[id] = character
	print("[LevelManager] Player spawned! Total in this level: ", players.size())

func remove_player(id: int) -> void:
	if players.has(id):
		print("[LevelManager] Removing player ", id, " from level: ", name)
		players[id].queue_free()
		players.erase(id)

func _on_entity_spawned(node: Node) -> void:
	if node is Character:
		var character = node as Character
		if character.player_id == NetworkManager.player_id:
			print("[LevelManager] MY CHARACTER spawned in level: ", name)

func _on_entity_despawned(node: Node) -> void:
	print("[LevelManager] Entity despawned: ", node.name)
