extends Node3D

signal state_changed(me)

@export var which_floor = 0

var pl_pos: Node3D = null

enum ACTION {CALL, GOTO}


func get_possible_actions(pl_pos: Node3D = null):
	var floor = get_pl_floor(pl_pos)
	if floor == which_floor and can_go(pl_pos):
		return [ACTION.GOTO]
	if floor != which_floor:
		return [ACTION.CALL]
	
func get_player_action(action: ACTION):
	match action:
		ACTION.CALL: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.NONE
		ACTION.GOTO: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.NONE
		
func get_action_description(action: ACTION):
	match action:
		ACTION.CALL: return "Call the elevator"
		ACTION.GOTO: return "Go to floor %d" % action 

func act(action: ACTION):
	match action:
		ACTION.CALL: call_elevator()
		ACTION.GOTO: goto_floor(action)
	state_changed.emit(self)

func call_elevator():
	pass

func goto_floor(floor):
	pass

func can_go(pl_pos):
	var origTrans: Transform3D = get_child(get_pl_floor(pl_pos)).global_transform 
	var openingDir: Vector3 = origTrans.basis * Vector3(0, 0, 1)
	var player_dir: Vector3 = pl_pos.global_transform.origin - origTrans.origin
	return (player_dir).dot(openingDir) > 0
	
func get_pl_floor(pl_pos: Node3D):
	var area_origins = find_children("areaOrigin")
	return area_origins.map(func(origin: Node3D): return (pl_pos.position-origin.position).abs() ).min().name

		
	
