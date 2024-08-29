class_name BTManager
extends Node

@export var rules: Array[BTInfo]
var script_rules: RULES

var name2rule = {}


func _ready():
	for rule in rules:
		name2rule[rule.parent_step.name] = rule
	script_rules = RULES.new()

func build_bt(step: PlanStep):
	var bt =  script_rules.build_bt(step)
	return bt

func get_bt_info(name: String):
	return name2rule[name]

