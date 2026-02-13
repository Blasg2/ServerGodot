extends CharacterBody3D

@export var speed = 5.0
@export var jump_strength = 5.0

@onready var display_name := $DisplayNameLabel3D as Label3D
@onready var input := $Input as PlayerInputFPS
@onready var tick_interpolator := $TickInterpolator as TickInterpolator
@onready var head := $Head as Node3D
@onready var hud := $HUD as CanvasGroup

var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")

func _ready():
	display_name.text = name
	hud.hide()

	NetworkTime.on_tick.connect(_tick)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

func _tick(dt: float, tick: int):
	pass

func _after_tick_loop():
	pass

func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	 # Skip simulation if prediction confidence is zero
	if is_zero_approx(input.confidence):
		$RollbackSynchronizer.ignore_prediction(self)
		return
	# Gravity
	_force_update_is_on_floor()
	if is_on_floor():
		if input.jump:
			velocity.y = jump_strength
	else:
		velocity.y -= gravity * delta

	# Handle look left and right
	rotate_object_local(Vector3(0, 1, 0), input.look_angle.x)

	# Handle look up and down
	head.rotate_object_local(Vector3(1, 0, 0), input.look_angle.y)

	head.rotation.x = clamp(head.rotation.x, -1.57, 1.57)
	head.rotation.z = 0
	head.rotation.y = 0

	# Apply movement
	var input_dir = input.movement
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.z)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	# move_and_slide assumes physics delta
	# multiplying velocity by NetworkTime.physics_factor compensates for it
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
	
