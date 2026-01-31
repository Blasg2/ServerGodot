extends Control

@export var clientButton: Button
@export var serverButton: Button

func _ready():
	serverButton.pressed.connect(_on_server_pressed)
	clientButton.pressed.connect(_on_client_pressed)

func _on_server_pressed():
	NetworkManager.start_server()
	get_tree().change_scene_to_file("res://scenes/world/game_world.tscn")

func _on_client_pressed():
	NetworkManager.connect_to_server()
	get_tree().change_scene_to_file("res://scenes/world/game_world.tscn")
