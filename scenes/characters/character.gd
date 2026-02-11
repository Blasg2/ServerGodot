class_name Character extends CharacterBody3D

@onready var camera: Camera3D = $Camera3D

var player_id: int = -1
var is_local_player: bool = false
var server_controller: ServerPhysicsController

const CLIENT_MOVE_SPEED: float = 5.0
const CLIENT_JUMP_VELOCITY: float = 10.0
const CLIENT_GRAVITY: float = 21.0

@export var mouse_sensitivity: float = 0.002
@export var joystick_look_sensitivity: float = 2.0
var left_stick := Vector2.ZERO
var right_stick := Vector2.ZERO

@export var username: String = ""

@onready var controls := $"../Controls"

# Client-side prediction reconciliation
var last_server_position := Vector3.ZERO
var last_server_rotation_y := 0.0
const RECONCILIATION_THRESHOLD := 0.5  # If desync > 0.5 units, snap to server

# State buffering for smooth interpolation (based on Godot best practices)
var state_buffer := []  # Buffer of past server states
const BUFFER_SIZE := 3  # Keep last 3 states
const INTERPOLATION_DELAY := 0.1  # Render 100ms in the past for smoothness
var render_timestamp := 0.0

func _enter_tree() -> void:
	player_id = int(get_parent().name)
	set_multiplayer_authority(player_id, true)

func _ready() -> void:
	camera.current = false
	is_local_player = (player_id == multiplayer.get_unique_id())

	# Initialize interpolation targets to current position
	last_server_position = global_position
	last_server_rotation_y = global_rotation.y

	if not is_local_player and not multiplayer.is_server():
		if controls :
			controls.queue_free()
	else:
		controls.show()
		camera.current = true
		print("Activated my camera")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


	if multiplayer.is_server():
		server_controller = ServerPhysicsController.new()
		add_child(server_controller)
		server_controller.initialize(self, player_id)
		server_controller.set_stats({
			"move_speed": 5.0,
			"jump_velocity": 10.0,
			"gravity": 21.0
		})

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() and is_local_player:
		_client_physics(delta)
	elif not multiplayer.is_server() and not is_local_player:
		# Other players - smooth interpolation to server position
		_interpolate_to_server_state(delta)

func _client_physics(delta: float) -> void:
	var input_dir := Input.get_vector("left","right","up","down") + left_stick
	var jump = Input.is_action_just_pressed("space")

	# Track rotation changes for server
	var rotation_delta := 0.0
	var camera_rotation_delta := 0.0

	# --- RIGHT STICK LOOK (minimal) ---
	if right_stick != Vector2.ZERO:
		var y_delta = -right_stick.x * joystick_look_sensitivity * delta
		var x_delta = -right_stick.y * joystick_look_sensitivity * delta

		rotate_y(y_delta)
		camera.rotate_x(x_delta)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

		rotation_delta += y_delta
		camera_rotation_delta += x_delta
	# --- end look ---


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

	_send_input_to_server(input_dir, jump, rotation_delta, camera_rotation_delta)

func _send_input_to_server(input_dir: Vector2, jump: bool, rotation_delta: float, camera_rotation_delta: float) -> void:
	# Send movement unreliably (every frame, loss is acceptable)
	rpc_id(1, "_receive_movement_input", input_dir, rotation_delta, camera_rotation_delta)

	# Send jump reliably (critical action, cannot be lost)
	if jump:
		rpc_id(1, "_receive_jump_input")

@rpc("any_peer", "unreliable")
func _receive_movement_input(input_dir: Vector2, rotation_delta: float, camera_rotation_delta: float) -> void:
	if not server_controller:
		return

	if not server_controller.verify_authority(multiplayer.get_remote_sender_id()):
		return

	server_controller.apply_movement(input_dir, false)
	server_controller.apply_rotation(rotation_delta, camera_rotation_delta)

@rpc("any_peer", "reliable")
func _receive_jump_input() -> void:
	if not server_controller:
		return

	if not server_controller.verify_authority(multiplayer.get_remote_sender_id()):
		return

	server_controller.apply_jump()

func _input(event: InputEvent) -> void:
	if not is_local_player or not camera or OS.has_feature("mobile"):
		return

	if event is InputEventMouseMotion:
		var y_delta = -event.relative.x * mouse_sensitivity
		var x_delta = -event.relative.y * mouse_sensitivity

		rotate_y(y_delta)
		camera.rotate_x(x_delta)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

		# Send rotation delta to server immediately for mouse input
		if multiplayer.get_unique_id() != 1:  # Don't send if we ARE the server
			rpc_id(1, "_receive_movement_input", Vector2.ZERO, y_delta, x_delta)


func _on_left_stick_analogic_changed(value: Vector2, distance: float, angle: float, angle_clockwise: float, angle_not_clockwise: float) -> void:
	left_stick = value

func _on_right_joystick_analogic_changed(value: Vector2, distance: float, angle: float, angle_clockwise: float, angle_not_clockwise: float) -> void:
	right_stick = value

# Called by server to sync position to all clients
@rpc("authority", "unreliable")
func _sync_server_state(pos: Vector3, rot_y: float, vel: Vector3, cam_rot_x: float) -> void:
	if multiplayer.is_server():
		return  # Server doesn't need to receive its own sync

	if is_local_player:
		# Reconcile local prediction with server state
		var position_error = global_position.distance_to(pos)
		if position_error > RECONCILIATION_THRESHOLD:
			# Significant desync - snap to server position
			global_position = pos
			velocity = vel
		# Else: trust local prediction (it's close enough)

		# Always trust server rotation for local player
		global_rotation.y = rot_y
		if camera:
			camera.global_rotation.x = cam_rot_x
	else:
		# For other players: Use state buffering
		var current_time = Time.get_ticks_msec() / 1000.0

		# Add state to buffer
		var state = {
			"timestamp": current_time,
			"position": pos,
			"rotation_y": rot_y,
			"velocity": vel
		}
		state_buffer.append(state)

		# Keep buffer size limited
		if state_buffer.size() > BUFFER_SIZE:
			state_buffer.pop_front()

		# Check for teleport (too far from current position)
		var distance_to_new_pos = global_position.distance_to(pos)
		if distance_to_new_pos > 5.0:  # Increased threshold
			# Snap immediately and clear buffer
			global_position = pos
			global_rotation.y = rot_y
			state_buffer.clear()
			state_buffer.append(state)

func _interpolate_to_server_state(_delta: float) -> void:
	# State buffer interpolation - Best practice from Godot community
	# Render in the past for smooth interpolation between confirmed server states

	if state_buffer.size() < 2:
		return  # Need at least 2 states to interpolate

	var current_time = Time.get_ticks_msec() / 1000.0
	render_timestamp = current_time - INTERPOLATION_DELAY

	# Find two states to interpolate between
	var state_from = null
	var state_to = null

	for i in range(state_buffer.size() - 1):
		if state_buffer[i]["timestamp"] <= render_timestamp and state_buffer[i + 1]["timestamp"] >= render_timestamp:
			state_from = state_buffer[i]
			state_to = state_buffer[i + 1]
			break

	# If we couldn't find states to interpolate, use the last two
	if state_from == null or state_to == null:
		if state_buffer.size() >= 2:
			state_from = state_buffer[state_buffer.size() - 2]
			state_to = state_buffer[state_buffer.size() - 1]
		else:
			return

	# Calculate interpolation factor
	var time_diff = state_to["timestamp"] - state_from["timestamp"]
	var t = 0.0
	if time_diff > 0.0:
		t = (render_timestamp - state_from["timestamp"]) / time_diff
		t = clamp(t, 0.0, 1.0)

	# Interpolate position
	global_position = state_from["position"].lerp(state_to["position"], t)

	# Interpolate rotation (shortest path)
	var angle_from = state_from["rotation_y"]
	var angle_to = state_to["rotation_y"]
	var angle_diff = angle_to - angle_from

	# Normalize to [-PI, PI]
	while angle_diff > PI:
		angle_diff -= TAU
	while angle_diff < -PI:
		angle_diff += TAU

	global_rotation.y = angle_from + (angle_diff * t)
