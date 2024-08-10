@tool
class_name LocationManager
extends Node

class GraphAStar:
	extends AStar3D

	var links_cost: Dictionary
	var name2index: Dictionary
	var index2name: Dictionary

	func build(hierarchy: LocationHierarchy):
		var idx = 1
		for child in hierarchy.child_locations:
			name2index[child.name] = idx
			index2name[idx] = child.name
			add_point(idx, Vector3(0, 0, 0))
			idx = idx +1
		name2index[LocationGraph.OUT_NODE_NAME] = idx
		index2name[idx] = LocationGraph.OUT_NODE_NAME
		add_point(idx, Vector3(0, 0, 0))
		
		
		for link in hierarchy.graph.links:
			var idx1 = name2index[link.source_name]
			var idx2 = name2index[link.dest_name]
			connect_points(idx1, idx2, true)
			links_cost[idx1 + 2 * idx2] = link.cost
			links_cost[idx2 + 2 * idx1] = link.cost

		return self
			
	func _compute_cost(u, v):
		return links_cost[u + 2 * v]

	func _estimate_cost(_u, _v):
		return 0


@export var location_hierarchy: LocationHierarchy

class LocationHierarchyNode:
	var name: String
	var aabb: AABB
	var child_locations: Array[LocationHierarchyNode]
	var graph: LocationGraph
	var parent: LocationHierarchyNode
	var level: int
	var astar: GraphAStar

func clone_node(old: LocationHierarchyNode):
	var new_node = LocationHierarchyNode.new()
	new_node.name = old.name
	new_node.aabb = old.aabb
	new_node.child_locations = old.child_locations
	new_node.graph = old.graph
	new_node.parent = old.parent
	new_node.level = old.level
	new_node.astar = old.astar
	return new_node

var location_hierarchy_node: LocationHierarchyNode

func _ready():
	build_hierarchy()
	find_parents_and_levels()
	var plan = plan_navigation_from_names("Harris house", "johns house")
	print("Full Path1:")
	for step in plan:
		print(step.name)
		print(step.position)
	return
	var pos1 = get_parent().get_node("Node3D").get_node("posA").global_position
	var pos2 = get_parent().get_node("Node3D").get_node("posB").global_position
	
	plan = plan_navigation_from_pos(pos1, pos2)
	print("Full Path:")
	for step in plan:
		print(step.name)
		print(step.position)

func build_hierarchy():
	location_hierarchy_node = LocationHierarchyNode.new()
	recursive_build(location_hierarchy_node, location_hierarchy)

func recursive_build(node: LocationHierarchyNode, hierarchy: LocationHierarchy):
	node.name = hierarchy.name
	node.aabb = hierarchy.aabb
	node.child_locations = []
	node.graph = hierarchy.graph
	node.astar = GraphAStar.new().build(hierarchy)
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

		return node

	return null
	

func get_node_from_name(location_name: String):
	var root = location_hierarchy_node
	return recursive_find_node_from_name(root, location_name)


func recursive_find_node_from_name(node: LocationHierarchyNode, location_name: String):
	if node.name == location_name:
		return node

	for child in node.child_locations:
		var out = recursive_find_node_from_name(child, location_name)
		if out != null: return out

	return null
	
func plan_navigation_from_pos(start_position: Vector3, end_position: Vector3):
	var start_node = get_node_from_position(start_position)
	var end_node = get_node_from_position(end_position)

	return plan_navigation(start_node, end_node)

	
func plan_navigation_from_names(start_name: String, end_name: String):
	var start_node = get_node_from_name(start_name)
	var end_node = get_node_from_name(end_name)

	return plan_navigation(start_node, end_node)


func plan_navigation(start_node: LocationHierarchyNode, end_node: LocationHierarchyNode):

	var path: HierarchyPath = find_path_in_hierarchy(start_node, end_node)
	var hierarchy_path = path.path
	var lca = path.lca

	var full_path: Array[PlanStep] = []

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
		if hierarchy_path[idx+1] == lca and hierarchy_path.size() >= idx +3:
			var partial_path = search_graph(lca, elem.name, hierarchy_path[idx +2].name)
			full_path.append_array(partial_path)
		else:
			if idx < lca_idx:
				var partial_path = search_graph(hierarchy_path[idx +1], elem.name, LocationGraph.OUT_NODE_NAME)
				full_path.append_array(partial_path)
			else:
				var partial_path = search_graph(elem, LocationGraph.OUT_NODE_NAME, hierarchy_path[idx +1].name)
				full_path.append_array(partial_path)

	return full_path

class HierarchyPath:
	var path: Array[LocationHierarchyNode]
	var lca: LocationHierarchyNode

func find_path_in_hierarchy(start_node: LocationHierarchyNode, end_node: LocationHierarchyNode) -> HierarchyPath:
	var lca = LCA(start_node, end_node)
	var path: Array[LocationHierarchyNode] = []
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

	var out = HierarchyPath.new()
	out.path = path
	out.lca = lca
	return out

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


class Linkinfo:
	var link: LocationGraphLink
	var reverse: bool

func find_link(graph: LocationGraph, a: StringName, b: StringName) -> Linkinfo:
	for link: LocationGraphLink in graph.links: 
		if (a == link.source_name and b == link.dest_name):
			var info = Linkinfo.new()
			info.link = link
			info.reverse = false
			return info
		elif (b == link.source_name and a == link.dest_name):
			var info = Linkinfo.new()
			info.link = link
			info.reverse = true
			return info
	return null


func search_graph(hierarchy: LocationHierarchyNode, start: String, end: String) -> Array[PlanStep]:
	var graph = hierarchy.graph
	#var path_names = shortestPath(graph, start, end)
	var path_names = shortestPathAstar(graph, hierarchy.astar, start, end)
	var path: Array[PlanStep] = []
	for idx in path_names.size():
		if idx == path_names.size()-1:
			break
		var a = path_names[idx]
		var b = path_names[idx + 1]
		var link_info = find_link(graph, a, b)
		var link = link_info.link
		var step = PlanStep.new()
		var end_position = Vector3()
		if link_info.reverse:
			step.position = link.end_position
			end_position = link.start_position
			step.name = link.dest_name + "->" + link.source_name
		else:
			step.position = link.start_position
			end_position = link.end_position
			step.name = link.source_name + "->" + link.dest_name 
		step.step_type = PlanStep.STEP_TYPE.GOTO_POSITION
		path.append(step)
		if link.crossing_rule != LocationGraphLink.CROSSING_RULE.NONE:
			var new_step = PlanStep.new()
			new_step.step_type = PlanStep.STEP_TYPE.EXECUTE_LINK_ACTION
			new_step.crossing_rule = link.crossing_rule
			new_step.link_end_position = end_position
			new_step.name = "LinkAction " + str(link.crossing_rule)
			path.append(new_step)


	return path

func shortestPath(graph: LocationGraph, start: String, end: String) -> Array[String]:
	if end == LocationGraph.OUT_NODE_NAME:
		if graph.out_strategy == LocationGraph.OUT_STRATEGY.NONE:
			return []
	#Specify link from out to each node?
	# if start == LocationGraph.OUT_NODE_NAME:
	# 	if graph.out_strategy == LocationGraph.OUT_STRATEGY.NONE:
	# 		return [end]
	
	var queue = [[start]]
	var visited = {}
	while queue.size() > 0:
		var path = queue.pop_front()
		var currentNode = path[path.size() - 1]
		if currentNode == end:
			return path
		elif not visited.has(currentNode):
			var neighbors = graph[currentNode]
			queue.append(neighbors)
			visited[currentNode] = null
	return []

func shortestPathAstar(graph: LocationGraph, astar: GraphAStar, start: String, end: String) -> Array[String]:
	if end == LocationGraph.OUT_NODE_NAME:
		if graph.out_strategy == LocationGraph.OUT_STRATEGY.NONE:
			return []

	var idx1 = astar.name2index[start]
	var idx2 = astar.name2index[end]
	var path: Array[String] = []
	var idx_path = astar.get_id_path(idx1, idx2)
	for idx in idx_path:
		path.append(astar.index2name[idx])

	return path


