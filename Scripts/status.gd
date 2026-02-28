extends Node

@onready var req: HTTPRequest = $HTTPRequest

signal WeatherRefresh(temp)

var temp_c := 0.0:
	set(value):
		temp_c = value
		WeatherRefresh.emit(temp_c)
		
var t: Timer


func _notification(what):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
			

func _ready() -> void:
	var args := OS.get_cmdline_args()
	if "--server" in args:
		req.request_completed.connect(_on_weather_done)
		t = Timer.new()
		add_child(t)
		t.timeout.connect(fetch_bh_weather)
		fetch_bh_weather()	
		
		

func fetch_bh_weather() -> void:
	req.request("https://api.open-meteo.com/v1/forecast?latitude=-19.9167&longitude=-43.9345&current=temperature_2m&timezone=America%2FSao_Paulo")

func _on_weather_done(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code < 200 or response_code >= 300:
		return
	var d = JSON.parse_string(body.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY:
		return
	temp_c = float(d["current"]["temperature_2m"])
	t.start(1800)
	
	
