extends Node3D

const MIN_DISTANCE_TO_EXECUTE_ACTION = 1.0

@export var hunger_curve: Curve
@export var comfort_curve: Curve
@export var hygiene_curve: Curve
@export var bladder_curve: Curve
@export var energy_curve: Curve
@export var fun_curve: Curve
@export var social_curve: Curve
@export var room_curve: Curve


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
		
func get_next_actions(position: Vector3, far_objects: Dictionary, close_objects: Array, reached: bool, motion: Vector2, current_car):
	var agent_input = GLOBAL_DEFINITIONS.AgentInput.new()
	if reached:
		going = false
	
	if going == true:
		return agent_input
	
	var scores: Array[ActionScore] = []
	for idx in close_objects.size():
		var action_info = close_objects[idx]
		#get action score
		var adv: GLOBAL_DEFINITIONS.ObjectAdvertisement = action_info.object.get_action_adv(action_info.object_action_id)
		
		var action_score = ActionScore.new()
		var score = get_object_score(state.needs, adv)
		action_score.score = score
		action_score.idx = idx
		action_score.adv = adv
		scores.append(action_score)
		
	scores.sort_custom(func(a, b): return a.score > b.score)
	var top_four = scores.slice(0, 3)
	var chosen = top_four.pick_random()
	
	#distance from object
	var object_position = close_objects[chosen.idx].object.position
	var distance = position.distance_to(object_position)
	if distance <= MIN_DISTANCE_TO_EXECUTE_ACTION:#execute
		agent_input.action_id = chosen.idx
		fulfill_object_adv(state.needs, chosen.adv)
	else: #reach object
		agent_input.going = true
		agent_input.next_pos = object_position
		going = true

	return agent_input
	

