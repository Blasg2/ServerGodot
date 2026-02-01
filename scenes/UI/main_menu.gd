extends Control

@export var clientButton: Button
@export var serverButton: Button

func _ready():
	serverButton.pressed.connect(_on_server_pressed)
	clientButton.pressed.connect(_on_client_pressed)

func _on_server_pressed():
	NetworkManager.start_server()

	var world = get_tree().current_scene
	if world and world.has_method("start_host_game"):
		world.start_host_game()

	queue_free()

func _on_client_pressed():
	var username = $User.text
	var password = $Password.text
	var address = "localhost" # TODO: replace with an Address LineEdit if you add one

	var world = get_tree().current_scene
	if world and world.has_method("start_client_game"):
		world.start_client_game(username, password, address)

	visible = false  # Hide instead of delete
