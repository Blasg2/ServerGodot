extends MeshInstance3D


func _ready() -> void:
	await get_tree().process_frame
	
	
	if $"..".username == "alice":
		self.mesh.radius = 0.5
