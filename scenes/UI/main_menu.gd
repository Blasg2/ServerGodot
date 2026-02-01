extends Control

@export var clientButton: Button
@export var serverButton: Button

var username: String
var password: String

func _ready():
	serverButton.pressed.connect(_on_server_pressed)
	clientButton.pressed.connect(_on_client_pressed)
	
	NetworkManager.login_successful.connect(_on_login_successful)
	NetworkManager.login_failed.connect(_on_login_failed)

func _on_server_pressed():
	NetworkManager.start_server()
	get_tree().change_scene_to_file("res://scenes/world/game_world.tscn")

func _on_client_pressed():
	username = $User.text     
	password = $Password.text  
	
	NetworkManager.connect_to_server()
	await multiplayer.connected_to_server
	print("Connected, sending login...")
	NetworkManager.send_login(username, password)

func _on_login_successful(account_data: Dictionary):
	print("✓ Authenticated! NOW changing scene...")
	get_tree().change_scene_to_file("res://scenes/world/game_world.tscn")

func _on_login_failed(reason: String):
	print("❌ Login failed: ", reason)
