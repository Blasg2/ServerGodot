extends MeshInstance3D
@onready var player := $".."
@onready var world := get_node("/root/World")
@onready var raycast := $"../Camera3D/RayCast3D"
@onready var cross := $"../../Controls/Cross"

var npc: bool = false

func _ready() -> void:
	await get_tree().process_frame
	
	
	if $"..".username == "alice":
		self.mesh.radius = 0.5
func _process(delta: float) -> void:
	if not player.is_local_player:
		return
		#
	#if Input.is_action_just_pressed("esc"):
		#world.rpc_id(1, "change_player_level", player.player_id, "Bola")
	#
		
	if Input.is_action_just_pressed("tab") and npc:
		if $"../../Controls/LineEdit".visible:
			$"../../Controls/AutoSizeRichTextLabel".hide()
			$"../../Controls/LineEdit".hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			$"..".set_physics_process(true)
			$"..".set_process_input(true)
			
		else:
			$"../../Controls/AutoSizeRichTextLabel".text = ""
			$"../../Controls/AutoSizeRichTextLabel".show()
			$"../../Controls/LineEdit".show() 
			$"../../Controls/LineEdit".grab_focus()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			$"..".set_physics_process(false)
			$"..".set_process_input(false)
		
		
	if raycast.is_colliding():
		npc = true
		cross.modulate = Color.CRIMSON
	else:
		npc= false
		cross.modulate = Color.WHITE
