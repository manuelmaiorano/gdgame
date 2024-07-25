extends Node3D
class_name Chair
enum ACTION {SIT, STAND}

signal state_changed(me)

var seated = false

func sit():
	if seated:
		return
	seated = true
	
func stand():
	if not seated:
		return
	seated = false
	

func get_possible_actions():
	if seated:
		return [ACTION.STAND]
	return [ACTION.SIT]
	
func get_player_action(action: ACTION):
	match action:
		ACTION.SIT: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.SIT
		ACTION.STAND: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.STAND
		
func get_action_description(action: ACTION):
	match action:
		ACTION.SIT: return "Sit Down"
		ACTION.STAND: return "Stand Up"
		
func act(action: ACTION):
	match action:
		ACTION.SIT: sit()
		ACTION.STAND: stand()
		
	state_changed.emit(self)
