extends Resource
class_name PlanStep

enum STEP_TYPE {
	#complex
	GOTO_LOCATION, SEARCH_OBJ_ACTION_UTILITY, SEARCH_OBJ_ACTION, EXECUTE_LINK_ACTION, CUSTOM,
	#base
	GOTO_POSITION, EXECUTE_OBJ_ACTION, EXECUTE_OBJ_ACTION_STORED, EXECUTE_OBJ_ACTION_BY_ACTION_TYPE, EXECUTE_NPC_ACTION, QUERY_INVENTORY, QUERY_CLOSE, EQUIP,
	QUERY_PERSON, AIM_AT, UNEQUIP, QUERY_ACTION_UITILITY, QUERY_NAVIGATION, BROADCAST}

@export var name: String
@export var step_type: STEP_TYPE
@export var object_action_id: int
@export var object_action_type: int
@export var player_action_id: GLOBAL_DEFINITIONS.CHARACTER_ACTION
@export var position: Vector3
@export var should_run: bool
@export var use_stored_pos: bool
@export var location: LocationName
@export var crossing_rule: LocationGraphLink.CROSSING_RULE
@export var link_end_position: Vector3
@export var obj_type: GLOBAL_DEFINITIONS.OBJECTS
@export var who: String
@export var property_name: String
@export var params: Array

func copy_params(old: PlanStep):
	self.step_type = old.step_type
	self.object_action_id = old.object_action_id
	self.object_action_type = old.object_action_type
	self.player_action_id = old.player_action_id
	self.position = old.position
	self.use_stored_pos = old.use_stored_pos
	self.location = old.location
	#self.should_run = old.should_run
	self.crossing_rule = old.crossing_rule
	self.link_end_position = old.link_end_position
	self.obj_type = old.obj_type
	self.who = old.who

func copy_params_from_parent_step(parent: PlanStep):
	
	if parent.obj_type != GLOBAL_DEFINITIONS.OBJECTS.NONE:
		self.obj_type = parent.obj_type
		self.object_action_type = parent.object_action_type
	if parent.player_action_id != GLOBAL_DEFINITIONS.CHARACTER_ACTION.NONE:
		self.player_action_id = parent.player_action_id
	if parent.location != null:
		self.location = parent.location
	self.should_run = parent.should_run
