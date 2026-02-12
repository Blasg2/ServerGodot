# res://scenes/UI/main_menu.gd
extends Control

@onready var database := "res://data/game_data.db"

func _ready() -> void:
	NetworkManager.player_authenticated.connect(_on_player_authenticated)
	var args := OS.get_cmdline_args()
	if "--server" in args:
		NetworkManager.start_server()

func _on_client_button_pressed():
	# Get credentials from UI
	var username = $User.text
	var password = $Password.text
	var address = "201.17.248.223"
	
	# Tell game world to start client with these credentials
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
	$"../Network/PlayerSpawner"._spawn(id)
	#var username = NetworkManager.get_account_data(id)["username"]
	#var sql = SQLite.new()
	#sql.path = database
	#sql.verbosity_level = SQLite.QUIET
	#sql.open_db()
	#var rows = sql.select_rows("charStats", "Username = '%s'" % username, ["CurrentLevel"])
	#var level = str(rows[0]["CurrentLevel"])
	#sql.close_db()
	#loadedLevels[level].MpSync.set_visibility_for(id, true)
	
