# res://scenes/UI/main_menu.gd
extends Control

@onready var world := $"../.."

func _on_client_button_pressed():
	# Get credentials from UI
	var username = $User.text
	var password = $Password.text
	var address = "localhost"
	
	# Tell game world to start client with these credentials
	world.start_client_game(username, password, address)
	

func _on_user_text_submitted(_new_text):
	_on_client_button_pressed()

func _on_password_text_submitted(_new_text):
	_on_client_button_pressed()
