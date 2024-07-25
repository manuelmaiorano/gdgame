extends Node3D

var going = false
	
func get_next_actions(far_objects: Dictionary, close_objects: Array, reached: bool, motion: Vector2, current_car):
	var agent_input = GLOBAL_DEFINITIONS.AgentInput.new()
	if reached:
		going = false
	for idx in close_objects.size():
		var action_info = close_objects[idx]
		match action_info.object.get_object_id():
			GLOBAL_DEFINITIONS.OBJECTS.PISTOL: 
				match action_info.object_action_id:
					Pistol.ACTION.PICK: agent_input.action_id = idx + 1
							
	if going == true:
		return agent_input
	for object: Node in far_objects.keys():
		match  object.get_object_id():
			GLOBAL_DEFINITIONS.OBJECTS.PISTOL: pass
			GLOBAL_DEFINITIONS.OBJECTS.CAR: 
				agent_input.going = true
				agent_input.next_pos = far_objects[object]
				going = true
	return agent_input
