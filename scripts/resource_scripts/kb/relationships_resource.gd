extends Resource
class_name Relationships

@export var relationships: Dictionary

func get_rel_value(name, rel_property):
    if not relationships.has(name):
        return 0.5 
    return relationships[name].get(rel_property)