extends VehicleBody3D
class_name Car
enum ACTION {ENTER, EXIT}

signal state_changed(me)

var entered = false

@onready var motion = Vector2()

const STEER_SPEED = 1.5
const STEER_LIMIT = 0.4
var mouse_sensitivity = 0.005
var MAX_RPM = 500
var MAX_TRQ = 200
@export var engine_force_value =1

var steer_target = 0

func enter():
	if entered:
		return
	entered = true
	
func exit():
	if not entered:
		return
	entered = false

func get_possible_actions(player_id):
	if entered:
		return [ACTION.EXIT]
	return [ACTION.ENTER]
	
func get_player_action(action: ACTION):
	match action:
		ACTION.ENTER: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.ENTER_CAR
		ACTION.EXIT: return GLOBAL_DEFINITIONS.CHARACTER_ACTION.EXIT_CAR
		
func get_action_description(action: ACTION):
	match action:
		ACTION.ENTER: return "Enter the car"
		ACTION.EXIT: return "Exit the car"
		
func act(action: ACTION, player_id):
	match action:
		ACTION.ENTER: enter()
		ACTION.EXIT: exit()
	state_changed.emit(self)
	
func set_motion(m):
	motion = Vector2(m)
	
func _physics_process(delta):
	if not entered:
		return

	var fwd_mps = (transform.basis.inverse() * linear_velocity).x

	steer_target = -motion.x
	steer_target *= STEER_LIMIT
	
	var acc = -motion.y

	steering = move_toward(steering, steer_target, STEER_SPEED * delta)
	var rpm = abs($Wheel_RL.get_rpm())
	$Wheel_RL.engine_force = acc * MAX_TRQ * (1-rpm/MAX_RPM)
	
	rpm = abs($Wheel_RR.get_rpm())
	$Wheel_RR.engine_force = acc * MAX_TRQ * (1-rpm/MAX_RPM)


func get_object_id():
	return GLOBAL_DEFINITIONS.OBJECTS.CAR
