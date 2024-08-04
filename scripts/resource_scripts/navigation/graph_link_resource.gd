extends Resource
class_name LocationGraphLink

enum CROSSING_RULE {DOOR, CROSSWALK}


@export var dest_name: String
@export var link_start_position: Vector3
@export var link_end_position: Vector3
@export var link_crossing_rule: CROSSING_RULE
@export var link_cost: float
