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
		if player.username == "eve":
			meshPath = "res://Art/PsxChar/gariba.tres"
		if player.username == "alice":
			meshPath = "res://Art/PsxChar/iusaf.tres"
		if player.username == "bob":
			meshPath = "res://Art/PsxChar/joj.tres"
		if player.username == "dave":
			meshPath = "res://Art/PsxChar/lil.tres"
			
