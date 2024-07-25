extends Node

class_name GLOBAL_DEFINITIONS
enum CHARACTER_ACTION {NONE, SIT, STAND, THROW, OPEN, PICK, ENTER_CAR, EXIT_CAR}

enum OBJECTS {DOOR, PISTOL, CAR, CHAIR, COUCH, WINDOW, ELEVATOR}

class AgentInput:
	var motion: Vector2
	var jumping: bool
	var running: bool
	var shooting: bool
	var aiming: bool
	var punching: bool
	var kicking: bool
	var talking: bool
	var action_id: int
	var next_pos: Vector3
	var going: bool
	
	
class AgentPerceptions:
	var actions: Array
