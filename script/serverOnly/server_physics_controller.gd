# res://script/serverOnly/server_physics_controller.gd
class_name ServerPhysicsController
extends Node

var physics_body: CharacterBody3D
var owner_id: int = -1

## Server-authoritative stats
var move_speed: float = 10.0
var jump_velocity: float = 10.0
var gravity: float = 21.0

func initialize(body: CharacterBody3D, player_id: int) -> void:
	physics_body = body
	owner_id = player_id

func _ready() -> void:
	if not multiplayer.is_server():
		set_physics_process(false)
		queue_free()

func _physics_process(delta: float) -> void:
	if not physics_body:
		return
	
	if not physics_body.is_on_floor():
		physics_body.velocity.y -= gravity * delta
	
	physics_body.move_and_slide()

func apply_movement(input_dir: Vector2, jump: bool) -> void:
	if not physics_body:
		return
	
	var move_direction = (physics_body.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if move_direction != Vector3.ZERO:
		physics_body.velocity.x = move_direction.x * move_speed
		physics_body.velocity.z = move_direction.z * move_speed
	else:
		physics_body.velocity.x = 0
		physics_body.velocity.z = 0
	
	if jump and physics_body.is_on_floor():
		physics_body.velocity.y = jump_velocity

func verify_authority(sender_id: int) -> bool:
	if sender_id != owner_id:
		push_warning("Player %d tried to control player %d" % [sender_id, owner_id])
		return false
	return true

func set_stats(stats: Dictionary) -> void:
	if stats.has("move_speed"): move_speed = stats.move_speed
	if stats.has("jump_velocity"): jump_velocity = stats.jump_velocity
	if stats.has("gravity"): gravity = stats.gravity
