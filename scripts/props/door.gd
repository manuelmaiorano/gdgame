extends Node3D

signal state_changed(me)

@export var locked = false
@export var opened = false

var collision_shape : CollisionShape3D = null
var collision_shape2 : CollisionShape3D = null
var pl_pos: Node3D = null

enum ACTION {OPEN, CLOSE, LOCK, UNLOCK}

func iterate(node):
	if node != null and  node is StaticBody3D and node.get_parent_node_3d().name.contains("door"):
		for child in node.get_children():
			print(node.get_parent_node_3d().name)
			if child is CollisionShape3D:
				if collision_shape != null:
					collision_shape2 = child
					return
				collision_shape = child
	for child in node.get_children():
		iterate(child)
		
func _ready():
	iterate(self)

func get_possible_actions(pl_pos: Node3D = null):
	if opened:
		return [ACTION.CLOSE]
	if locked:
		if can_lock():
			return [ACTION.UNLOCK]
		else:
			return []
		
	if can_lock():
		return [ACTION.LOCK, ACTION.OPEN]
	else:
		return [ACTION.OPEN]
	
func get_player_action(action: ACTION):
	match action:
		ACTION.OPEN: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.OPEN
		ACTION.CLOSE: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.NONE
		ACTION.LOCK: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.NONE
		ACTION.UNLOCK: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.NONE
		
func get_action_description(action: ACTION):
	match action:
		ACTION.OPEN: return "Open the door"
		ACTION.CLOSE: return "Close the door"
		ACTION.LOCK: return "Lock the door"
		ACTION.UNLOCK: return "Unlock the door"

func open():
	if opened or locked:
		return
	$"AnimationPlayer".play("open")
	collision_shape.disabled = true
	if collision_shape2 != null:
		collision_shape2.disabled = true
	delayed_state_change(false)
	opened = true

func close():
	if not opened:
		return
	$"AnimationPlayer".play_backwards("open")
	collision_shape.disabled = true
	if collision_shape2 != null:
		collision_shape2.disabled = true
	delayed_state_change(false)
	opened = false

func lock():
	if opened or locked: return
	locked = true
	
func unlock():
	if opened or not locked: return
	locked = false

func act(action: ACTION):
	match action:
		ACTION.OPEN: open()
		ACTION.CLOSE: close()
		ACTION.LOCK: lock()
		ACTION.UNLOCK: unlock()
	state_changed.emit(self)
		
func _on_area_3d_body_entered(body):
	pass
	
func delayed_state_change(value: bool):
	await get_tree().create_timer(1.0).timeout
	collision_shape.disabled = value
	if collision_shape2 != null:
		collision_shape2.disabled = value
	
func can_lock():
	if pl_pos == null:
		return false
	var origTrans: Transform3D = find_child("areaOrigin*").global_transform 
	var openingDir: Vector3 = origTrans.basis * Vector3(0, 0, 1)
	var player_dir: Vector3 = pl_pos.global_transform.origin - origTrans.origin
	return (player_dir).dot(openingDir) > 0
	
func set_player(pl):
	pl_pos = pl
	
