extends RigidBody3D
class_name Pistol
enum ACTION {PICK}

signal state_changed(me)

var picked = false

func pick():
	if picked:
		return false
	picked = true
	freeze = true
	$CollisionShape3D.disabled = true
	self.hide()
	return true

func include_in_utility_search():
	return false

func get_type():
	return GLOBAL_DEFINITIONS.OBJECTS.PISTOL
	
func get_item_desc():
	return "Gun"
	
func get_possible_actions(player):
	if picked:
		return []
	return [ACTION.PICK]
	
func get_player_action(action: ACTION):
	match action:
		ACTION.PICK: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.PICK
		
func get_action_description(action: ACTION):
	match action:
		ACTION.PICK: return "Pick the gun"

func act(action: ACTION, player):
	var outcome = true
	match action:
		ACTION.PICK: outcome = pick()
	state_changed.emit(self)
	return outcome

func get_object_id():
	return GLOBAL_DEFINITIONS.OBJECTS.PISTOL

func equip():
	self.show()

func unequip():
	self.hide()
