class_name DebugManager
extends Node

var custom_text = ""
var filter_by_player = null

func print_debug_info(info: String, player):
	if player == filter_by_player:
		custom_text = info

func append_debug_info(info: String, player):
	if player == filter_by_player:
		custom_text += info

func clear_debug_info(player):
	custom_text = ""
	
func _process(delta):
	$Label.text = "FPS: %d \n" % int(Engine.get_frames_per_second()) +  "\n" + custom_text
