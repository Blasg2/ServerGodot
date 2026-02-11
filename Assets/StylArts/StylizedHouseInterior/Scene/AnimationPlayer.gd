extends AnimationPlayer

# Export the variable to make it editable in the editor
@export var animation_name: String = "new_animation"

func _ready():
	# Connect the animation_finished signal to the _on_animation_finished method
	connect("animation_finished", Callable(self, "_on_animation_finished"))
	
	# Play the animation using the variable
	play(animation_name)

func _on_animation_finished(anim_name):
	if anim_name == animation_name:
		stop()
		get_tree().quit()
