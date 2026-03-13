extends TextureRect

@onready var userN := $"../User"


func _on_hal_pressed() -> void:
	userN.text = "Gui"
	$Hal.modulate = Color.RED
	clean_menu_select($Hal)
	

func _on_gariba_pressed() -> void:
	userN.text = "Gariba"
	$Gariba.modulate = Color.RED
	clean_menu_select($Gariba)
	
	
func _on_iusaf_pressed() -> void:
	userN.text = "Iusaf"
	$Iusaf.modulate = Color.RED
	clean_menu_select($Iusaf)
	
	
func _on_lil_pressed() -> void:
	userN.text = "Lil"
	$Lil.modulate = Color.RED
	clean_menu_select($Lil)
	
	
func _on_joj_pressed() -> void:
	userN.text = "Joj"
	$Joj.modulate = Color.RED
	clean_menu_select($Joj)
	

#CLEAN THE MENU SELECTION
func clean_menu_select(user: Node)->void:
	for c in get_children():
		if c != user:
			c.modulate = Color(0,0,0,0)
