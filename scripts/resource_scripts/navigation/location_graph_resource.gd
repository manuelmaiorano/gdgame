extends Resource
class_name LocationGraph

const OUT_NODE_NAME: StringName = "out"

enum OUT_STRATEGY {SEARCH, NONE}

@export var out_strategy: OUT_STRATEGY
@export var links: Array[LocationGraphLink]


