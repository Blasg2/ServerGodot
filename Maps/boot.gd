extends Control

const VERSION_URL := "https://raw.githubusercontent.com/Blasg2/BHsimOpen/main/version.json"
const PLAY_STORE_URL := "https://play.google.com/store/apps/details?id=com.yourcompany.yourgame"

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var status_label: Label = $StatusLabel

var _http: HTTPRequest
var _download_dest: String = ""
var _download_callback: Callable
var _remote_info: Dictionary = {}
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
	
	# Already up to date
	if remote_version == PatchLoader.current_version:
		_go_to_main_menu()
		return
	
	# New base version required
	if remote_base != PatchLoader.BUILT_IN_BASE:
		if OS.has_feature("mobile"):
			PatchLoader._clear_all()
			PatchLoader.save_state()
			_prompt_store_update()
		else:
			status_label.text = "Contate o dev"
			get_tree().paused = true
		return
	
	# Same base, new patch
	_download_patch(remote_version)

# ─── PATCH ───

func _download_patch(version: String):
	var patch_url: String = _remote_info.get("patch_url", "")
	if patch_url == "":
		_go_to_main_menu()
		return
	
	# Delete old patch
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

func _prompt_store_update():
	status_label.text = "Nova versão disponível!\nAtualize pela Play Store."
	progress_bar.visible = false
	await get_tree().create_timer(2.0).timeout
	OS.shell_open(PLAY_STORE_URL)

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
