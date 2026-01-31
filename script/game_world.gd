extends Node3D

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var entities: Node3D = %Entities

var character_scene = preload("res://scenes/characters/character.tscn")
var players: Dictionary = {}  # player_id -> Character node

func _ready() -> void:
	print("=== GAME WORLD READY ===")
	print("Is server: ", multiplayer.is_server())
	
	# Use Godot's built-in multiplayer signals
	if multiplayer.is_server():
		print("Setting up server - connecting to peer signals...")
		multiplayer.peer_connected.connect(_on_player_connected)
		multiplayer.peer_disconnected.connect(_on_player_disconnected)
		print("✓ Server setup complete")
	
	# Connect spawner events (both server and client)
	if spawner:
		spawner.spawned.connect(_on_entity_spawned)
		spawner.despawned.connect(_on_entity_despawned)
		print("✓ Spawner connected")
	else:
		print("✗ ERROR: Spawner is null!")
	
	print("========================")

## SERVER ONLY: Called when a peer connects
func _on_player_connected(id: int) -> void:
	print(">>> PEER CONNECTED: ", id)
	print(">>> Spawning character for player ", id)
	_spawn_player(id)

## SERVER ONLY: Called when a peer disconnects
func _on_player_disconnected(id: int) -> void:
	print(">>> PEER DISCONNECTED: ", id)
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

## SERVER ONLY: Create and spawn character
func _spawn_player(id: int) -> void:
	if players.has(id):
		print("!!! Player ", id, " already spawned, skipping")
		return
	
	print(">>> Creating character instance for ", id)
	var character = character_scene.instantiate()
	character.name = str(id)
	character.player_id = id
	
	# Spawn at random position
	character.global_position = Vector3(
		randf_range(-5, 5),
		2,
		randf_range(-5, 5)
	)
	
	print(">>> Adding character to scene at ", character.global_position)
	entities.add_child(character, true)
	players[id] = character
	print(">>> Character spawned! Total players: ", players.size())

## BOTH: Called when any entity spawns via MultiplayerSpawner
func _on_entity_spawned(node: Node) -> void:
	print("*** Entity spawned: ", node.name, " (Type: ", node.get_class(), ")")
	
	if node is Character:
		var character = node as Character
		print("*** Character player_id: ", character.player_id)
		print("*** My player_id: ", NetworkManager.player_id)
		
		# If this is OUR character, enable camera
		if character.player_id == NetworkManager.player_id:
			print("*** THIS IS MY CHARACTER! Enabling camera")
			

## BOTH: Called when any entity despawns
func _on_entity_despawned(node: Node) -> void:
	print("*** Entity despawned: ", node.name)
