extends CharacterBody3D
@export var speed = 5.0
@export var jump_strength = 5.0

@onready var input := $Input as PlayerInputFPS
@onready var MpSync := $MultiplayerSynchronizer
@onready var rollback: RollbackSynchronizer = $RollbackSynchronizer
@onready var mesh := $Mesh

var hudLoad := load("res://characters/hud.tscn")
var pending_teleport: Vector3 = Vector3.INF
var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")
var username: String
var CurrentLevel: String

func server_teleport(pos: Vector3) -> void:
	pending_teleport = pos

func _ready():
	if input.is_multiplayer_authority() or multiplayer.is_server():
		var hud = hudLoad.instantiate()
		add_child(hud)

func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if pending_teleport != Vector3.INF:
		global_position = pending_teleport
		velocity = Vector3.ZERO
		pending_teleport = Vector3.INF
		return

	_force_update_is_on_floor()

	if is_on_floor():
		if input.jump:
			velocity.y = jump_strength
	else:
		velocity.y -= gravity * delta

	var direction = Vector3(input.movement.x, 0, input.movement.z)
	direction = direction.rotated(Vector3.UP, input.camera_yaw)

	if direction.length() > 0.1:
		velocity.x = direction.normalized().x * speed
		velocity.z = direction.normalized().z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor

func _process(delta: float) -> void:
	if not input.is_multiplayer_authority():
		print("Remote %s pos: %s vel: %s" % [name, global_position, velocity])
	var flat_vel = Vector3(velocity.x, 0, velocity.z)
	if flat_vel.length() > 0.1:
		var target_angle = atan2(-flat_vel.z, flat_vel.x)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_angle, 10.0 * delta)

func _force_update_is_on_floor():
	var old_velocity = velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity

func get_player_id() -> int:
	return input.get_multiplayer_authority()
