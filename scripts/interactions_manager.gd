class_name InteractionsManager
extends Node


func build_bt(perception: CHARACTER_CONTROLLER.Perception, witness):
	var callable = Callable(self, perception.event)
	return callable.callv([perception.character, null, witness])

func WitnessShooting(character: CHARACTER_CONTROLLER, victim: CHARACTER_CONTROLLER, witness: CHARACTER_CONTROLLER):
	if character.ai.agent_kb.relationships[victim].love < 0.5:

		return BtRulesManager.Sequence(
			[BtRulesManager.RunHome()]
			)
