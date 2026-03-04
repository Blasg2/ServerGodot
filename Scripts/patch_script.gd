extends Node

var BUILT_IN_BASE: String
var current_version: String

func _init():
	BUILT_IN_BASE = ProjectSettings.get_setting("application/config/version")
	current_version = BUILT_IN_BASE
	_load_state()
	_apply_patch()

func _load_state():
	var config := ConfigFile.new()
	if config.load("user://patches/state.cfg") != OK:
		return
	
	if config.get_value("state", "built_in_base", "") != BUILT_IN_BASE:
		_clear_all()
		return
	
	current_version = config.get_value("state", "current_version", BUILT_IN_BASE)

func _apply_patch():
	if FileAccess.file_exists("user://patches/patch.pck"):
		if ProjectSettings.load_resource_pack("user://patches/patch.pck"):
			print("Patch loaded: patch.pck (v", current_version, ")")
		else:
			print("Failed to load patch.pck, removing")
			_clear_all()

func save_state():
	DirAccess.make_dir_recursive_absolute("user://patches/")
	var config := ConfigFile.new()
	config.set_value("state", "built_in_base", BUILT_IN_BASE)
	config.set_value("state", "current_version", current_version)
	config.save("user://patches/state.cfg")

func _clear_all():
	current_version = BUILT_IN_BASE
	var dir = DirAccess.open("user://patches/")
	if dir:
		for file in dir.get_files():
			dir.remove(file)
	print("Cleared all patches")
