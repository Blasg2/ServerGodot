extends BaseNetInput
class_name PlayerInputFPS

@export var mouse_sensitivity: float = 0.7
@export var hud: CanvasGroup

@onready var camera: Camera3D = $"../Head/Camera3D"

var is_setup: bool = false
var override_mouse: bool = false

var mouse_rotation: Vector2 = Vector2.ZERO
var look_angle: Vector2 = Vector2.ZERO
var movement: Vector3 = Vector3.ZERO
var jump: bool = false

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		override_mouse = false

func _input(event: InputEvent) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if !is_multiplayer_authority(): return

	if event is InputEventMouseMotion:
		mouse_rotation.y += event.relative.x * mouse_sensitivity
		mouse_rotation.x += event.relative.y * mouse_sensitivity

	if event.is_action_pressed("escape"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		override_mouse = true

func _gather():
	if !is_setup:
		setup()

	movement = Vector3(
		Input.get_axis("move_west", "move_east"),
		0,
		Input.get_axis("move_north", "move_south")
	)
	jump = Input.is_action_pressed("move_jump")

	if override_mouse:
		look_angle = Vector2.ZERO
		mouse_rotation = Vector2.ZERO
	else:
		look_angle = Vector2(-mouse_rotation.y, -mouse_rotation.x)
		mouse_rotation = Vector2.ZERO

func setup():
	is_setup = true
	camera.current = true
	hud.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
