extends Resource
class_name PlanStep

enum STEP_TYPE {
    #complex
    GOTO_LOCATION, SEARCH_OBJ_ACTION, EXECUTE_LINK_ACTION,
    #base
    GOTO_POSITION, EXECUTE_OBJ_ACTION, EXECUTE_OBJ_ACTION_BY_ACTION_ID, EXECUTE_NPC_ACTION}

@export var name: String
@export var step_type: STEP_TYPE
@export var object_id: int
@export var object_action_id: int
@export var player_action_id: GLOBAL_DEFINITIONS.CHARACTER_ACTION
@export var position: Vector3
@export var location: LocationName
@export var crossing_rule: LocationGraphLink.CROSSING_RULE
@export var link_end_position: Vector3