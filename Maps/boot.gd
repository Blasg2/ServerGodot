extends Control

const VERSION_URL := "https://raw.githubusercontent.com/Blasg2/BHsimOpen/main/version.json"
const PLAY_STORE_URL := "https://play.google.com/store/apps/details?id=com.yourcompany.yourgame"

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var status_label: Label = $StatusLabel

var _http: HTTPRequest
var _download_dest: String = ""
var _download_callback: Callable
var _remote_info: Dictionary = {}
var _pending_base_downloads: Array = []
var _downloaded_something := false

func _ready():
	progress_bar.visible = false
	status_label.text = "Verificando atualizações..."
	_check_for_updates()

func _check_for_updates():
	_http_request(VERSION_URL, "", _on_version_check)

func _on_version_check(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_go_to_main_menu()
		return
	
	_remote_info = JSON.parse_string(body.get_string_from_utf8())
	if _remote_info == null:
		_go_to_main_menu()
		return
	
	var remote_base: String = _remote_info.get("base", PatchLoader.BUILT_IN_BASE)
	var remote_version: String = _remote_info.get("version", PatchLoader.BUILT_IN_BASE)
	var store_version: String = _remote_info.get("store_version", PatchLoader.BUILT_IN_BASE)
	
	if remote_version == PatchLoader.current_version:
		_go_to_main_menu()
		return
	
	if PatchLoader.current_base != remote_base:
		if OS.has_feature("mobile"):
			if _version_compare(store_version, PatchLoader.BUILT_IN_BASE) > 0:
				_prompt_store_update(store_version)
			else:
				_go_to_main_menu()
			return
		
		var upgrades: Array = _remote_info.get("base_upgrades", [])
		_pending_base_downloads = _find_upgrade_path(PatchLoader.current_base, remote_base, upgrades)
		
		if _pending_base_downloads.is_empty():
			var full_url = _remote_info.get("full_download_url", "")
			if full_url != "":
				_prompt_full_download(full_url)
			else:
				_go_to_main_menu()
			return
		
		_download_next_base_upgrade()
		return
	
	_download_patch(remote_version)

# ─── BASE UPGRADES ───

func _find_upgrade_path(from_base: String, to_base: String, upgrades: Array) -> Array:
	var upgrade_map := {}
	for u in upgrades:
		upgrade_map[u["from"]] = u
	
	var path := []
	var current = from_base
	var safety := 0
	while current != to_base and safety < 50:
		safety += 1
		if not upgrade_map.has(current):
			return []
		var step = upgrade_map[current]
		if not PatchLoader.applied_bases.has(step["to"]):
			path.append(step)
		current = step["to"]
	
	if current != to_base:
		return []
	return path

func _download_next_base_upgrade():
	if _pending_base_downloads.is_empty():
		PatchLoader.current_version = PatchLoader.current_base + ".0"
		PatchLoader.save_state()
		
		var remote_version: String = _remote_info.get("version", "")
		if remote_version != PatchLoader.current_version:
			_download_patch(remote_version)
		else:
			_go_to_main_menu()
		return
	
	var step = _pending_base_downloads[0]
	var dest_name = PatchLoader.base_pck_name(step["to"])
	
	status_label.text = "Baixando base %s → %s..." % [step["from"], step["to"]]
	progress_bar.visible = true
	progress_bar.value = 0
	
	DirAccess.make_dir_recursive_absolute("user://patches/")
	_download_file(
		step["url"],
		"user://patches/" + dest_name,
		_on_base_downloaded.bind(step)
	)

func _on_base_downloaded(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray, step: Dictionary):
	progress_bar.visible = false
	var dest_path = "user://patches/" + PatchLoader.base_pck_name(step["to"])
	
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		if FileAccess.file_exists(dest_path):
			DirAccess.remove_absolute(dest_path)
		status_label.text = "Falha ao baixar atualização"
		await get_tree().create_timer(2.0).timeout
		_go_to_main_menu()
		return
	
	if ProjectSettings.load_resource_pack(dest_path):
		PatchLoader.applied_bases.append(step["to"])
		PatchLoader.current_base = step["to"]
		PatchLoader.save_state()
		_downloaded_something = true
		
		if FileAccess.file_exists("user://patches/patch.pck"):
			DirAccess.remove_absolute("user://patches/patch.pck")
		
		_pending_base_downloads.pop_front()
		_download_next_base_upgrade()
	else:
		DirAccess.remove_absolute(dest_path)
		status_label.text = "Falha ao aplicar atualização"
		await get_tree().create_timer(2.0).timeout
		_go_to_main_menu()

# ─── PATCH ───

func _download_patch(version: String):
	var patch_url: String = _remote_info.get("patch_url", "")
	if patch_url == "":
		_go_to_main_menu()
		return
	
	if FileAccess.file_exists("user://patches/patch.pck"):
		DirAccess.remove_absolute("user://patches/patch.pck")
	
	status_label.text = "Baixando atualização..."
	progress_bar.visible = true
	progress_bar.value = 0
	
	DirAccess.make_dir_recursive_absolute("user://patches/")
	_download_file(
		patch_url,
		"user://patches/patch.pck",
		_on_patch_downloaded.bind(version)
	)

func _on_patch_downloaded(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray, version: String):
	progress_bar.visible = false
	
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		if FileAccess.file_exists("user://patches/patch.pck"):
			DirAccess.remove_absolute("user://patches/patch.pck")
		status_label.text = "Falha ao baixar atualização"
		await get_tree().create_timer(2.0).timeout
		_go_to_main_menu()
		return
	
	if ProjectSettings.load_resource_pack("user://patches/patch.pck"):
		PatchLoader.current_version = version
		PatchLoader.save_state()
		_downloaded_something = true
		status_label.text = "Atualizado para v%s!" % version
		await get_tree().create_timer(1.0).timeout
	else:
		DirAccess.remove_absolute("user://patches/patch.pck")
		status_label.text = "Falha ao aplicar atualização"
		await get_tree().create_timer(2.0).timeout
	
	_go_to_main_menu()

# ─── PROMPTS ───

func _prompt_store_update(store_version: String):
	status_label.text = "Nova versão disponível (v%s)!\nAtualize pela Play Store." % store_version
	progress_bar.visible = false
	await get_tree().create_timer(2.0).timeout
	OS.shell_open(PLAY_STORE_URL)
	await get_tree().create_timer(3.0).timeout
	_go_to_main_menu()

func _prompt_full_download(url: String):
	status_label.text = "Nova versão disponível!\nBaixe a nova versão."
	progress_bar.visible = false
	await get_tree().create_timer(2.0).timeout
	OS.shell_open(url)
	await get_tree().create_timer(3.0).timeout
	_go_to_main_menu()

# ─── HTTP ───

func _http_request(url: String, download_path: String, callback: Callable):
	if _http:
		_http.queue_free()
	_http = HTTPRequest.new()
	add_child(_http)
	_download_dest = ""
	if download_path != "":
		_http.download_file = download_path
		_download_dest = download_path
	_download_callback = callback
	_http.request_completed.connect(_on_http_done)
	if _http.request(url) != OK:
		_http.queue_free()
		_http = null
		_go_to_main_menu()

func _download_file(url: String, dest: String, callback: Callable):
	_http_request(url, dest, callback)

func _on_http_done(result: int, code: int, headers: PackedStringArray, body: PackedByteArray):
	var cb = _download_callback
	_download_callback = Callable()
	_http.queue_free()
	_http = null
	cb.call(result, code, headers, body)

func _process(_delta: float):
	if _http == null or _download_dest == "":
		return
	var body_size = _http.get_body_size()
	var downloaded = _http.get_downloaded_bytes()
	if body_size > 0:
		progress_bar.value = (float(downloaded) / float(body_size)) * 100.0
		status_label.text = "Baixando... %.1f / %.1f MB" % [downloaded / 1048576.0, body_size / 1048576.0]

# ─── NAV ───

func _go_to_main_menu():
	PatchLoader.save_state()
	if _downloaded_something:
		status_label.text = "Reiniciando..."
		await get_tree().create_timer(0.5).timeout
		OS.set_restart_on_exit(true)
		get_tree().quit()
		return
	get_tree().change_scene_to_file("res://menu.tscn")

func _version_compare(a: String, b: String) -> int:
	var parts_a = a.split(".")
	var parts_b = b.split(".")
	var max_len = max(parts_a.size(), parts_b.size())
	for i in max_len:
		var va = int(parts_a[i]) if i < parts_a.size() else 0
		var vb = int(parts_b[i]) if i < parts_b.size() else 0
		if va > vb: return 1
		elif va < vb: return -1
	return 0
