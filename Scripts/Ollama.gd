# res://script/OllamaClient.gd
extends Node
class_name OllamaClient

@export var base_url := "http://127.0.0.1:11434"
@export var model := "llama3.1:8b"

# SERVER-ONLY async call
# Calls on_done(text) when ready, on_error(msg) on failure
func chat(prompt: String, on_done: Callable, on_error: Callable = Callable()) -> void:
	# Make sure only the server uses Ollama (prevents client abuse + keeps API local)
	if multiplayer and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		if on_error.is_valid():
			on_error.call("Ollama is server-only")
		return

	var req := HTTPRequest.new()
	add_child(req)

	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		req.queue_free()

		if result != HTTPRequest.RESULT_SUCCESS:
			if on_error.is_valid(): on_error.call("HTTPRequest failed result=%s" % result)
			return
		if code < 200 or code >= 300:
			if on_error.is_valid(): on_error.call("HTTP %d: %s" % [code, body.get_string_from_utf8()])
			return

		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) != TYPE_DICTIONARY:
			if on_error.is_valid(): on_error.call("Bad JSON: " + body.get_string_from_utf8())
			return

		# Ollama /api/chat returns {"message":{"role":"assistant","content":"..."}, ...}
		var msg = parsed.get("message", {})
		var content := str(msg.get("content", ""))
		on_done.call(content)
	)

	var payload := {
		"model": model,
		"stream": false,
		"messages": [
			{"role": "user", "content": prompt}
		]
	}

	var err := req.request(
		base_url + "/api/chat",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		req.queue_free()
		if on_error.is_valid(): on_error.call("request() err=%s" % err)
