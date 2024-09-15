class_name InteractionRules
extends Node


static func build_bt(perception: CHARACTER_CONTROLLER.Perception, witness: CHARACTER_CONTROLLER):
	var callable = Callable(InteractionRules, perception.event)
	var params = [perception.character, witness]
	params.append_array(perception.params)
	return callable.callv(params)

static func WitnessShooting(character: CHARACTER_CONTROLLER, witness: CHARACTER_CONTROLLER, victim: String):
	if witness == character:
		return null
	if character.ai.agent_kb.relationships.get_rel_value(victim, "love") < 0.5:

		return BTRules.Sequence(
				[BTRules.RunHome()]
			)
	return BTRules.Sequence([])
