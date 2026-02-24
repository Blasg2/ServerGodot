extends BaseNetInput
class_name PlayerInputFPS
@export var mouse_sensitivity: float = 0.7
var is_setup: bool = false
var override_mouse: bool = false
var mouse_rotation: Vector2 = Vector2.ZERO
var look_angle: Vector2 = Vector2.ZERO
var movement: Vector3 = Vector3.ZERO
var jump: bool = false
var camera_yaw: float = 0.0

var joy_movement: Vector2 = Vector2.ZERO

func _enter_tree() -> void:
	control.joystick.connect(setJoy)


func _input(event: InputEvent) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if !is_multiplayer_authority(): return
	if event.is_action_pressed("escape"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			override_mouse = true
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			override_mouse = false

func _gather():
	if !is_setup:
		setup()
	
	# Keyboard + joystick combined
	movement = Vector3(
		Input.get_axis("move_west", "move_east") + joy_movement.x,
		0,
		Input.get_axis("move_north", "move_south") + joy_movement.y
	)
	movement.x = clamp(movement.x, -1.0, 1.0)
	movement.z = clamp(movement.z, -1.0, 1.0)
	
	jump = Input.is_action_pressed("move_jump")
	
	var pivot = get_node_or_null("../SpringArmPivot")
	if pivot:
		camera_yaw = pivot.global_rotation.y

func setup():
	is_setup = true
	var cam = get_node_or_null("../SpringArmPivot/Camera3D")
	if cam:
		cam.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func setJoy(a,b)->void:
	a.analogic_changed.connect(_on_left_joy_analogic_changed)

func _on_left_joy_analogic_changed(value: Vector2, distance: float, angle: float, angle_clockwise: float, angle_not_clockwise: float) -> void:
	joy_movement = value
