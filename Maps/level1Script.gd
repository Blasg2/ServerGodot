extends Node

var Wchat: String

func _ready() -> void:
	if multiplayer.is_server():
		Wchat = FileAccess.get_file_as_string("res://data/ZapChat.txt") + FileAccess.get_file_as_string("res://data/ZapGui.txt")
		
		$"../ChatSprite/SubViewport/Chat".text = pegar_parte_do_chat(Wchat)
		$"../Esfera".talk($"../ChatSprite/SubViewport/Chat".text)

@rpc ("any_peer", "reliable")
func refreshChat()->void:
	if multiplayer.is_server():
		$"../ChatSprite/SubViewport/Chat".text = pegar_parte_do_chat(Wchat)
		$"../Esfera".talk($"../ChatSprite/SubViewport/Chat".text)

func pegar_parte_do_chat(chat: String) -> String:
	var lines := chat.split("\n", false)
	if lines.is_empty():
		return ""

	var filtered := PackedStringArray()
	for i in range(lines.size()):
		var s := lines[i].strip_edges()

		# Skip media placeholder
		if s.find("Multimedia omitido") != -1 or s.find("Mídia oculta") != -1:
			continue

		# Remove "date, time - " prefix if present
		var dash := s.find(" - ")
		if dash != -1:
			s = s.substr(dash + 3)

		# Also handle "[..] Name: msg" style (optional)
		if s.begins_with("["):
			var close := s.find("] ")
			if close != -1:
				s = s.substr(close + 2)

		if s.is_empty():
			continue
		filtered.append(s)

	lines = filtered
	if lines.is_empty():
		return ""

	var n := 15
	if lines.size() <= n:
		return "\n".join(lines)

	var start := randi_range(0, lines.size() - n)
	return "\n".join(lines.slice(start, start + n))
