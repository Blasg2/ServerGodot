extends Node

var BUILT_IN_BASE: String
var current_base: String
var current_version: String
var applied_bases: Array = []

func _init():
	BUILT_IN_BASE = ProjectSettings.get_setting("application/config/version")
	_load_state()
	_apply_existing_pcks()

func _load_state():
	current_base = BUILT_IN_BASE
	current_version = BUILT_IN_BASE
	
	var config := ConfigFile.new()
	if config.load("user://patches/state.cfg") != OK:
		return
	
	if config.get_value("state", "built_in_base", "") != BUILT_IN_BASE:
		_clear_all()
		return
	
	current_base = config.get_value("state", "current_base", BUILT_IN_BASE)
	current_version = config.get_value("state", "current_version", BUILT_IN_BASE)
	applied_bases = config.get_value("state", "applied_bases", [])

func _apply_existing_pcks():
	for base_ver in applied_bases:
		var pck_path = "user://patches/" + base_pck_name(base_ver)
		if FileAccess.file_exists(pck_path):
			if ProjectSettings.load_resource_pack(pck_path):
				print("Patch loaded: ", pck_path)
			else:
				print("Failed to load: ", pck_path, " — clearing all")
				_clear_all()
				return
		else:
			print("Missing: ", pck_path, " — clearing all")
			_clear_all()
			return
	
	if FileAccess.file_exists("user://patches/patch.pck"):
		if ProjectSettings.load_resource_pack("user://patches/patch.pck"):
			print("Patch loaded: patch.pck (v", current_version, ")")
		else:
			print("Failed to load patch.pck, removing")
			DirAccess.remove_absolute("user://patches/patch.pck")
			current_version = current_base + ".0"

func save_state():
	DirAccess.make_dir_recursive_absolute("user://patches/")
	var config := ConfigFile.new()
	config.set_value("state", "built_in_base", BUILT_IN_BASE)
	config.set_value("state", "current_base", current_base)
	config.set_value("state", "current_version", current_version)
	config.set_value("state", "applied_bases", applied_bases)
	config.save("user://patches/state.cfg")

func base_pck_name(to_base: String) -> String:
	return "base_to_%s.pck" % to_base.replace(".", "_")

func _clear_all():
	current_base = BUILT_IN_BASE
	current_version = BUILT_IN_BASE
	applied_bases = []
	var dir = DirAccess.open("user://patches/")
	if dir:
		for file in dir.get_files():
			dir.remove(file)
	print("Cleared all patches")
