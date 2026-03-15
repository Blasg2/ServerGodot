extends Node
class_name PlayerInputFPS

var is_setup: bool = false
var override_mouse: bool = false
var movement: Vector3 = Vector3.ZERO
var jump: bool = false
var camera_yaw: float = 0.0
var joy_movement: Vector2 = Vector2.ZERO

func _ready():
	if is_multiplayer_authority():
		NetworkTime.before_tick_loop.connect(_gather)
		control.joystick.connect(setJoy)

func _gather():
	if not is_multiplayer_authority():
		return
	
	if not is_setup:
		setup()
	
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

func _input(event: InputEvent) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("escape"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			override_mouse = true
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			override_mouse = false

func setup():
	is_setup = true
	var cam = get_node_or_null("../SpringArmPivot/Camera3D")
	if cam:
		cam.current = true
	if not OS.has_feature("mobile"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func setJoy(a, _b) -> void:
	a.analogic_changed.connect(_on_left_joy_analogic_changed)

func _on_left_joy_analogic_changed(value: Vector2, _distance: float, _angle: float, _angle_clockwise: float, _angle_not_clockwise: float) -> void:
	joy_movement = value
