extends CanvasLayer

signal action1

@onready var world: Node = get_node("/root/World")
@onready var action := $Buttons/Action


func _ready() -> void:
	action.hide()
	
	$Temperatura.text= "%s °C" % world.temp_c
	world.WeatherRefresh.connect(weather)
	control.joystick.emit($LeftJoy, $RightJoy)
	
func weather(temp)->void:
	$Temperatura.text= "%s °C" % temp


func _on_action_pressed() -> void:
	action1.emit()
