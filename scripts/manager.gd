extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	var player = get_parent().find_child("ch_def*")
	player.controlled_by_player = true
	player.get_node("ControllablePlayer/CameraBase/CameraRot/SpringArm3D/Camera3D").make_current()
	player.get_node("ControllablePlayer").show()
	get_parent().find_child("ch_male").controlled_by_player = false
	get_parent().find_child("ch_male").get_node("ControllablePlayer/UI").hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
