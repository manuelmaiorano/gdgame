extends Control

signal equip(idx)

@onready var items = $InventoryContainer/Inventory/items
@onready var current_selected_idx = 0
@onready var current_equipped_idx = -1
@onready var n_items = 0
@onready var ui_items = items.get_children()

func _ready():
	set_item_states()

func update_inventory(inventory: Array[GLOBAL_DEFINITIONS.InventoryItem], equipped_idx):
	inventory = inventory.duplicate()
	n_items = 0
	
	for item in inventory:
		var ui_item = ui_items[n_items]
		ui_item.get_node("Container/Label").text = item.object.get_item_desc()
		
		n_items += 1
	
	current_equipped_idx = equipped_idx
	
	set_item_states()
	
func _process(delta):
	if Input.is_action_just_pressed("inventory_scroll_right"):
		current_selected_idx += 1
		if current_selected_idx >= n_items:
			current_selected_idx = 0
		set_item_states()
	if Input.is_action_just_pressed("inventory_scroll_left"):
		current_selected_idx -= 1
		if current_selected_idx < 0:
			current_selected_idx = n_items-1
		if n_items == 0:
			current_selected_idx = 0
		set_item_states()
	if Input.is_action_just_pressed("equip_unequip"):
		if current_equipped_idx == current_selected_idx:
			current_equipped_idx = -1
			set_item_states()
			equip.emit(current_selected_idx)
			return
		current_equipped_idx = current_selected_idx
		set_item_states()
		equip.emit(current_selected_idx)
	#DebugView.print_debug_info("IDX: %d" % current_selected_idx, null)
			
func set_item_states():
	for idx in ui_items.size():
		var ui_item = ui_items[idx]
		if idx == current_selected_idx:
			ui_item.selected_item()
		if idx == current_equipped_idx:
			ui_item.equipped_item()
			continue
		if idx >= n_items:
			ui_item.disabled_item()
		else:
			ui_item.unselected_item()
