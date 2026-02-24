extends MeshInstance3D

@export var npc_name := "Chelala"
@export var personality := "You have a dark humor. Comment on the web-chat and the people who sent the messages in a funny way. Reply in pt-BR. (4-9 sentences)."

# This version makes CLIENT ask SERVER, and SERVER calls Ollama, then replies back to that CLIENT.

func talk(player_text: String) -> void:
	if multiplayer and multiplayer.has_multiplayer_peer():
		# ✅ If we are the server, just call Ollama directly
		if multiplayer.is_server():
			_call_ollama_local(player_text)
			return

		# CLIENT: ask server
		rpc_id(1, "_server_npc_talk", npc_name, personality, player_text)
		_show_dialogue("%s: Pensando..." % npc_name)
	else:
		_call_ollama_local(player_text)

func _call_ollama_local(player_text: String) -> void:
	var prompt := "%s\nNPC name: %s\nPlayer says: %s\nNPC reply:" % [personality, npc_name, player_text]
	_show_dialogue("%s: Pensando..." % npc_name)
	Ollama.chat(
		prompt,
		func(answer: String):
			_show_dialogue("%s: %s" % [npc_name, answer.strip_edges()]),
		func(err: String):
			_show_dialogue("%s: (Não consigo pensar em nada no momento: %s)" % [npc_name, err])
	)

# SERVER: receives the request, calls Ollama, returns the answer to the requesting peer
@rpc("any_peer", "reliable")
func _server_npc_talk(_npc_name: String, _personality: String, player_text: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()

	var prompt := "%s\nNPC name: %s\nPlayer says: %s\nNPC reply:" % [_personality, _npc_name, player_text]

	Ollama.chat(
		prompt,
		func(answer: String):
			rpc_id(sender_id, "_client_npc_reply", _npc_name, answer),
		func(err: String):
			rpc_id(sender_id, "_client_npc_reply", _npc_name, "(error: %s)" % err)
	)

# CLIENT: receives the NPC reply and shows it
@rpc("authority", "reliable")
func _client_npc_reply(_npc_name: String, answer: String) -> void:
	_show_dialogue("%s: %s" % [_npc_name, answer.strip_edges()])

func _show_dialogue(texte: String) -> void:
	print(texte)
