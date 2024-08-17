extends Node3D
class_name Chair
enum ACTION {SIT, STAND}

signal state_changed(me)

var seated = false
@onready var current_player = null

func _ready():
	pass
	
func include_in_utility_search():
	return true
	
func sit(player):
	current_player = player
	if seated:
		return false
	seated = true
	return true
	
func stand(player):
	current_player = null
	if not seated:
		return false
	seated = false
	return true
	

func get_possible_actions(player):
	if seated and player == current_player:
		return [ACTION.STAND]
	elif seated and not player == current_player:
		return []
	return [ACTION.SIT]
	
func get_player_action(action: ACTION):
	match action:
		ACTION.SIT: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.SIT
		ACTION.STAND: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.STAND
		
func get_action_description(action: ACTION):
	match action:
		ACTION.SIT: return "Sit Down"
		ACTION.STAND: return "Stand Up"
		
func get_action_adv(action: ACTION):
	var adv = GLOBAL_DEFINITIONS.ObjectAdvertisement.new()
	match action:
		ACTION.SIT: adv.comfort += 0.5
	return adv
		
func act(action: ACTION, player):
	var res = true
	match action:
		ACTION.SIT: 
			res =  sit(player)
		ACTION.STAND: 
			res = stand(player)
		
	state_changed.emit(self)
	return res
	

func get_type():
	return GLOBAL_DEFINITIONS.OBJECTS.CHAIR
