extends Node3D

@onready var player := $".."

var meshPath: String = "":
	set(value):
		meshPath = value
		_apply_mesh()
		

func _apply_mesh()->void:
	$meshy.mesh = load(meshPath)

func _ready() -> void:
	if multiplayer.is_server():
		if player.username == "Gariba":
			meshPath = "res://Art/PsxChar/gariba.tres"
		if player.username == "Iusaf":
			meshPath = "res://Art/PsxChar/iusaf.tres"
		if player.username == "Joj":
			meshPath = "res://Art/PsxChar/joj.tres"
		if player.username == "Lil":
			meshPath = "res://Art/PsxChar/lil.tres"
		if player.username == "Gui":
			meshPath = "res://Art/PsxChar/gotica.tres"
			
