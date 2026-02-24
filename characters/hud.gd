extends CanvasLayer


@onready var world = 	get_node("/root/World")


func _ready() -> void:
	$Temperatura.text= "%s °C" % world.temp_c
	world.WeatherRefresh.connect(weather)
	control.joystick.emit($LeftJoy, $RightJoy)
	
func weather(temp)->void:
	$Temperatura.text= "%s °C" % temp
