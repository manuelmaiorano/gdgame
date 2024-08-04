extends Node

@export var location_hierarchy: LocationHierarchy

class LocationHierarchyNode:
	var name: String
	var aabb: AABB
	var child_locations: Array[LocationHierarchyNode]
	var graph: LocationGraph
	var parent: LocationHierarchyNode
	var level: int

func clone_node(old: LocationHierarchyNode):
	var new = LocationHierarchyNode.new()
	new.name = old.name
	new.aabb = old.aabb
	new.child_locations = old.child_locations
	new.graph = old.graph
	new.parent = old.parent
	new.level = old.level

var location_hierarchy_node: LocationHierarchyNode

func _ready():
	build_hierarchy()
	find_parents_and_levels()

func build_hierarchy():
	location_hierarchy_node = LocationHierarchyNode.new()
	recursive_build(location_hierarchy_node, location_hierarchy)

func recursive_build(node: LocationHierarchyNode, hierarchy: LocationHierarchy):
	node.name = hierarchy.name
	node.aabb = hierarchy.aabb
	node.child_locations = []
	node.graph = hierarchy.graph
	for child in hierarchy.child_locations:
		var child_node = LocationHierarchyNode.new()
		node.child_locations.append(child_node)
		recursive_build(child_node, child)


func find_parents_and_levels():
	dfs(location_hierarchy_node, 0, null)

func dfs(node: LocationHierarchyNode, level: int, parent: LocationHierarchyNode):
	node.level = level
	node.parent = parent

	for child in node.child_locations:
		if child != parent:
			dfs(child, level + 1, node)


func get_node_from_position(position: Vector3):
	var root = location_hierarchy_node
	return recursive_find_node(root, position)


func recursive_find_node(node: LocationHierarchyNode, position: Vector3):

	if node.aabb.has_point(position):

		for child in node.child_locations:
			var out = recursive_find_node(child, position)
			if out != null: return out

		return node.name

	return null



func get_aabb_from_name(location_name: String):
	var root = location_hierarchy_node
	return recursive_find_aabb(root, location_name)


func recursive_find_aabb(node: LocationHierarchyNode, location_name: String):
	if node.name == location_name:
		return node.aabb

	for child in node.child_locations:
		return recursive_find_aabb(child, location_name)

	return null
	


func get_node_from_name(location_name: String):
	var root = location_hierarchy_node
	return recursive_find_node_from_name(root, location_name)


func recursive_find_node_from_name(node: LocationHierarchyNode, location_name: String):
	if node.name == location_name:
		return node

	for child in node.child_locations:
		return recursive_find_node_from_name(child, location_name)

	return null
	
enum StepType {GOTO, LINK_ACTION}

class NavigationPlanStep:
	var step_type: StepType
	var end_position: Vector3
	
	

func plan_navigation(start_position: Vector3, end_position: Vector3):
	var start_node = get_node_from_position(start_position)
	var end_node = get_node_from_position(end_position)

	var lca = LocationHierarchyNode.new()
	var hierarchy_path = find_path_in_hierarchy(start_node, end_node, lca)

	var full_path: Array[NavigationPlanStep] = []

	#find index of lca
	var lca_idx = -1
	for idx in hierarchy_path.size():
		var elem = hierarchy_path[idx]
		if elem == lca:
			lca_idx = idx
			break

	for idx in hierarchy_path.size():
		var elem = hierarchy_path[idx]
		if idx == hierarchy_path.size() - 1:
			break
		if elem == lca:
			continue
		if hierarchy_path[idx+1] == lca:
			var partial_path = search_graph(elem.graph, elem.name, hierarchy_path[idx +2].name)
			full_path.append_array(partial_path)
		else:
			if idx < lca_idx:
				var partial_path = search_graph(elem.graph, elem.name, LocationGraph.OUT_NODE_NAME)
				full_path.append_array(partial_path)
			else:
				var partial_path = search_graph(hierarchy_path[idx +1].graph, LocationGraph.OUT_NODE_NAME, hierarchy_path[idx +1].name)
				full_path.append_array(partial_path)

	return full_path

	
	
	


func find_path_in_hierarchy(start_node: LocationHierarchyNode, end_node: LocationHierarchyNode, lca_out: LocationHierarchyNode) -> Array[LocationHierarchyNode]:
	var lca = LCA(start_node, end_node)
	lca_out = lca
	var path = []
	var a = start_node
	var b = end_node
	while a != lca:
		path.append(clone_node(a))
		a = a.parent
	path.append(a)
	var temp = []
	while b != lca:
		temp.append(clone_node(b))
		b = b.parent
	temp.reverse()
	for x in temp:
		path.append(x)

	return path




func LCA(node_a: LocationHierarchyNode, node_b: LocationHierarchyNode):  
	var a = node_a
	var b = node_b
	if node_a.level > node_b.level:
		a = node_b
		b = node_a

	var diff = b.level - a.level
	while diff != 0:
		b = b.parent
		diff -= 1
	if a == b:
		return a
	while a != b:
		a = a.parent
		b = b.parent
	return a



func search_graph(graph: LocationGraph, start: String, end: String) -> Array[NavigationPlanStep]:
	return []


# func dfs_search(vis: Dictionary, x, y, stack):
# 	stack.append(x)
# 	if x == y:
 
# 		printPath(stack)
# 		return
# 	vis.has(x)
 
#     # if backtracking is taking place
 
# 	for j in v[x]:
             
#             # if the node is not visited
# 	if (vis[j] == False):
# 		DFS(vis, j, y, stack)
        
# 	del stack[-1]
	
