extends Node

const FPS: int = 60
const MS_PER_FRAME: float = 1000.0 / float(FPS)
const PING_INTERVAL_MS: int = 500

var _ping_timer: Timer
var _raw_tick: int = 0
var _tick_offset: int = 0

var tick: int:
	get: return _raw_tick + _tick_offset

func _ready() -> void:
	# Start ping timer when connected to server
	NetworkManager.player_connected.connect(_on_player_connected)

func _physics_process(_delta: float) -> void:
	_raw_tick += 1

func _on_player_connected(id: int) -> void:
	if id == multiplayer.get_unique_id():  # We just connected
		_setup_ping_timer()
		_request_ping()

func _setup_ping_timer() -> void:
	if _ping_timer: return
	
	_ping_timer = Timer.new()
	_ping_timer.wait_time = float(PING_INTERVAL_MS) / 1000.0
	_ping_timer.autostart = true
	_ping_timer.timeout.connect(_request_ping)
	add_child(_ping_timer)

func _request_ping() -> void:
	if NetworkManager.is_server: return
	rpc_id(1, "_server_ping", Time.get_ticks_msec(), _raw_tick)

@rpc("any_peer", "reliable")
func _server_ping(client_time_ms: int, client_tick: int) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	rpc_id(sender_id, "_client_pong", _raw_tick, client_tick, client_time_ms)

@rpc("reliable")
func _client_pong(server_tick: int, echo_client_tick: int, echo_client_time_ms: int) -> void:
	var rtt = Time.get_ticks_msec() - echo_client_time_ms
	var one_way_ticks = int((rtt / 2.0) / MS_PER_FRAME)
	var tick_difference = server_tick - echo_client_tick
	_tick_offset = tick_difference - one_way_ticks
#```
#
#---
#
### Step 4: Game World Scene
#
#**scenes/world/game_world.tscn:**
#
#Scene structure:
#```
#GameWorld (Node3D)
#├── Environment (lighting, ground, etc.)
#│   ├── DirectionalLight3D
#│   ├── Ground (StaticBody3D)
#│   └── Obstacles...
#├── Entities (Node3D) [Set unique_name_in_owner = true, name it "%Entities"]
#├── MultiplayerSpawner
#│   └── Spawn Path: %Entities
#│   └── Auto Spawn List: [character.tscn]
#└── Camera3D (for server view or lobby)
