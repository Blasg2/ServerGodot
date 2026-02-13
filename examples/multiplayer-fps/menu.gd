extends Control

func _ready() -> void:
	NetworkManager.player_authenticated.connect(_on_player_authenticated)
	NetworkManager.unspawn_player.connect(_on_player_disconnected)
	var args := OS.get_cmdline_args()
	if "--server" in args:
		NetworkManager.start_server()


func _on_client_button_pressed():
	var username = $User.text
	var password = $Password.text
	var address = "201.17.248.223"
	start_client_game(username, password, address)


func _on_user_text_submitted(_new_text):
	_on_client_button_pressed()

func _on_password_text_submitted(_new_text):
	_on_client_button_pressed()


func start_client_game(username: String, password: String, address: String = "localhost") -> void:
	NetworkManager.pending_username = username
	NetworkManager.pending_password = password
	NetworkManager.connect_to_server(address)


func _on_player_authenticated(id: int) -> void:
	if not multiplayer.is_server():
		return
	# Server spawns → MultiplayerSpawner replicates to everyone automatically
	$"../Network/PlayerSpawner".spawn_player(id)


func _on_player_disconnected(id: int, _username: String) -> void:
	if not multiplayer.is_server():
		return
	$"../Network/PlayerSpawner".despawn_player(id)
