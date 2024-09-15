class_name BTRules
extends Node

static func build_bt(step: PlanStep):
	var callable = Callable(BTRules, step.name)
	if step.params != null:
		return callable.callv(step.params) 
	return callable.call()

static func Goto(should_run) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "Goto"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.GOTO_POSITION
	step.use_stored_pos = true
	step.should_run = should_run
	bt_node.step = step
	return bt_node

static func AimAt() :
	var bt_node = AI.BTNode.new()
	bt_node.name = "AimAt"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.AIM_AT
	bt_node.step = step
	return bt_node

static func BroadCast(event, params) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "AimAt"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.BROADCAST
	step.who = event
	step.params = params
	bt_node.step = step
	return bt_node

static func Execute() :
	var bt_node = AI.BTNode.new()
	bt_node.name = "ExexuteStored"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_STORED
	bt_node.step = step
	return bt_node

static func ExecuteNearbyByType(type) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "ExexuteStored"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_BY_ACTION_TYPE
	step.object_action_type = type
	bt_node.step = step
	return bt_node

static func ExecuteChAction(action) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "ExexuteChAction"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.EXECUTE_NPC_ACTION
	step.player_action_id = action
	bt_node.step = step
	return bt_node

static func QueryInventory(type: GLOBAL_DEFINITIONS.OBJECTS = GLOBAL_DEFINITIONS.OBJECTS.NONE) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "QueryInventory"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.QUERY_INVENTORY
	step.obj_type = type
	bt_node.step = step
	return bt_node


static func QueryPerson(name, property) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "QueryPerson"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.QUERY_PERSON
	step.who = name
	step.property_name = property
	bt_node.step = step
	return bt_node

static func QueryClose(type: GLOBAL_DEFINITIONS.OBJECTS = GLOBAL_DEFINITIONS.OBJECTS.NONE) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "QueryClose"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.QUERY_CLOSE
	step.obj_type = type
	bt_node.step = step
	return bt_node

static func QueryUtility() :
	var bt_node = AI.BTNode.new()
	bt_node.name = "QueryUtility"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.QUERY_ACTION_UITILITY
	bt_node.step = step
	return bt_node

static func QueryNavigation(loc_name) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "QueryNavigation"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.QUERY_NAVIGATION
	step.location = LocationName.new()
	step.location.place_name = loc_name
	bt_node.step = step
	return bt_node

static func ExecuteNavigation(should_run):
	var bt_node = AI.BTNode.new()
	bt_node.name = "ExecNavigation"
	bt_node.type = AI.BTNodeType.NAV
	var step = PlanStep.new()
	step.should_run = should_run
	bt_node.step = step
	return bt_node

static func Equip(type: GLOBAL_DEFINITIONS.OBJECTS = GLOBAL_DEFINITIONS.OBJECTS.NONE) :
	var bt_node = AI.BTNode.new()
	bt_node.name = "Equip"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.EQUIP
	step.obj_type = type
	bt_node.step = step
	return bt_node

static func UnEquip() :
	var bt_node = AI.BTNode.new()
	bt_node.name = "UnEquip"
	bt_node.type = AI.BTNodeType.TASK
	var step = PlanStep.new()
	step.step_type = PlanStep.STEP_TYPE.UNEQUIP
	bt_node.step = step
	return bt_node

static func Selector(steps):
	var bt_node = AI.BTNode.new()
	bt_node.type = AI.BTNodeType.SELECTOR
	for btstep in steps:
		btstep.parent = bt_node
		bt_node.children.append(btstep)
	
	return bt_node

static func Sequence(steps):
	var bt_node = AI.BTNode.new()
	bt_node.type = AI.BTNodeType.SEQUENCE
	for btstep in steps:
		btstep.parent = bt_node
		bt_node.children.append(btstep)
	
	return bt_node

static func Retry(btstep, amount):
	var bt_node = AI.BTNode.new()
	bt_node.type = AI.BTNodeType.RETRY
	bt_node.attempts = amount
	btstep.parent = bt_node
	bt_node.children.append(btstep)
	
	return bt_node

static func GotoLocation(location_name, should_run):
	return Sequence([
		QueryNavigation(location_name),
		ExecuteNavigation(should_run)
	])

static func SearchObjActionUtility(should_run) :
	return Sequence([
		QueryUtility(),
		Goto(should_run),
		Execute()
	])

static func SearchObjAction(type: GLOBAL_DEFINITIONS.OBJECTS = GLOBAL_DEFINITIONS.OBJECTS.NONE) :
	return Sequence([
		QueryClose(type),
		Goto(false),
		Execute()
	])

static func AcquireObj(type):
	return Selector([
		QueryInventory(type),
		SearchObjAction(type)
	])

static func EquipObj(type):
	return Sequence([
		AcquireObj(type),
		Equip()
	])

static func ShootPerson(name):
	return Selector([
		Sequence([
			EquipObj(GLOBAL_DEFINITIONS.OBJECTS.PISTOL),
			BroadCast("WitnessShooting", [name]),
			Retry(
				Sequence([
					QueryPerson(name, "global_position"),
					AimAt(),
					ExecuteChAction(GLOBAL_DEFINITIONS.CHARACTER_ACTION.SHOOT),
					QueryPerson(name, "ragdoll")
					]),
				30
			),
			UnEquip()
		]),
		UnEquip()
	])

static func OpenNearbyDoor():
	return Selector([
		ExecuteNearbyByType(Door.ACTION.OPEN),
		Sequence([
			ExecuteNearbyByType(Door.ACTION.UNLOCK),
			ExecuteNearbyByType(Door.ACTION.OPEN),
		])
	])

static func CrossCrossWalk():
	return Selector([
		ExecuteNearbyByType(Door.ACTION.OPEN),
		Sequence([
			ExecuteNearbyByType(Door.ACTION.UNLOCK),
			ExecuteNearbyByType(Door.ACTION.OPEN),
		])
	])

static func RunHome():
	return Retry(
		GotoLocation("home", true), 3
	)
