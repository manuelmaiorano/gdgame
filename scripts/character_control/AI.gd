extends Node3D
class_name AI

const MIN_DISTANCE_TO_DOOR = 0.1

@export var agent_kb: KnowledgeBase

var current_event: DailyStep = null
var current_event_idx: int = 0


var current_bt: BTNode
var current_step_task: PlanStep = null
var current_retry_amount = 0
var nav_steps = null

var player = null

enum BTNodeType {SEQUENCE, SELECTOR, TASK, RETRY, NAV}

class BTNode:
	var name: String
	var step: PlanStep
	var children: Array[BTNode]
	var parent: BTNode
	var type: BTNodeType
	var attempts: int

class NpcNeeds:
	#physical
	var hunger: float
	var comfort: float
	var hygiene: float
	var bladder: float
	#mental
	var energy: float
	var fun: float
	var social: float
	var room: float
	
func update_needs(needs: NpcNeeds, action: GLOBAL_DEFINITIONS.AgentInput):
	var step = 0.01
	needs.hunger -= step
	needs.comfort -= step
	needs.hygiene -= step
	needs.bladder -= step
	needs.energy -= step
	needs.fun -= step
	needs.social -= step
	needs.room -= step
	DebugView.append_debug_info("NEEDS:\n hunger: %f, \ncomfort: %f \n" % [needs.hunger, needs.comfort], player)
	
func get_object_score(needs: NpcNeeds, objectAd: GLOBAL_DEFINITIONS.ObjectAdvertisement):
	var score = 0
	score += agent_kb.needs_curves.hunger_curve.sample_baked(needs.hunger) * objectAd.hunger
	score += agent_kb.needs_curves.comfort_curve.sample_baked(needs.comfort) * objectAd.comfort
	score += agent_kb.needs_curves.hygiene_curve.sample_baked(needs.hygiene) * objectAd.hygiene
	score += agent_kb.needs_curves.bladder_curve.sample_baked(needs.bladder) * objectAd.bladder
	score += agent_kb.needs_curves.energy_curve.sample_baked(needs.energy) * objectAd.energy
	score += agent_kb.needs_curves.fun_curve.sample_baked(needs.fun) * objectAd.fun
	score += agent_kb.needs_curves.social_curve.sample_baked(needs.social) * objectAd.social
	score += agent_kb.needs_curves.room_curve.sample_baked(needs.room) * objectAd.room
	
	return score
	

class NpcState:
	
	var health: int
	var stamina: int
	var money: int
	
	var needs: NpcNeeds
	
@onready var state: NpcState = NpcState.new()

class ActionScore:
	var idx: int
	var score: float
	var adv: GLOBAL_DEFINITIONS.ObjectAdvertisement

func _ready():
	state.needs = NpcNeeds.new()
		

func handle_doors_navigation(player_position: Vector3, possible_actions: Array, agent_input: GLOBAL_DEFINITIONS.AgentInput):
	for idx in possible_actions.size():
		var action = possible_actions[idx]
		if action.object_action_id == Door.ACTION.OPEN and player_position.distance_to(action.object.position) < MIN_DISTANCE_TO_DOOR:
			agent_input.action_id = idx
			return

func fulfill_object_adv(objectAd: GLOBAL_DEFINITIONS.ObjectAdvertisement):
	state.needs.hunger += objectAd.hunger
	state.needs.comfort += objectAd.comfort
	state.needs.hygiene += objectAd.hygiene
	state.needs.bladder += objectAd.bladder
	state.needs.energy += objectAd.energy
	state.needs.fun += objectAd.fun
	state.needs.social += objectAd.social
	state.needs.room += objectAd.room

func pick_obj_action(possible_actions: Array):
	var scores: Array[ActionScore] = []
	for idx in possible_actions.size():
		var action_info = possible_actions[idx]
		if not action_info.object.include_in_utility_search():
			continue
		#get action score
		var adv: GLOBAL_DEFINITIONS.ObjectAdvertisement = action_info.object.get_action_adv(action_info.object_action_id)
		
		var action_score = ActionScore.new()
		var score = get_object_score(state.needs, adv)
		action_score.score = score
		action_score.idx = idx
		action_score.adv = adv
		scores.append(action_score)

	scores.sort_custom(func(a, b): return a.score > b.score)
	var top = scores.slice(0, 3)
	var chosen = top.pick_random()
	
	if chosen == null:
		return null

	return possible_actions[chosen.idx]
	

# func fill_bt_node_seq(bt_node: BTNode, children_steps: Array[PlanStep]):
# 	bt_node.type = BTInfo.BTNodeType.SEQUENCE
# 	for step in children_steps:
# 		var btNode_child = BTNode.new()
# 		btNode_child.step = step
# 		btNode_child.parent = bt_node
# 		btNode_child.type = BTInfo.BTNodeType.TASK
# 		bt_node.children.append(btNode_child)


func update(player_position: Vector3, possible_obj_actions: Array, perceptions: Array[CHARACTER_CONTROLLER.Perception], feedback: GLOBAL_DEFINITIONS.AI_FEEDBACK, minutes: int):
	var should_abort = false
	update_needs(state.needs, null)
	
	if current_bt == null and current_event == null:
		if not current_event_idx == -1:
			var next_event = agent_kb.daily_plan.schedule[current_event_idx]
			if minutes > next_event.hours * 60 + next_event.minutes:
				current_event = agent_kb.daily_plan.schedule[current_event_idx]

				var step = PlanStep.new()
				step.name = current_event.step_name
				step.params = current_event.step_params
				current_bt = BTRules.build_bt(step)

		# #check schedule
		# for event in day_schedules:
		# 	if event == current_event:
		# 		continue
		# 	if minutes > event.hours * 60 + event.minutes:
		# 		current_bt = BTNode.new()
		# 		#get_BTNode(current_bt, event.step, player_position, possible_obj_actions)
		# 		current_bt = BtRulesManager.build_bt(event.step)
		# 		current_event = event
	if current_bt == null:
		#add default 
		var step = PlanStep.new()
		step.name = "SearchObjActionUtility"
		step.params = [false]
		current_bt = BTRules.build_bt(step)

	if feedback != GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING:
		var outcome = process_BT(current_bt, feedback)
		if outcome != ProcessReturn.WAIT:
			current_bt = null
			if current_event != null:
				current_event = null
				current_event_idx += 1
				if current_event_idx >= agent_kb.daily_plan.schedule.size():
					current_event_idx = -1
	
	for perception in perceptions:
		var bt = InteractionRules.build_bt(perception, player)
		if bt == null:
			continue
		current_bt = bt
	return should_abort

enum ProcessReturn {BRANCH_DONE, SUCCESS, FAILURE, WAIT}

func process_BT(bt_node: BTNode, task_feedback: GLOBAL_DEFINITIONS.AI_FEEDBACK, ind_amount: int = 0) -> ProcessReturn:
	match bt_node.type:
		BTNodeType.SELECTOR:
			DebugView.append_debug_info(" ".repeat(ind_amount) + "selector: \n", player)
			var branches = 0
			for child in bt_node.children:
				var outcome = process_BT(child, task_feedback, ind_amount +4)
				if outcome == ProcessReturn.BRANCH_DONE:
					branches += 1
					continue
				if outcome == ProcessReturn.SUCCESS:
					return ProcessReturn.SUCCESS
				if outcome == ProcessReturn.FAILURE:
					continue
				if outcome == ProcessReturn.WAIT:
					return ProcessReturn.WAIT
			if branches == bt_node.children.size():
				return ProcessReturn.BRANCH_DONE
			return ProcessReturn.FAILURE
		BTNodeType.SEQUENCE:
			DebugView.append_debug_info(" ".repeat(ind_amount) + "sequence: \n", player)
			var branches = 0
			for idx in bt_node.children.size():
				var child = bt_node.children[idx]
				var outcome = process_BT(child, task_feedback, ind_amount+4)
				if outcome == ProcessReturn.BRANCH_DONE:
					branches += 1
					continue
				if outcome == ProcessReturn.SUCCESS:
					continue
				if outcome == ProcessReturn.FAILURE:
					return ProcessReturn.FAILURE
				if outcome == ProcessReturn.WAIT:
					return ProcessReturn.WAIT
			if branches == bt_node.children.size():
				return ProcessReturn.BRANCH_DONE
			return ProcessReturn.SUCCESS
		BTNodeType.NAV:
			DebugView.append_debug_info(" ".repeat(ind_amount) + "nav: \n", player)
			build_nav_steps(bt_node)
			var branches = 0
			for idx in bt_node.children.size():
				var child = bt_node.children[idx]
				var outcome = process_BT(child, task_feedback, ind_amount+4)
				if outcome == ProcessReturn.BRANCH_DONE:
					branches += 1
					continue
				if outcome == ProcessReturn.SUCCESS:
					continue
				if outcome == ProcessReturn.FAILURE:
					return ProcessReturn.FAILURE
				if outcome == ProcessReturn.WAIT:
					return ProcessReturn.WAIT
			if branches == bt_node.children.size():
				return ProcessReturn.BRANCH_DONE
			return ProcessReturn.SUCCESS
		BTNodeType.RETRY:
			while current_retry_amount < bt_node.attempts:
				DebugView.append_debug_info(" ".repeat(ind_amount) + "retry(%d): \n" % current_retry_amount, player)
				var child = bt_node.children[0]
				var outcome = process_BT(child, task_feedback, ind_amount+4)
				if outcome == ProcessReturn.BRANCH_DONE:
					current_retry_amount = 0
					return ProcessReturn.BRANCH_DONE
				if outcome == ProcessReturn.SUCCESS:
					current_retry_amount = 0
					return ProcessReturn.SUCCESS
				if outcome == ProcessReturn.FAILURE:
					current_retry_amount += 1
					continue
				if outcome == ProcessReturn.WAIT:
					return ProcessReturn.WAIT
			current_retry_amount = 0
			return ProcessReturn.FAILURE
		BTNodeType.TASK:
			DebugView.append_debug_info(" ".repeat(ind_amount) + "task: %s\n" % bt_node.name, player)
			if bt_node.step.step_type == PlanStep.STEP_TYPE.QUERY_PERSON and bt_node.step.property_name == "ragdoll":
				pass
			if current_step_task == null:
				current_step_task = bt_node.step
				return ProcessReturn.WAIT
			if current_step_task.step_type == PlanStep.STEP_TYPE.QUERY_PERSON and current_step_task.property_name == "ragdoll":
				pass
			if bt_node.step == current_step_task:
				if task_feedback == GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED:
					current_step_task = null
					return ProcessReturn.FAILURE
				if task_feedback == GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE:
					current_step_task = null
					return ProcessReturn.SUCCESS
			return ProcessReturn.BRANCH_DONE
		_: return ProcessReturn.BRANCH_DONE 


# var btstack: Array[BTNode] = []
# var curr_idx = 0

# func process_BT_stack(bt_node: BTNode, task_feedback: GLOBAL_DEFINITIONS.AI_FEEDBACK, ind_amount: int = 0):
# 	btstack.append(bt_node)
# 	btstack.pop_back()
# 	while true:
# 		var node: BTNode = btstack.back()
# 		match node.type:
# 			BTInfo.BTNodeType.SELECTOR:
# 				DebugView.append_debug_info(" ".repeat(ind_amount) + "selector: \n", player)
# 				if curr_idx == 0:
# 					btstack.append(node.children[0])
# 					continue
# 				if curr_idx == node.children.size()-1:
# 					btstack.pop_back()
# 					curr_idx = 0
# 					continue
# 				if task_feedback == GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED:
# 					btstack.pop_back()
# 					continue
# 				if task_feedback == GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE:
# 					curr_idx += 1
# 					btstack.append(node.children[curr_idx])
# 					continue

# 			BTInfo.BTNodeType.SEQUENCE:
# 				DebugView.append_debug_info(" ".repeat(ind_amount) + "sequence: \n", player)
				
# 			BTInfo.BTNodeType.NAV:
# 				DebugView.append_debug_info(" ".repeat(ind_amount) + "nav: \n", player)
# 				#build_nav_steps(bt_node, node.step.should_run)
				
# 			BTInfo.BTNodeType.RETRY:
# 				pass
# 			BTInfo.BTNodeType.TASK:
# 				current_step_task = btstack.back().step
# 				DebugView.append_debug_info(" ".repeat(ind_amount) + "task: %s\n" % bt_node.name, player)
				
				
				


func build_nav_steps(bt_node):
	bt_node.type = BTNodeType.SEQUENCE
	for step in nav_steps:
		var btNode_child = BTNode.new()
		btNode_child.step = step
		btNode_child.parent = bt_node
		if step.step_type == PlanStep.STEP_TYPE.GOTO_POSITION:
			btNode_child.type = BTNodeType.TASK
			btNode_child.step.should_run = bt_node.step.should_run
		else:
			match step.crossing_rule:
				LocationGraphLink.CROSSING_RULE.NONE:
					btNode_child.type = BTNodeType.TASK
				LocationGraphLink.CROSSING_RULE.DOOR:
					var door_step = PlanStep.new()
					door_step.name = "OpenNearbyDoor"
					door_step.params = []
					btNode_child = BTRules.build_bt(door_step)
				LocationGraphLink.CROSSING_RULE.CROSSWALK:
					var crosswalk_step = PlanStep.new()
					crosswalk_step.step_type = PlanStep.STEP_TYPE.GOTO_POSITION
					crosswalk_step.position = step.link_end_position
					btNode_child =  crosswalk_step
		bt_node.children.append(btNode_child)
