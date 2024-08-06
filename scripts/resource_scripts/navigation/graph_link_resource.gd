extends Resource
class_name LocationGraphLink

enum CROSSING_RULE {NONE, DOOR, CROSSWALK}

@export var source_name: StringName
@export var dest_name: StringName
@export var start_position: Vector3
@export var end_position: Vector3
@export var crossing_rule: CROSSING_RULE
@export var cost: float
