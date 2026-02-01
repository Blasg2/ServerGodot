class_name Character extends CharacterBody3D

var player_id: int = -1
var is_local_player: bool = false
var camera: Camera3D
var server_controller: ServerPhysicsController

# CLIENT: Approximate values for prediction (can be slightly wrong)
const CLIENT_MOVE_SPEED: float = 10.0
const CLIENT_JUMP_VELOCITY: float = 10.0
const CLIENT_GRAVITY: float = 21.0

@export var mouse_sensitivity: float = 0.002

func _ready() -> void:
	
	# Get player_id from node name
	player_id = int(name)	

	is_local_player = (player_id == NetworkManager.player_id)
	set_multiplayer_authority(player_id)
	

	print("=== CHARACTER READY ===")
	print("player_id: ", player_id)
	print("is_local_player: ", is_local_player)
	print("is_server: ", multiplayer.is_server())
	print("======================")
	
	camera = $Camera3D
	
	# Setup camera
	if not is_local_player:
		if camera:
			camera.current = false
			camera.queue_free()
			camera = null
			print("Deleted other player's camera")
	else:
		if camera:
			camera.current = true
			print("Activated my camera")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# SERVER: Setup physics controller
	if multiplayer.is_server():
		server_controller = ServerPhysicsController.new()
		add_child(server_controller)
		server_controller.initialize(self, player_id)
		
		# TODO: Load stats from database
		# For now, hardcoded example showing different speeds
		server_controller.set_stats({
			"move_speed": 50.0,  # Could vary per player/class
			"jump_velocity": 10.0,
			"gravity": 21.0
		})

func _physics_process(delta: float) -> void:
	# Only clients do prediction; server uses controller
	if not multiplayer.is_server() and is_local_player:
		_client_physics(delta)

## CLIENT: Local prediction using approximate values
func _client_physics(delta: float) -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var jump = Input.is_action_just_pressed("ui_accept")
	
	# Predict movement (just for feel, server will correct)
	var move_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * CLIENT_MOVE_SPEED
		velocity.z = move_direction.z * CLIENT_MOVE_SPEED
	else:
		velocity.x = 0
		velocity.z = 0
	
	# Predict gravity
	if not is_on_floor():
		velocity.y -= CLIENT_GRAVITY * delta
	
	# Predict jump
	if jump and is_on_floor():
		velocity.y = CLIENT_JUMP_VELOCITY
	
	move_and_slide()
	
	# Send raw input to server
	_send_input_to_server(input_dir, jump)

## CLIENT: Send only raw input (not velocity/position)
func _send_input_to_server(input_dir: Vector2, jump: bool) -> void:
	var camera_rot_x = camera.global_rotation.x if camera else 0.0
	var rotation_y = global_rotation.y
	
	rpc_id(1, "_receive_client_input", input_dir, jump, rotation_y, camera_rot_x, NetworkClock.tick)

## SERVER: Receive client input and delegate to controller
@rpc("any_peer", "unreliable")
func _receive_client_input(input_dir: Vector2, jump: bool, rotation_y: float, camera_rot_x: float, _client_tick: int) -> void:
	if not server_controller:
		return
	
	# Verify sender
	if not server_controller.verify_authority(multiplayer.get_remote_sender_id()):
		return
	
	# Apply movement through controller (uses server's authoritative stats)
	server_controller.apply_movement(input_dir, jump)
	
	# Apply rotation
	global_rotation.y = rotation_y
	if camera:
		camera.global_rotation.x = camera_rot_x

## Handle mouse look (client only)
func _input(event: InputEvent) -> void:
	if not is_local_player or not camera:
		return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
