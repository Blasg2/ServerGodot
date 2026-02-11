extends Camera3D

var ssCount = 1

func _ready():
	var dir = DirAccess.open("C:/")
	dir.make_dir("screenshots")
	
	dir = DirAccess.open("C:/screenshots")
	for n in dir.get_files():
		ssCount += 1

func _input(event):
	if event.is_action_pressed("screenshot"):
		screenshot()

func screenshot():
	await RenderingServer.frame_post_draw
	var viewport = get_viewport()
	var img = viewport.get_texture().get_image()
	img.save_png("C:/screenshots/screenshot_%d.png" % ssCount)
	ssCount += 1
