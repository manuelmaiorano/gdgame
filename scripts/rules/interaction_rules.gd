class_name InteractionRules
extends Node


static func build_bt(perception: CHARACTER_CONTROLLER.Perception, witness):
	var callable = Callable(InteractionRules, perception.event)
	return callable.callv([perception.character, null, witness])

static func WitnessShooting(character: CHARACTER_CONTROLLER, victim: CHARACTER_CONTROLLER, witness: CHARACTER_CONTROLLER):
	if witness == character:
		return null
	if character.ai.agent_kb.relationships.get_rel_value(victim, "love") < 0.5:

		return BTRules.Sequence(
				[BTRules.RunHome()]
			)
	return BTRules.Sequence([])
