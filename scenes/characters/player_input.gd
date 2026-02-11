extends Node
class_name PlayerInput

var movement: Vector2 = Vector2.ZERO
var jump: bool = false
var rotation_delta: float = 0.0
var camera_rotation_delta: float = 0.0

var left_stick := Vector2.ZERO
var right_stick := Vector2.ZERO
@export var joystick_look_sensitivity: float = 2.0

var body: CharacterBody3D

# Accumulators for mouse input between ticks
var _accumulated_rot: float = 0.0
var _accumulated_cam_rot: float = 0.0

func _rollback_tick(_delta: float, _tick: int, _is_fresh: bool) -> void:
	if not is_multiplayer_authority():
		return
	
	movement = Input.get_vector("left", "right", "up", "down") + left_stick
	jump = Input.is_action_pressed("space")  # NOT just_pressed - doesn't work with rollback
	
	# Consume accumulated mouse deltas
	rotation_delta = _accumulated_rot
	camera_rotation_delta = _accumulated_cam_rot
	
	# Add stick on top
	if right_stick != Vector2.ZERO:
		rotation_delta += -right_stick.x * joystick_look_sensitivity * _delta
		camera_rotation_delta += -right_stick.y * joystick_look_sensitivity * _delta
	
	# Reset accumulators AFTER consuming
	_accumulated_rot = 0.0
	_accumulated_cam_rot = 0.0

func apply_mouse_look(y_delta: float, x_delta: float) -> void:
	_accumulated_rot += y_delta
	_accumulated_cam_rot += x_delta

func on_left_stick_changed(value: Vector2, _d: float, _a: float, _ac: float, _anc: float) -> void:
	left_stick = value

func on_right_stick_changed(value: Vector2, _d: float, _a: float, _ac: float, _anc: float) -> void:
	right_stick = value
