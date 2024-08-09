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

@export var day_plan: Dayplan
var current_step_stack: Array[PlanStep]
var current_step: PlanStep

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

func fulfill_object_adv(needs: NpcNeeds, objectAd: GLOBAL_DEFINITIONS.ObjectAdvertisement):
	needs.hunger += objectAd.hunger
	needs.comfort += objectAd.comfort
	needs.hygiene += objectAd.hygiene
	needs.bladder += objectAd.bladder
	needs.energy += objectAd.energy
	needs.fun += objectAd.fun
	needs.social += objectAd.social
	needs.room += objectAd.room
	
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
		

func handle_doors_navigation(player_position: Vector3, possible_actions: Array, agent_input: GLOBAL_DEFINITIONS.AgentInput):
	for idx in possible_actions.size():
		var action = possible_actions[idx]
		if action.object_action_id == Door.ACTION.OPEN and player_position.distance_to(action.object.position) < MIN_DISTANCE_TO_DOOR:
			agent_input.action_id = idx
			return

func pick_obj_action(possible_actions: Array):
	var scores: Array[ActionScore] = []
	for idx in possible_actions.size():
		var action_info = possible_actions[idx]
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

	return chosen
	
func transform_plan_step(step: PlanStep, player_position: Vector3, possible_obj_actions: Array) -> Array[PlanStep]:
	var steps = []
	match step.step_type:
		PlanStep.STEP_TYPE.GOTO_LOCATION:
			var pl_loc_name = Locations.get_node_from_position(player_position).name
			var nav_steps = Locations.plan_navigation_from_names(pl_loc_name, step.location.place_name)
			steps.append_array(nav_steps)
		
		PlanStep.STEP_TYPE.EXECUTE_LINK_ACTION:
			match step.crossing_rule:
				LocationGraphLink.CROSSING_RULE.NONE:
					steps.append(step)
				LocationGraphLink.CROSSING_RULE.DOOR:
					var execute_step = PlanStep.new()
					execute_step.step_type = PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_BY_ACTION_ID
					execute_step.object_action_id = Door.ACTION.OPEN
					steps = [execute_step]
				LocationGraphLink.CROSSING_RULE.CROSSWALK:
					var reach_step = PlanStep.new()
					reach_step.step_type = PlanStep.STEP_TYPE.GOTO_POSITION
					reach_step.position = step.link_end_position
					steps = [reach_step]
		
		PlanStep.STEP_TYPE.SEARCH_OBJ_ACTION:
			var obj_action = pick_obj_action(possible_obj_actions)
			
			var reach_step = PlanStep.new()
			reach_step.step_type = PlanStep.STEP_TYPE.GOTO_POSITION
			reach_step.position = obj_action.object.position
			var execute_step = PlanStep.new()
			execute_step.step_type = PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION
			execute_step.object_id = obj_action.object.get_instance_id()
			execute_step.object_action_id = obj_action.object_action_id
			steps = [reach_step, execute_step]

			var object_position = obj_action.object.position
			var distance = player_position.distance_to(object_position)
			if distance >= GLOBAL_DEFINITIONS.MIN_DISTANCE_TO_EXECUTE_ACTION:
				steps = [reach_step, execute_step]
			else:
				steps = [execute_step]
		_:
			steps.append(step)


	return steps

func update(player_position: Vector3, possible_obj_actions: Array, feedback: GLOBAL_DEFINITIONS.AI_FEEDBACK):


	match feedback:
		GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE:
			var step = current_step_stack.pop_back()
			var steps = transform_plan_step(step, player_position,possible_obj_actions)
			

		GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED:
			pass
		GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING:
			pass
		
