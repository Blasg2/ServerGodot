extends Control

func _on_client_button_pressed():
	var username = $User.text
	var password = $Password.text
	NetworkManager.pending_username = username
	NetworkManager.pending_password = password
	NetworkManager.connect_to_server("201.17.248.223")

func _on_user_text_submitted(_new_text):
	_on_client_button_pressed()

func _on_password_text_submitted(_new_text):
	_on_client_button_pressed()
