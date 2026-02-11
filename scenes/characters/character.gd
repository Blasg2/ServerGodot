# res://scenes/characters/character.gd
# MIGRATED TO NETFOX - Replaces custom sync with RollbackSynchronizer
class_name Character extends CharacterBody3D

@onready var camera: Camera3D = $Camera3D
@onready var input: PlayerInput = $PlayerInput

var player_id: int = -1
var is_local_player: bool = false

## Movement constants (same on all peers - deterministic simulation)
const MOVE_SPEED: float = 5.0
const JUMP_VELOCITY: float = 10.0
const GRAVITY: float = 21.0

@export var mouse_sensitivity: float = 0.002
@export var username: String = ""

@onready var controls := $"../Controls"

## State properties for RollbackSynchronizer (server-authoritative)
## These are declared here so RollbackSynchronizer can find them

func _enter_tree() -> void:
	player_id = int(get_parent().name)
	# Body is owned by server (authority = 1) for state
	set_multiplayer_authority(1)

func _ready() -> void:
	camera.current = false
	is_local_player = (player_id == multiplayer.get_unique_id())

	# Set up PlayerInput authority - owned by the PLAYER for input
	input.set_multiplayer_authority(player_id)
	input.body = self

	if not is_local_player and not multiplayer.is_server():
		if controls:
			controls.queue_free()
	else:
		controls.show()
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## NETFOX: This replaces BOTH _client_physics AND ServerPhysicsController
## It runs on ALL peers during the rollback loop (tick-based, deterministic)
func _rollback_tick(delta: float, _tick: int, _is_fresh: bool) -> void:
	var input_dir: Vector2 = input.movement
	var do_jump: bool = input.jump
	var rot_delta: float = input.rotation_delta
	var cam_rot_delta: float = input.camera_rotation_delta
	
	# Apply rotation for ALL players — rollback restores state,
	# so we must reapply rotation from input during resimulation
	if rot_delta != 0.0:
		rotate_y(rot_delta)
	if cam_rot_delta != 0.0 and camera:
		camera.rotate_x(cam_rot_delta)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)
	
	# Movement (same as before)
	var move_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * MOVE_SPEED
		velocity.z = move_direction.z * MOVE_SPEED
	else:
		velocity.x = 0
		velocity.z = 0
	
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if do_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
## But the rotation is applied in _rollback_tick via PlayerInput
func _input(event: InputEvent) -> void:
	if not is_local_player or not camera or OS.has_feature("mobile"):
		return
	if event is InputEventMouseMotion:
		var y_delta = -event.relative.x * mouse_sensitivity
		var x_delta = -event.relative.y * mouse_sensitivity
		# DON'T rotate here — just feed into PlayerInput
		input.apply_mouse_look(y_delta, x_delta)


## Joystick signal connections (connected from scene)
func _on_left_stick_analogic_changed(value: Vector2, distance: float, angle: float, angle_clockwise: float, angle_not_clockwise: float) -> void:
	input.on_left_stick_changed(value, distance, angle, angle_clockwise, angle_not_clockwise)

func _on_right_joystick_analogic_changed(value: Vector2, distance: float, angle: float, angle_clockwise: float, angle_not_clockwise: float) -> void:
	input.on_right_stick_changed(value, distance, angle, angle_clockwise, angle_not_clockwise)
