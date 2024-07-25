extends Label

var player = null
# Called when the node enters the scene tree for the first time.
func _ready():
	player = get_parent().get_parent().find_child("ch_def1")
	print(get_parent())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	text = "FPS: %d \n" % int(Engine.get_frames_per_second()) + "%f \n %f \n %f" % [player.global_position.x, player.global_position.y, player.global_position.z]
