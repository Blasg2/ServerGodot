extends LineEdit

@export var npc_name := "Bob"
@export var personality := "You are a friendly NPC in a game. Reply in pt-BR. Keep it short (1-2 sentences)."

# This version makes CLIENT ask SERVER, and SERVER calls Ollama, then replies back to that CLIENT.

func talk(player_text: String) -> void:
	# CLIENT: ask server to generate NPC reply
	if multiplayer and multiplayer.has_multiplayer_peer():
		rpc_id(1, "_server_npc_talk", npc_name, personality, player_text)
		_show_dialogue("%s: Pensando..." % npc_name) # optional thinking
	else:
		# SINGLEPLAYER / no multiplayer peer: call locally
		_call_ollama_local(player_text)

func _call_ollama_local(player_text: String) -> void:
	var prompt := "%s\nNPC name: %s\nPlayer says: %s\nNPC reply:" % [personality, npc_name, player_text]
	_show_dialogue("%s: ..." % npc_name)
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
	$"../AutoSizeRichTextLabel".text = texte

func _on_text_submitted(new_text: String) -> void:
	talk(new_text)
	text = ""
	call_deferred("edit")
