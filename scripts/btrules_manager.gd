class_name BTManager
extends Node

@export var rules: Array[BTInfo]

var name2rule = {}

func _ready():
	for rule in rules:
		name2rule[rule.parent_step.name] = rule

func get_bt_info(name: String):
	return name2rule[name]

