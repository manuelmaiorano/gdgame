class_name RULES

func build_bt(step: PlanStep):
	var callable = Callable(self, step.name)
	if step.params != null:
		return callable.callv(step.params) 
	return callable.call()

func Goto(should_run) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "Goto"
	bt_node.type = BTInfo.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.GOTO_POSITION
	step.use_stored_pos = true
	step.should_run = should_run
	bt_node.step = step
	return bt_node

func AimAt() :
	var bt_node = AI.BTNode.new()
	bt_node.name = "AimAt"
	bt_node.type = BTInfo.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.AIM_AT
	bt_node.step = step
	return bt_node

func Execute() :
	var bt_node = AI.BTNode.new()
	bt_node.name = "ExexuteStored"
	bt_node.type = BTInfo.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_STORED
	bt_node.step = step
	return bt_node

func ExecuteNearbyByType(type) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "ExexuteStored"
	bt_node.type = BTInfo.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_BY_ACTION_TYPE
	step.object_action_type = type
	bt_node.step = step
	return bt_node

func ExecuteChAction(action) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "ExexuteChAction"
	bt_node.type = BTInfo.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.EXECUTE_NPC_ACTION
	step.player_action_id = action
	bt_node.step = step
	return bt_node

func QueryInventory(type: GLOBAL_DEFINITIONS.OBJECTS = GLOBAL_DEFINITIONS.OBJECTS.NONE) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "QueryInventory"
	bt_node.type = BTInfo.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.QUERY_INVENTORY
	step.obj_type = type
	bt_node.step = step
	return bt_node


func QueryPerson(name, property) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "QueryPerson"
	bt_node.type = BTInfo.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.QUERY_PERSON
	step.who = name
	step.property_name = property
	bt_node.step = step
	return bt_node

func QueryClose(type: GLOBAL_DEFINITIONS.OBJECTS = GLOBAL_DEFINITIONS.OBJECTS.NONE) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "QueryClose"
	bt_node.type = BTInfo.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.QUERY_CLOSE
	step.obj_type = type
	bt_node.step = step
	return bt_node

func QueryUtility() :
	var bt_node = AI.BTNode.new()
	bt_node.name = "QueryUtility"
	bt_node.type = BTInfo.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.QUERY_ACTION_UITILITY
	bt_node.step = step
	return bt_node

func QueryNavigation(loc_name) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "QueryNavigation"
	bt_node.type = BTInfo.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.QUERY_NAVIGATION
	step.location = LocationName.new()
	step.location.place_name = loc_name
	bt_node.step = step
	return bt_node

func ExecuteNavigation():
	var bt_node = AI.BTNode.new()
	bt_node.name = "ExecNavigation"
	bt_node.type = BTInfo.BTNodeType.NAV
	var step = PlanStep.new()
	bt_node.step = step
	return bt_node

func Equip(type: GLOBAL_DEFINITIONS.OBJECTS = GLOBAL_DEFINITIONS.OBJECTS.NONE) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "Equip"
	bt_node.type = BTInfo.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.EQUIP
	step.obj_type = type
	bt_node.step = step
	return bt_node

func UnEquip() :
	var bt_node = AI.BTNode.new()
	bt_node.name = "UnEquip"
	bt_node.type = BTInfo.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.UNEQUIP
	bt_node.step = step
	return bt_node

func Selector(steps):
	var bt_node = AI.BTNode.new()
	bt_node.type = BTInfo.BTNodeType.SELECTOR
	for btstep in steps:
		btstep.parent = bt_node
		bt_node.children.append(btstep)
	
	return bt_node

func Sequence(steps):
	var bt_node = AI.BTNode.new()
	bt_node.type = BTInfo.BTNodeType.SEQUENCE
	for btstep in steps:
		btstep.parent = bt_node
		bt_node.children.append(btstep)
	
	return bt_node

func Retry(btstep, amount):
	var bt_node = AI.BTNode.new()
	bt_node.type = BTInfo.BTNodeType.RETRY
	bt_node.attempts = amount
	btstep.parent = bt_node
	bt_node.children.append(btstep)
	
	return bt_node

func GotoLocation(location_name):
	return Sequence([
		QueryNavigation(location_name),
		ExecuteNavigation()
	])

func SearchObjActionUtility(should_run) :
	return Sequence([
		QueryUtility(),
		Goto(should_run),
		Execute()
	])

func SearchObjAction(type: GLOBAL_DEFINITIONS.OBJECTS = GLOBAL_DEFINITIONS.OBJECTS.NONE) :
	return Sequence([
		QueryClose(type),
		Goto(false),
		Execute()
	])

func AcquireObj(type):
	return Selector([
		QueryInventory(type),
		SearchObjAction(type)
	])

func EquipObj(type):
	return Sequence([
		AcquireObj(type),
		Equip()
	])

func ShootPerson(name):
	return Selector([
		Sequence([
			EquipObj(GLOBAL_DEFINITIONS.OBJECTS.PISTOL),
			Retry(
				Sequence([
					QueryPerson(name, "global_position"),
					AimAt(),
					#ExecuteChAction(GLOBAL_DEFINITIONS.CHARACTER_ACTION.SHOOT),
					QueryPerson(name, "ragdoll")
					]),
				10
			),
			UnEquip()
		]),
		UnEquip()
	])

func OpenNearbyDoor():
	return Selector([
		ExecuteNearbyByType(Door.ACTION.OPEN),
		Sequence([
			ExecuteNearbyByType(Door.ACTION.UNLOCK),
			ExecuteNearbyByType(Door.ACTION.OPEN),
		])
	])

func CrossCrossWalk():
	return Selector([
		ExecuteNearbyByType(Door.ACTION.OPEN),
		Sequence([
			ExecuteNearbyByType(Door.ACTION.UNLOCK),
			ExecuteNearbyByType(Door.ACTION.OPEN),
		])
	])
