extends Node3D

const MIN_DISTANCE_TO_DOOR = 0.1

@export var hunger_curve: Curve
@export var comfort_curve: Curve
@export var hygiene_curve: Curve
@export var bladder_curve: Curve
@export var energy_curve: Curve
@export var fun_curve: Curve
@export var social_curve: Curve
@export var room_curve: Curve

@export var day_schedules: Array[DaySchedule]
var current_event: DaySchedule
var current_bt: BTNode
var current_step_task: PlanStep = null
var current_retry_amount = 0

class BTNode:
	var step: PlanStep
	var children: Array[BTNode]
	var parent: BTNode
	var type: BTInfo.BTNodeType

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
	
func get_object_score(needs: NpcNeeds, objectAd: GLOBAL_DEFINITIONS.ObjectAdvertisement):
	var score = 0
	score += hunger_curve.sample_baked(needs.hunger) * objectAd.hunger
	score += comfort_curve.sample_baked(needs.comfort) * objectAd.comfort
	score += hygiene_curve.sample_baked(needs.hygiene) * objectAd.hygiene
	score += bladder_curve.sample_baked(needs.bladder) * objectAd.bladder
	score += energy_curve.sample_baked(needs.energy) * objectAd.energy
	score += fun_curve.sample_baked(needs.fun) * objectAd.fun
	score += social_curve.sample_baked(needs.social) * objectAd.social
	score += room_curve.sample_baked(needs.room) * objectAd.room
	
	return score
	
class NpcPersonality:
	var neat: float
	var outgoing: float
	var active: float
	var playful: float
	var nice: float
	
class NpcRelationships:
	var relation_scores: Array[float]

class NpcKB:
	var house_name: String
	

class NpcState:
	var name: String
	var id: int
	var backstory: String
	
	var health: int
	var stamina: int
	var money: int
	
	var needs: NpcNeeds
	
	var personality: NpcPersonality
	
	var relationships: NpcRelationships
	
@onready var state: NpcState = NpcState.new()
var going = false

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
	
# func transform_plan_step(step: PlanStep, player_position: Vector3, possible_obj_actions: Array) -> Array[PlanStep]:
# 	var steps = []
# 	match step.step_type:
# 		PlanStep.STEP_TYPE.GOTO_LOCATION:
# 			var pl_loc_name = Locations.get_node_from_position(player_position).name
# 			var nav_steps = Locations.plan_navigation_from_names(pl_loc_name, step.location.place_name)
# 			steps.append_array(nav_steps)
		
# 		PlanStep.STEP_TYPE.EXECUTE_LINK_ACTION:
# 			match step.crossing_rule:
# 				LocationGraphLink.CROSSING_RULE.NONE:
# 					steps.append(step)
# 				LocationGraphLink.CROSSING_RULE.DOOR:
# 					var execute_step = PlanStep.new()
# 					execute_step.step_type = PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_BY_ACTION_ID
# 					execute_step.object_action_id = Door.ACTION.OPEN
# 					steps = [execute_step]
# 				LocationGraphLink.CROSSING_RULE.CROSSWALK:
# 					var reach_step = PlanStep.new()
# 					reach_step.step_type = PlanStep.STEP_TYPE.GOTO_POSITION
# 					reach_step.position = step.link_end_position
# 					steps = [reach_step]
		
# 		PlanStep.STEP_TYPE.SEARCH_OBJ_ACTION:
# 			var obj_action = pick_obj_action(possible_obj_actions)
			
# 			var reach_step = PlanStep.new()
# 			reach_step.step_type = PlanStep.STEP_TYPE.GOTO_POSITION
# 			reach_step.position = obj_action.object.position
# 			var execute_step = PlanStep.new()
# 			execute_step.step_type = PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION
# 			execute_step.object_action_id = obj_action.get_instance_id()
# 			steps = [reach_step, execute_step]

# 			var object_position = obj_action.object.position
# 			var distance = player_position.distance_to(object_position)
# 			if distance >= GLOBAL_DEFINITIONS.MIN_DISTANCE_TO_EXECUTE_ACTION:
# 				steps = [reach_step, execute_step]
# 			else:
# 				steps = [execute_step]
# 		_:
# 			steps.append(step)


# 	return steps

func fill_bt_node_seq(bt_node: BTNode, children_steps: Array[PlanStep]):
	bt_node.type = BTInfo.BTNodeType.SEQUENCE
	for step in children_steps:
		var btNode_child = BTNode.new()
		btNode_child.step = step
		btNode_child.parent = bt_node
		btNode_child.type = BTInfo.BTNodeType.TASK
		bt_node.children.append(btNode_child)

func get_BTNode(btNode: BTNode, step: PlanStep, player_position: Vector3, possible_obj_actions: Array):
	btNode.step = step
	btNode.type = BTInfo.BTNodeType.TASK
	btNode.children = []
	match step.step_type:
		PlanStep.STEP_TYPE.GOTO_LOCATION:
			var pl_loc_name = Locations.get_node_from_position(player_position).name
			var nav_steps = Locations.plan_navigation_from_names(pl_loc_name, step.location.place_name)
			fill_bt_node_seq(btNode, nav_steps)
		PlanStep.STEP_TYPE.EXECUTE_LINK_ACTION:
			match step.crossing_rule:
				LocationGraphLink.CROSSING_RULE.NONE:
					btNode.type = BTInfo.BTNodeType.TASK
				LocationGraphLink.CROSSING_RULE.DOOR:
					var execute_step = PlanStep.new()
					execute_step.step_type = PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_BY_ACTION_TYPE
					execute_step.object_action_type = Door.ACTION.OPEN
					fill_bt_node_seq(btNode, [execute_step])
				LocationGraphLink.CROSSING_RULE.CROSSWALK:
					var reach_step = PlanStep.new()
					reach_step.step_type = PlanStep.STEP_TYPE.GOTO_POSITION
					reach_step.position = step.link_end_position
					fill_bt_node_seq(btNode, [reach_step])
		
		PlanStep.STEP_TYPE.SEARCH_OBJ_ACTION_UTILITY:
			var obj_action = pick_obj_action(possible_obj_actions)
			if obj_action != null:
			
				var reach_step = PlanStep.new()
				reach_step.step_type = PlanStep.STEP_TYPE.GOTO_POSITION
				reach_step.should_run = step.should_run
				reach_step.position = obj_action.object.position
				var execute_step = PlanStep.new()
				execute_step.step_type = PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION
				execute_step.object_id = obj_action.object.get_instance_id()
				execute_step.object_action_id = obj_action.object_action_id

				var object_position = obj_action.object.position
				var distance = player_position.distance_to(object_position)
				if distance >= GLOBAL_DEFINITIONS.MIN_DISTANCE_TO_EXECUTE_ACTION:
					fill_bt_node_seq(btNode, [reach_step, execute_step])
				else:
					fill_bt_node_seq(btNode, [execute_step])
		
		PlanStep.STEP_TYPE.SEARCH_OBJ_ACTION:
			
			var query_step = PlanStep.new()
			query_step.step_type = PlanStep.STEP_TYPE.QUERY_CLOSE
			query_step.obj_type = step.obj_type
			query_step.object_action_type = step.object_action_type
			query_step.return_var_name = "obj"

			var reach_step = PlanStep.new()
			reach_step.step_type = PlanStep.STEP_TYPE.GOTO_POSITION
			reach_step.should_run = step.should_run
			reach_step.use_stored_pos = true
			
			var execute_step = PlanStep.new()
			execute_step.step_type = PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_STORED
			execute_step.input_var_name = "obj"
			
			fill_bt_node_seq(btNode, [query_step, reach_step, execute_step])

		PlanStep.STEP_TYPE.CUSTOM:
			var expansion_rule: BTInfo = BtRulesManager.get_bt_info(step.name)
			btNode.type = expansion_rule.type
			for child in expansion_rule.children_steps:
				var btNode_child = BTNode.new()
				btNode_child.step = PlanStep.new()

				btNode_child.step.name = child.name
				btNode_child.step.copy_params(child)
				btNode_child.step.copy_params_from_parent_step(step)

				get_BTNode(btNode_child, btNode_child.step, player_position, possible_obj_actions)
				btNode_child.parent = btNode
				btNode.children.append(btNode_child)
				
		_:
			btNode.type = BTInfo.BTNodeType.TASK




func update(player_position: Vector3, possible_obj_actions: Array, feedback: GLOBAL_DEFINITIONS.AI_FEEDBACK, minutes: int):
	var should_abort = false
	update_needs(state.needs, null)
	
	if current_bt == null:
		#check schedule
		for event in day_schedules:
			if event == current_event:
				continue
			if minutes > event.hours * 60 + event.minutes:
				current_bt = BTNode.new()
				get_BTNode(current_bt, event.step, player_position, possible_obj_actions)
				current_event = event
	if current_bt == null:
		#add default 
		current_bt = BTNode.new()
		var step = PlanStep.new()
		step.step_type = PlanStep.STEP_TYPE.SEARCH_OBJ_ACTION_UTILITY
		get_BTNode(current_bt, step, player_position, possible_obj_actions)

	if feedback != GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING:
		var outcome = process_BT(current_bt, feedback)
		if outcome != ProcessReturn.WAIT:
			current_bt = null
	
	return should_abort

enum ProcessReturn {BRANCH_DONE, SUCCESS, FAILURE, WAIT}

func process_BT(bt_node: BTNode, task_feedback: GLOBAL_DEFINITIONS.AI_FEEDBACK) -> ProcessReturn:
	match bt_node.type:
		BTInfo.BTNodeType.SELECTOR:
			var branches = 0
			for child in bt_node.children:
				var outcome = process_BT(child, task_feedback)
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
		BTInfo.BTNodeType.SEQUENCE:
			var branches = 0
			for idx in bt_node.children.size():
				var child = bt_node.children[idx]
				var outcome = process_BT(child, task_feedback)
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
		BTInfo.BTNodeType.RETRY:
			while current_retry_amount < bt_node.amount:
				current_retry_amount += 1
				var child = bt_node.children[0]
				var outcome = process_BT(child, task_feedback)
				if outcome == ProcessReturn.BRANCH_DONE:
					current_retry_amount = 0
					return ProcessReturn.BRANCH_DONE
				if outcome == ProcessReturn.SUCCESS:
					current_retry_amount = 0
					return ProcessReturn.SUCCESS
				if outcome == ProcessReturn.FAILURE:
					continue
				if outcome == ProcessReturn.WAIT:
					return ProcessReturn.WAIT
			current_retry_amount = 0
			return ProcessReturn.FAILURE
		BTInfo.BTNodeType.TASK:
			if current_step_task == null:
				current_step_task = bt_node.step
				return ProcessReturn.WAIT
			if bt_node.step == current_step_task:
				if task_feedback == GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED:
					current_step_task = null
					return ProcessReturn.FAILURE
				if task_feedback == GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE:
					current_step_task = null
					return ProcessReturn.SUCCESS
			return ProcessReturn.BRANCH_DONE
		_: return ProcessReturn.BRANCH_DONE 

			

