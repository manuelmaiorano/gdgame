class_name CharacterManager
extends Node

@export var player_controlled_character: String
@export var player_view_character: String

var current_view_player_idx: int
var players: Array

func register(player):
	if player.name == player_view_character:
		current_view_player_idx = players.size()
	players.append(player)
	players[current_view_player_idx].get_node("ControllablePlayer/CameraBase/CameraRot/SpringArm3D/Camera3D").make_current()
	players[current_view_player_idx].get_node("ControllablePlayer/UI").show()
	DebugView.filter_by_player = players[current_view_player_idx]

func get_by_name(name):
	for player in players:
		if player.name == name:
			return player
	return null
	
func _process(delta):
	if Input.is_action_just_pressed("switch_player_view"):
		switch()
			
func switch():
	players[current_view_player_idx].get_node("ControllablePlayer/UI").hide()
	if current_view_player_idx + 1 <= players.size()-1:
		current_view_player_idx += 1
	else:
		current_view_player_idx = 0
	players[current_view_player_idx].get_node("ControllablePlayer/CameraBase/CameraRot/SpringArm3D/Camera3D").make_current()
	players[current_view_player_idx].get_node("ControllablePlayer/UI").show()
	DebugView.filter_by_player = players[current_view_player_idx]
		
