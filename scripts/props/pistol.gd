extends RigidBody3D
class_name Pistol
enum ACTION {PICK}

signal state_changed(me)

var picked = false

func pick():
	if picked:
		return
	picked = true
	freeze = true
	$CollisionShape3D.disabled = true
	self.hide()
	

func get_possible_actions(player_id):
	if picked:
		return []
	return [ACTION.PICK]
	
func get_player_action(action: ACTION):
	match action:
		ACTION.PICK: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.PICK
		
func get_action_description(action: ACTION):
	match action:
		ACTION.PICK: return "Pick the gun"

func act(action: ACTION, player_id):
	match action:
		ACTION.PICK: pick()
	state_changed.emit(self)

func get_object_id():
	return GLOBAL_DEFINITIONS.OBJECTS.PISTOL
