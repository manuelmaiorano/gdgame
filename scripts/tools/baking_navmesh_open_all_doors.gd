@tool
extends EditorScript

func _run():
	for node in get_all_children(get_scene()):
		if node is AnimationPlayer and node.get_parent().name.contains("Door"):
			print(node.get_parent().name)
			if 1 == 1:
				node.play_backwards("open")
			else:
				node.play("open")
# This function is recursive: it calls itself to get lower levels of child nodes as needed.
# `children_acc` is the accumulator parameter that allows this function to work.
# It should be left to its default value when you call this function directly.
func get_all_children(in_node, children_acc = []):
	children_acc.push_back(in_node)
	for child in in_node.get_children():
		children_acc = get_all_children(child, children_acc)

	return children_acc
