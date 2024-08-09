@tool
extends EditorScript

func _run():
	for node in get_all_children(get_scene()):
		if node.name == "map":
			var hierarchy: LocationHierarchy = load("res://resources/navigation/locations.tres")
			iterate(node.get_node("root"), hierarchy)
			ResourceSaver.save(hierarchy, "res://resources/navigation/locations.tres")
			break

func iterate(node: Node, hierarchy: LocationHierarchy):
	print(node.name)
	var coll: CollisionShape3D = node.get_node("CollisionShape3D")

	hierarchy.name = node.name

	var children_areas = node.get_children().filter(func (x): return x is Area3D)
	hierarchy.aabb = get_aabb_from_collision_shape(coll)
	
	var links = []
	if node.has_node("links"):
		links = node.get_node("links").get_children()
		
	var linkObjs: Array[LocationGraphLink] = []
	for link in links:
		var linkObj = LocationGraphLink.new()
		var splitted = link.name.split("_")
		var from = splitted[0]
		var to = splitted[1]
		linkObj.source_name = from
		linkObj.dest_name = to
		if link is Node3D:
			linkObj.start_position = link.global_position
			linkObj.end_position = link.global_position
			linkObj.crossing_rule = LocationGraphLink.CROSSING_RULE.NONE
		if link is NavigationLink3D:
			linkObj.start_position = link.start_position
			linkObj.end_position = link.end_position
			linkObj.crossing_rule = LocationGraphLink.CROSSING_RULE.CROSSWALK
	
		linkObj.cost = 1
		linkObjs.append(linkObj)

	var graph = LocationGraph.new()
	graph.links = linkObjs
	graph.out_strategy = LocationGraph.OUT_STRATEGY.SEARCH

	hierarchy.graph = graph
	
	hierarchy.child_locations = []
	for child in children_areas:
		var hierarchy_child = LocationHierarchy.new()
		hierarchy.child_locations.append(hierarchy_child)
		iterate(child, hierarchy_child)

func get_aabb_from_collision_shape(coll: CollisionShape3D):
	var position = coll.global_position

	var size: Vector3 = coll.shape.size

	var aabb_position = Vector3(position.x - size.x/2, position.y - size.y/2, position.z - size.z/2, )

	return AABB(aabb_position, size)



func get_all_children(in_node, children_acc = []):
	children_acc.push_back(in_node)
	for child in in_node.get_children():
		children_acc = get_all_children(child, children_acc)

	return children_acc
