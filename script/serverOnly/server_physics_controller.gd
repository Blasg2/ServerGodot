# res://script/serverOnly/server_physics_controller.gd
class_name ServerPhysicsController
extends Node

var physics_body: CharacterBody3D
var owner_id: int = -1
var camera_node: Camera3D  # Reference to camera for rotation

## Server-authoritative stats
var move_speed: float = 10.0
var jump_velocity: float = 10.0
var gravity: float = 21.0

## State sync
var sync_timer: float = 0.0
const SYNC_RATE: float = 1.0 / 15.0  # 15 updates per second (reduced from 20 for smoother interpolation)

func initialize(body: CharacterBody3D, player_id: int) -> void:
	physics_body = body
	owner_id = player_id
	# Find camera child
	for child in body.get_children():
		if child is Camera3D:
			camera_node = child
			break

func _ready() -> void:
	if not multiplayer.is_server():
		set_physics_process(false)
		queue_free()

func _physics_process(delta: float) -> void:
	if not physics_body:
		return

	# Apply gravity
	if not physics_body.is_on_floor():
		physics_body.velocity.y -= gravity * delta

	# Move the character (only once per frame!)
	physics_body.move_and_slide()

	# Sync state to clients periodically
	sync_timer += delta
	if sync_timer >= SYNC_RATE:
		sync_timer = 0.0
		_broadcast_state()

func apply_movement(input_dir: Vector2, _jump: bool) -> void:
	if not physics_body:
		return

	var move_direction = (physics_body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if move_direction != Vector3.ZERO:
		physics_body.velocity.x = move_direction.x * move_speed
		physics_body.velocity.z = move_direction.z * move_speed
	else:
		physics_body.velocity.x = 0
		physics_body.velocity.z = 0

func apply_jump() -> void:
	if not physics_body:
		return

	if physics_body.is_on_floor():
		physics_body.velocity.y = jump_velocity

func apply_rotation(rotation_delta: float, camera_rotation_delta: float) -> void:
	if not physics_body:
		return

	# Apply rotation delta to body
	physics_body.rotate_y(rotation_delta)

	# Apply camera rotation delta
	if camera_node:
		camera_node.rotate_x(camera_rotation_delta)
		camera_node.rotation.x = clamp(camera_node.rotation.x, -PI/2, PI/2)

func _broadcast_state() -> void:
	if not physics_body:
		return

	var cam_rot_x = camera_node.global_rotation.x if camera_node else 0.0

	# Send to all clients (including the owner for reconciliation)
	physics_body.rpc("_sync_server_state",
		physics_body.global_position,
		physics_body.global_rotation.y,
		physics_body.velocity,
		cam_rot_x)

func verify_authority(sender_id: int) -> bool:
	if sender_id != owner_id:
		push_warning("Player %d tried to control player %d" % [sender_id, owner_id])
		return false
	return true

func set_stats(stats: Dictionary) -> void:
	if stats.has("move_speed"): move_speed = stats.move_speed
	if stats.has("jump_velocity"): jump_velocity = stats.jump_velocity
	if stats.has("gravity"): gravity = stats.gravity
