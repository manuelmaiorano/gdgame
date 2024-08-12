class_name BTManager
extends Node

@export var rules: Array[BTInfo]

var name2rule = {}


func _ready():
	for rule in rules:
		name2rule[rule.parent_step.name] = rule
	
	var bt_info = BTInfo.new()
	var plan = PlanStep.new()
	plan.step_type = PlanStep.STEP_TYPE.EQUIP
	bt_info.parent_step = plan
	name2rule["equip"] = bt_info

func get_bt_info(name: String):
	return name2rule[name]

