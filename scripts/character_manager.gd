class_name CharacterManager
extends Node

@export var player_controlled_character: String

var current_view_player_idx: int
var players: Array

func register(player):
	if player.name == player_controlled_character:
		current_view_player_idx = players.size()
	players.append(player)
	
func _process(delta):
	if Input.is_action_just_pressed("switch_player_view"):
		players[current_view_player_idx].get_node("ControllablePlayer/UI").hide()
		if current_view_player_idx + 1 <= players.size()-1:
			current_view_player_idx += 1
		else:
			current_view_player_idx = 0
		players[current_view_player_idx].get_node("ControllablePlayer/CameraBase/CameraRot/SpringArm3D/Camera3D").make_current()
		players[current_view_player_idx].get_node("ControllablePlayer/UI").show()
		DebugView.filter_by_player = players[current_view_player_idx]
			
		
		
