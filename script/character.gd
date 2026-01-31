class_name Character extends CharacterBody3D

var player_id: int = -1
var is_local_player: bool = false
var camera: Camera3D

# CLIENT: Approximate values for prediction (can be slightly wrong, doesn't matter)
# These are just for feel, server will correct us
const CLIENT_MOVE_SPEED: float = 10.0
const CLIENT_JUMP_VELOCITY: float = 10.0
const CLIENT_GRAVITY: float = 21.0

# SERVER ONLY: The REAL authoritative values
# Only these matter for actual gameplay
var server_move_speed: float = 10.0
var server_jump_velocity: float = 10.0
var server_gravity: float = 21.0

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
	
	# SERVER: Could load character stats from database/config here
	if multiplayer.is_server():
		server_move_speed = 50.0  # Could vary per player/class
		server_jump_velocity = 10.0
		server_gravity = 21.0
		print("Server initialized stats for player ", player_id)

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_physics(delta)
	elif is_local_player:
		_client_physics(delta)

## SERVER: Authoritative simulation using SERVER values only
func _server_physics(delta: float) -> void:
	# Apply gravity using SERVER value
	if not is_on_floor():
		velocity.y -= server_gravity * delta
	
	# Velocity is set by _receive_client_input using SERVER values
	# Client can't affect this!
	move_and_slide()

## CLIENT: Local prediction using APPROXIMATE values
func _client_physics(delta: float) -> void:
	# Get raw input (just button states)
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var jump = Input.is_action_just_pressed("ui_accept")
	
	# Predict movement using CLIENT constants (approximate)
	# This is just for responsiveness - server will correct us
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
	
	# Send ONLY raw input to server (not velocity, not position)
	_send_input_to_server(input_dir, jump)

## CLIENT: Send only raw input (W/A/S/D states, not calculated velocity)
func _send_input_to_server(input_dir: Vector2, jump: bool) -> void:
	var camera_rotation = camera.global_rotation if camera else Vector3.ZERO
	
	# We send: which keys are pressed, camera angle, timestamp
	# We DON'T send: velocity, position, or any calculated values
	rpc_id(1, "_receive_client_input", input_dir, jump, camera_rotation, NetworkClock.tick)

## SERVER: Receive raw input and calculate movement using SERVER values
@rpc("any_peer", "unreliable")
func _receive_client_input(input_dir: Vector2, jump: bool, camera_rot: Vector3, _client_tick: int) -> void:
	# Verify this input is from the character's owner
	if multiplayer.get_remote_sender_id() != player_id:
		print("WARNING: Player ", multiplayer.get_remote_sender_id(), " tried to control player ", player_id)
		return
	
	# Calculate movement using SERVER's authoritative values
	# Client's local values don't matter!
	var move_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if move_direction != Vector3.ZERO:
		# Use SERVER_MOVE_SPEED (client can't cheat this)
		velocity.x = move_direction.x * server_move_speed
		velocity.z = move_direction.z * server_move_speed
	else:
		velocity.x = 0
		velocity.z = 0
	
	# Use SERVER_JUMP_VELOCITY (client can't cheat this)
	if jump and is_on_floor():
		velocity.y = server_jump_velocity
	
	# Apply rotation
	global_rotation.y = camera_rot.y
	if camera:
		camera.global_rotation.x = camera_rot.x

## Handle mouse look (client only)
func _input(event: InputEvent) -> void:
	if not is_local_player or not camera:
		return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)




## SERVER ONLY: Functions to modify stats (for powerups, upgrades, etc.)
#func set_move_speed(new_speed: float) -> void:
	#if not multiplayer.is_server():
		#return
	#server_move_speed = new_speed
	#print("Player ", player_id, " speed changed to ", new_speed)
#
#func set_jump_power(new_jump: float) -> void:
	#if not multiplayer.is_server():
		#return
	#server_jump_velocity = new_jump
	#print("Player ", player_id, " jump power changed to ", new_jump)

## Optional: Sync display values to client for UI
## (if you want to show current speed in a HUD)
@rpc("authority", "reliable")
func sync_stats_for_display(speed: float, jump: float) -> void:
	# Client receives display values for UI only
	# These don't affect actual movement!
	pass  # You can use these to update UI later
