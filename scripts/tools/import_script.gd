@tool # Needed so it runs in editor.
extends EditorScenePostImport

var root = null
var door_script = null
var chair_script = null
var sofa_script = null
var door_regex = null
var window_script = null
# This sample changes all node names.
# Called right after the scene is imported and gets the root node.
func _post_import(scene):
	# Change all node names to "modified_[oldnodename]"
	root = scene
	door_script = load("res://door.gd")
	chair_script = load("res://Chair.gd")
	sofa_script = load("res://sofa.gd")
	window_script = load("res://window.gd")
	print(root)
	door_regex = RegEx.new()
	door_regex.compile("\\(([p|n])(\\d+)\\)")
	iterate(scene)
	return scene # Remember to return the imported scene

# Recursive function that is called on every node
# (for demonstration purposes; EditorScenePostImport only requires a `_post_import(scene)` function).
func iterate(node: Node):
	if node != null:
		if node.name.contains("Window"):
			print("%s" % node.name)
			var transl = 1.0
			var result: RegExMatch = door_regex.search(node.find_child("windowBottom*").name)
			if result:
				var value = result.get_string(2).to_float()
				var sign = result.get_string(1)
				if sign == "p":
					transl = value / 100
				else:
					transl = -value / 100
					
			var area = Area3D.new()
			var collision_shape = CollisionShape3D.new()
			var box_shape = BoxShape3D.new()
			
			var animation_player : AnimationPlayer = AnimationPlayer.new()
			var animation: Animation = Animation.new()
			animation.add_track(Animation.TYPE_POSITION_3D)
			
			animation.track_set_path(0, NodePath("%s:position" % node.find_child("windowBottom*").name))
			animation.track_insert_key(0, 0.0, node.find_child("windowBottom*").transform.origin)
			animation.track_insert_key(0, 1.0, node.find_child("windowBottom*").transform.origin + Vector3(0, transl, 0))
			
			collision_shape.shape = box_shape
			node.add_child(area)
			node.add_child(Node3D.new())
			area.add_child(collision_shape)
			area.set_owner(root)
			collision_shape.set_owner(root)
			var area_origin: Node3D = node.find_child("areaOrigin*")
			if area_origin != null:
				area.transform.origin = area_origin.transform.origin
			
			node.add_child(animation_player)
			animation_player.set_owner(root)
			animation_player.name = "AnimationPlayer"
			var animation_library = AnimationLibrary.new()
			animation_library.add_animation("open", animation)
			animation_player.add_animation_library("", animation_library)
			
			node.set_script(window_script)
		if node.name.contains("doubleDoor"):
			print("%s" % node.name)
			var angleL = 120.0
			var result: RegExMatch = door_regex.search(node.find_child("doorLeft*").name)
			if result:
				var value = result.get_string(2).to_float()
				var sign = result.get_string(1)
				if sign == "p":
					angleL = value
				else:
					angleL = -value
					
			var angleR = 120.0
			result = door_regex.search(node.find_child("doorRight*").name)
			if result:
				var value = result.get_string(2).to_float()
				var sign = result.get_string(1)
				if sign == "p":
					angleR = value
				else:
					angleR = -value
				
			var area = Area3D.new()
			var collision_shape = CollisionShape3D.new()
			var box_shape = BoxShape3D.new()
			
			var animation_player : AnimationPlayer = AnimationPlayer.new()
			var animation: Animation = Animation.new()
			animation.add_track(Animation.TYPE_ROTATION_3D)
			
			animation.track_set_path(0, NodePath("%s:rotation" % node.find_child("doorLeft*").name))
			animation.track_insert_key(0, 0.0, Basis.from_euler(Vector3()))
			animation.track_insert_key(0, 1.0, Basis.from_euler(Vector3(0, deg_to_rad(angleL), 0)))
			
			animation.add_track(Animation.TYPE_ROTATION_3D)
			
			animation.track_set_path(1, NodePath("%s:rotation" % node.find_child("doorRight*").name))
			animation.track_insert_key(1, 0.0, Basis.from_euler(Vector3()))
			animation.track_insert_key(1, 1.0, Basis.from_euler(Vector3(0, deg_to_rad(angleR), 0)))
			#box_shape.size = 1.0
			
			collision_shape.shape = box_shape
			node.add_child(area)
			node.add_child(Node3D.new())
			area.add_child(collision_shape)
			area.set_owner(root)
			collision_shape.set_owner(root)
			var area_origin: Node3D = node.find_child("areaOrigin*")
			if area_origin != null:
				area.transform.origin = area_origin.transform.origin
			
			node.add_child(animation_player)
			animation_player.set_owner(root)
			animation_player.name = "AnimationPlayer"
			var animation_library = AnimationLibrary.new()
			animation_library.add_animation("open", animation)
			animation_player.add_animation_library("", animation_library)
			
			node.set_script(door_script)
		if node.name.contains("Door") and not node.name.contains("doubleDoor"):
			print("%s" % node.name)
			var angle = 120.0
			var result: RegExMatch = door_regex.search(node.name)
			if result:
				var value = result.get_string(2).to_float()
				var sign = result.get_string(1)
				if sign == "p":
					angle = value
				else:
					angle = -value
					
			print(angle)
				
			var area = Area3D.new()
			var collision_shape = CollisionShape3D.new()
			var box_shape = BoxShape3D.new()
			
			var animation_player : AnimationPlayer = AnimationPlayer.new()
			var animation: Animation = Animation.new()
			animation.add_track(Animation.TYPE_ROTATION_3D)
			
			animation.track_set_path(0, NodePath("%s:rotation" % node.find_child("door*").name))
			animation.track_insert_key(0, 0.0, Basis.from_euler(Vector3()))
			animation.track_insert_key(0, 1.0, Basis.from_euler(Vector3(0, deg_to_rad(angle), 0)))
			#box_shape.size = 1.0
			
			collision_shape.shape = box_shape
			node.add_child(area)
			node.add_child(Node3D.new())
			area.add_child(collision_shape)
			area.set_owner(root)
			collision_shape.set_owner(root)
			var area_origin: Node3D = node.find_child("areaOrigin*")
			if area_origin != null:
				area.transform.origin = area_origin.transform.origin
			
			node.add_child(animation_player)
			animation_player.set_owner(root)
			animation_player.name = "AnimationPlayer"
			var animation_library = AnimationLibrary.new()
			animation_library.add_animation("open", animation)
			animation_player.add_animation_library("", animation_library)
			
			node.set_script(door_script)
		if node.name.contains("Chair"):
			print("%s" % node.name)
			var area = Area3D.new()
			var collision_shape = CollisionShape3D.new()
			var box_shape = BoxShape3D.new()
			
			collision_shape.shape = box_shape
			node.add_child(area)
			node.add_child(Node3D.new())
			area.add_child(collision_shape)
			area.set_owner(root)
			collision_shape.set_owner(root)
			var area_origin: Node3D = node.find_child("areaOrigin*")
			if area_origin != null:
				area.transform.origin = area_origin.transform.origin
			
			var sitpos = node.find_child("*sittingPos*")
			sitpos.name = "SitPosition"
			node.set_script(chair_script)
		if node.name.contains("Sofa"):
			print("%s" % node.name)
			var area = Area3D.new()
			var collision_shape = CollisionShape3D.new()
			var box_shape: BoxShape3D = BoxShape3D.new()
			box_shape.size = Vector3(1, 1, 2)
			
			collision_shape.shape = box_shape
			node.add_child(area)
			node.add_child(Node3D.new())
			area.add_child(collision_shape)
			area.set_owner(root)
			collision_shape.set_owner(root)
			var area_origin: Node3D = node.find_child("areaOrigin*")
			if area_origin != null:
				area.transform.origin = area_origin.transform.origin
			
			var sitPos = Node3D.new()
			sitPos.name = "SitPosition"
			node.add_child(sitPos)
			sitPos.set_owner(root)
			node.set_script(sofa_script)
		for child in node.get_children():
			iterate(child)
