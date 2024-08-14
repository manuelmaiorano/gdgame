extends Resource
class_name BTInfo

enum BTNodeType {SEQUENCE, SELECTOR, TASK, RETRY, NAV}

@export var parent_step: PlanStep
@export var children_steps: Array[PlanStep]
@export var type: BTNodeType
@export var attempts: int
