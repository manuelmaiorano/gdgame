extends Node3D
class_name Person

enum ACTION {INTERACT}

signal state_changed(me)

@onready var character = self.get_parent()

func interact():
	return true

func include_in_utility_search():
	return true
	
func get_action_adv(action: ACTION):
	var adv = GLOBAL_DEFINITIONS.ObjectAdvertisement.new()
	match action:
		ACTION.INTERACT: adv.social += 0.5
	return adv

func get_type():
	return GLOBAL_DEFINITIONS.OBJECTS.PERSON
	
func get_item_desc():
	return "Person"
	
func get_possible_actions(player):
	if player == character:
		return []
	return [ACTION.INTERACT]
	
func get_player_action(action: ACTION):
	match action:
		ACTION.INTERACT: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.TALK
		
func get_action_description(action: ACTION):
	match action:
		ACTION.INTERACT: return "Interact"

func act(action: ACTION, player_id):
	var outcome = true
	match action:
		ACTION.INTERACT: outcome = interact()
	state_changed.emit(self)
	return outcome
