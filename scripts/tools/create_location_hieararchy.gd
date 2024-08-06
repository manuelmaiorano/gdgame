@tool
extends EditorScript

func _run():
    for node in get_all_children(get_scene()):
        if node.name == "map":
            pass
                

func get_all_children(in_node, children_acc = []):
    children_acc.push_back(in_node)
    for child in in_node.get_children():
        children_acc = get_all_children(child, children_acc)

    return children_acc