extends CharacterBody3D
@export var speed = 5.0
@export var jump_strength = 5.0

@onready var input := $Input as PlayerInputFPS
@onready var MpSync := $MultiplayerSynchronizer
@onready var mesh := $Mesh
@onready var state_sync: StateSynchronizer = $StateSynchronizer

var hudLoad := load("res://characters/hud.tscn")
var gravity = ProjectSettings.get_setting(&"physics/3d/default_gravity")
var username: String
var CurrentLevel: String

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		afkRefresh.rpc_id(1, true)
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		afkRefresh.rpc_id(1, false)

@rpc ("any_peer", "reliable", "call_remote")
func afkRefresh(afk: bool)->void:
	if afk:
		$Afk.text = "AFK"
	else:
		$Afk.text = ""

func _ready():
	if input.is_multiplayer_authority() or multiplayer.is_server():
		var hud = hudLoad.instantiate()
		add_child(hud)
		get_node("/root/World/Loading").hide()
	
	if multiplayer.is_server():
		NetworkTime.on_tick.connect(_server_tick)


func _server_tick(_delta: float, _tick: int) -> void:
	if process_mode == Node.PROCESS_MODE_DISABLED:
		return
		
	if is_on_floor():
		if input.jump:
			velocity.y = jump_strength
	else:
		velocity.y -= gravity * NetworkTime.ticktime

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
	var flat_vel = Vector3(velocity.x, 0, velocity.z)
	if flat_vel.length() > 0.1:
		var target_angle = atan2(-flat_vel.z, flat_vel.x)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_angle, 10.0 * delta)

func get_player_id() -> int:
	return input.get_multiplayer_authority()
