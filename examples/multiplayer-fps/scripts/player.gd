extends CharacterBody3D

@export var speed = 5.0
@export var jump_strength = 5.0

@onready var display_name := $DisplayNameLabel3D as Label3D
@onready var input := $Input as PlayerInputFPS
@onready var head := $Head as Node3D
@onready var hud := $HUD as CanvasGroup
@onready var MpSync := $MultiplayerSynchronizer
@onready var rollback: RollbackSynchronizer = $RollbackSynchronizer


var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")

var username: String 
var CurrentLevel: String

func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _ready():
	display_name.text = name
	hud.hide()
	await get_tree().process_frame
	input.set_multiplayer_authority(int(name))	
	$RollbackSynchronizer.process_settings()

func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if process_mode == Node.PROCESS_MODE_DISABLED:
		return
	_force_update_is_on_floor()
	if is_on_floor():
		if input.jump:
			velocity.y = jump_strength
	else:
		velocity.y -= gravity * delta

	rotate_object_local(Vector3(0, 1, 0), input.look_angle.x)

	head.rotate_object_local(Vector3(1, 0, 0), input.look_angle.y)
	head.rotation.x = clamp(head.rotation.x, -1.57, 1.57)
	head.rotation.z = 0
	head.rotation.y = 0

	var direction = (transform.basis * Vector3(input.movement.x, 0, input.movement.z)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity

func get_player_id() -> int:
	return input.get_multiplayer_authority()
