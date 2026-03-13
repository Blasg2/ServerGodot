extends Node



##MUDAR CHAT
func _on_mudar_chat_body_entered(body: Node3D) -> void:
	if body.get_node("HUD") != null:
		var hud = body.get_node("HUD")
		hud.action.text = "Mudar chat"
		hud.action.show()
		hud.action1.connect(chatRefresh)
	
func _on_mudar_chat_body_exited(body: Node3D) -> void:
	if body.get_node("HUD") != null:
		var hud = body.get_node("HUD")
		hud.action.hide()
		hud.action1.disconnect(chatRefresh)

func chatRefresh()->void:
	$"../LevelScript".refreshChat.rpc_id(1)


##ACENDER LUZ
func _on_ligar_luz_body_entered(body: Node3D) -> void:
	if body.get_node("HUD") != null:
		var hud = body.get_node("HUD")
		hud.action.text = "Interruptor"
		hud.action.show()
		hud.action1.connect(acenderLuz)

func _on_ligar_luz_body_exited(body: Node3D) -> void:
	if body.get_node("HUD") != null:
		var hud = body.get_node("HUD")
		hud.action.hide()
		hud.action1.disconnect(acenderLuz)

func acenderLuz()->void:
	lampada.rpc_id(1)
	
@rpc ("any_peer", "reliable")
func lampada()->void:
	if multiplayer.is_server():
		if $"../OmniLight3D".light_energy != 0:
			$"../OmniLight3D".light_energy = 0
		else:
			$"../OmniLight3D".light_energy = 16
		
		
	
	
	
	
	
	
	
	
	
