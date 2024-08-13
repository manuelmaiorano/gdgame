extends Node

class_name GLOBAL_DEFINITIONS

const MIN_DISTANCE_TO_EXECUTE_ACTION = 0.2

enum CHARACTER_ACTION {NONE, SIT, STAND, THROW, OPEN, PICK, ENTER_CAR, EXIT_CAR, PUNCH, RUN, KICK, JUMP, TALK, SHOOT}

enum OBJECTS {NONE, DOOR, PISTOL, CAR, CHAIR, COUCH, WINDOW, ELEVATOR, PERSON}

enum AI_FEEDBACK {DONE, FAILED, RUNNING}

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
	var going: bool
	var q_to
	var shoot_target


class ObjectAdvertisement:
	#physical
	var hunger: float
	var comfort: float
	var hygiene: float
	var bladder: float
	#mental
	var energy: float
	var fun: float
	var social: float
	var room: float


class InventoryItem:
	var object
	var type: OBJECTS

const INVENTORY_SPACE = 8
