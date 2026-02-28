extends Node

var render_scale: float = 1.0
var max_fps: int = 60

const PATH := "user://settings.cfg"

func _ready():
	load_settings()
	_apply()


func save_settings():
	var config := ConfigFile.new()
	config.set_value("video", "render_scale", render_scale)
	config.set_value("video", "max_fps", max_fps)
	config.save(PATH)


func load_settings():
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	render_scale = config.get_value("video", "render_scale", 1.0)
	max_fps = config.get_value("video", "max_fps", 60)


func _apply():
	get_viewport().scaling_3d_scale = render_scale
	Engine.max_fps = max_fps
	save_settings()
