class_name Character extends CharacterBody3D

var player_id: int = -1
var is_local_player: bool = false
var camera: Camera3D
var server_controller: ServerPhysicsController
var _setup_done := false

const CLIENT_MOVE_SPEED: float = 10.0
const CLIENT_JUMP_VELOCITY: float = 10.0
const CLIENT_GRAVITY: float = 21.0

@export var mouse_sensitivity: float = 0.002
@export var username: String = ""

@onready var serverSync = $ServerSync
#
func _enter_tree() -> void:
	# Only set authority if name is valid peer id
	if name.is_valid_int():
		var id = int(name)
		$MultiplayerSynchronizer.set_multiplayer_authority(id)
		#
func _ready() -> void:
	# Disable camera immediately
	var cam = $Camera3D
	if cam:
		cam.current = false
	
func _process(_delta: float) -> void:
	if _setup_done:
		return
	
	# Wait until name is valid
	if not name.is_valid_int():
		return
	
	_setup_done = true
	_do_setup()
	
	
func _do_setup() -> void:
	player_id = int(name)
	var my_peer_id = multiplayer.get_unique_id()
	is_local_player = (player_id == my_peer_id)

	if is_local_player:
		print("=== CHARACTER SETUP [peer %d] ===" % my_peer_id)
		print("player_id: ", player_id)
		print("is_local_player: ", is_local_player)
		
	
	#$MultiplayerSynchronizer.set_multiplayer_authority(player_id)
	
	camera = $Camera3D
	
	if is_local_player:
		if camera:
			camera.current = true
			print("Activated my camera")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	if multiplayer.is_server():
		server_controller = ServerPhysicsController.new()
		add_child(server_controller)
		server_controller.initialize(self, player_id)
		server_controller.set_stats({
			"move_speed": 10.0,
			"jump_velocity": 10.0,
			"gravity": 21.0
		})
	

func _physics_process(delta: float) -> void:
	if not _setup_done:
		return
	
	if not multiplayer.is_server() and is_local_player:
		_client_physics(delta)

func _client_physics(delta: float) -> void:
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var jump = Input.is_action_just_pressed("space")
	
	var move_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * CLIENT_MOVE_SPEED
		velocity.z = move_direction.z * CLIENT_MOVE_SPEED
	else:
		velocity.x = 0
		velocity.z = 0
	
	if not is_on_floor():
		velocity.y -= CLIENT_GRAVITY * delta
	
	if jump and is_on_floor():
		velocity.y = CLIENT_JUMP_VELOCITY
	
	move_and_slide()
	
	_send_input_to_server(input_dir, jump)

func _send_input_to_server(input_dir: Vector2, jump: bool) -> void:
	var camera_rot_x = camera.global_rotation.x if camera else 0.0
	var rotation_y = global_rotation.y
	
	rpc_id(1, "_receive_client_input", input_dir, jump, rotation_y, camera_rot_x, 0)

@rpc("any_peer", "unreliable")
func _receive_client_input(input_dir: Vector2, jump: bool, rotation_y: float, camera_rot_x: float, _client_tick: int) -> void:
	if not server_controller:
		return
	
	if not server_controller.verify_authority(multiplayer.get_remote_sender_id()):
		return
	
	server_controller.apply_movement(input_dir, jump)
	
	global_rotation.y = rotation_y
	if camera:
		camera.global_rotation.x = camera_rot_x

func _input(event: InputEvent) -> void:
	if not is_local_player or not camera:
		return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
