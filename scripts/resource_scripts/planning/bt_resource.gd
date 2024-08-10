extends Resource
class_name BTInfo

enum BTNodeType {SEQUENCE, SELECTOR, TASK, RETRY, QUERY}

@export var parent_step: PlanStep
@export var children_step_names: Array[String]
@export var type: BTNodeType
@export var attempts: int