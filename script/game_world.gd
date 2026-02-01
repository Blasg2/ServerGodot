extends Node3D

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var entities: Node3D = %Entities

var character_scene = preload("res://scenes/characters/character.tscn")
var players: Dictionary = {}

func _ready() -> void:
	print("=== GAME WORLD READY ===")
	print("Is server: ", multiplayer.is_server())
	
	if multiplayer.is_server():
		print("Setting up server...")
		multiplayer.peer_connected.connect(_on_player_connected)
		multiplayer.peer_disconnected.connect(_on_player_disconnected)
		NetworkManager.player_authenticated.connect(_on_player_authenticated)
		print("✓ Server setup complete")
	
	if spawner:
		spawner.spawned.connect(_on_entity_spawned)
		spawner.despawned.connect(_on_entity_despawned)
		print("✓ Spawner connected")
	
	print("========================")

func _on_player_connected(id: int) -> void:
	print(">>> PEER CONNECTED: ", id)
	
	if NetworkManager.authenticated_players.has(id):
		print(">>> Already authenticated, spawning")
		_spawn_player(id)
	else:
		print(">>> Not authenticated yet, waiting...")

func _on_player_authenticated(id: int) -> void:
	print(">>> PLAYER AUTHENTICATED: ", id)
	# Spawn if not already spawned
	_spawn_player(id)

func _on_player_disconnected(id: int) -> void:
	print(">>> PEER DISCONNECTED: ", id)
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

func _spawn_player(id: int) -> void:
	if players.has(id):
		return
	
	print(">>> Creating character for ", id)
	var character = character_scene.instantiate()
	character.name = str(id)
	character.player_id = id
	character.global_position = Vector3(randf_range(-5, 5), 2, randf_range(-5, 5))
	
	entities.add_child(character, true)
	players[id] = character
	print(">>> Spawned! Total: ", players.size())

func _on_entity_spawned(node: Node) -> void:
	if node is Character:
		var character = node as Character
		if character.player_id == NetworkManager.player_id:
			print("*** MY CHARACTER!")

func _on_entity_despawned(node: Node) -> void:
	print("*** Despawned: ", node.name)
