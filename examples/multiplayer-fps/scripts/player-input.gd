extends BaseNetInput
class_name PlayerInputFPS

@export var mouse_sensitivity: float = 0.7
@export var hud: CanvasGroup

@onready var camera: Camera3D = $"../Head/Camera3D"
@onready var _rollback_synchronizer := $"../RollbackSynchronizer" as RollbackSynchronizer

# Config variables
var is_setup: bool = false
var override_mouse: bool = false

# Input variables
var mouse_rotation: Vector2 = Vector2.ZERO
var look_angle: Vector2 = Vector2.ZERO
var movement: Vector3 = Vector3.ZERO
var jump: bool = false
var confidence: float = 1.0

func _ready():
	super()
	NetworkRollback.after_prepare_tick.connect(_predict)

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

	var mx = Input.get_axis("move_west", "move_east")
	var mz = Input.get_axis("move_north", "move_south")
	movement = Vector3(mx, 0, mz)
	jump = Input.is_action_pressed("move_jump")

	if override_mouse:
		look_angle = Vector2.ZERO
		mouse_rotation = Vector2.ZERO
	else:
		look_angle = Vector2(-mouse_rotation.y, -mouse_rotation.x)
		mouse_rotation = Vector2.ZERO

func _predict(_tick: int):
	if not _rollback_synchronizer.is_predicting():
		confidence = 1.0
		return

	if not _rollback_synchronizer.has_input():
		confidence = 0.0
		return

	var decay_time := NetworkTime.seconds_to_ticks(0.15)
	var input_age := _rollback_synchronizer.get_input_age()

	confidence = input_age / float(decay_time)
	confidence = clampf(1.0 - confidence, 0.0, 1.0)

	movement *= confidence
	look_angle *= confidence

func setup():
	is_setup = true
	camera.current = true
	hud.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
