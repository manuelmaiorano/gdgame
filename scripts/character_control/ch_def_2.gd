extends CharacterBody3D

enum ANIMATIONS {JUMP_UP, JUMP_DOWN, STRAFE, WALK}

const DIRECTION_INTERPOLATE_SPEED = 1
const MOTION_INTERPOLATE_SPEED = 10
const ROTATION_INTERPOLATE_SPEED = 10

const MIN_AIRBORNE_TIME = 0.7
const JUMP_SPEED = 5

var airborne_time = 100

var orientation = Transform3D()
var root_motion = Transform3D()
var motion = Vector2()

@onready var initial_position = transform.origin
@onready var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * ProjectSettings.get_setting("physics/3d/default_gravity_vector")

@onready var animation_tree = $AnimationManager/AnimationTree
@onready var player_model = $Human_rig


@export var current_animation := ANIMATIONS.WALK
#@export var current_interaction := ACTIONS.NONE

@onready var ragdoll = false

#@onready var current_door = null
@onready var current_pistol = null
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var agent_input = GLOBAL_DEFINITIONS.AgentInput.new()
class ActionInfo:
	var object_action_id
	var player_action_id
	var desc
	
@onready var objects_to_actions: Dictionary = {}

func _ready():
	# Pre-initialize orientation transform.
	orientation = player_model.global_transform
	orientation.origin = Vector3()
	if not multiplayer.is_server():
		set_process(false)
	navigation_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	schedule_plan()
	
func schedule_plan():
	while true:
		await get_tree().create_timer(3.0).timeout

		set_movement_target(get_parent().find_child("ch_def1").transform.origin)
	#await get_tree().create_timer(3.0).timeout
	#set_movement_target(get_tree().get_root().get_node("Main/Location3").transform.origin)
	#await get_tree().create_timer(3.0).timeout
	#set_movement_target(get_tree().get_root().get_node("Main/Location1").transform.origin)
	#await get_tree().create_timer(5.0).timeout
	#set_movement_target(get_tree().get_root().get_node("Main/Location2").transform.origin)
	#await get_tree().create_timer(5.0).timeout
	#set_movement_target(get_tree().get_root().get_node("Main/Location4").transform.origin)
	#await get_tree().create_timer(10.0).timeout
	#set_movement_target(get_tree().get_root().get_node("Main/Location5").transform.origin)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	pass

func set_movement_target(movement_target: Vector3):
	navigation_agent.set_target_position(movement_target)
	
func _physics_process(delta: float):
	if navigation_agent.is_navigation_finished():
		agent_input.motion = Vector2()
	else:
		var next_path_position: Vector3 = navigation_agent.get_next_path_position()
		var vector_to: Vector3 = global_position.direction_to(next_path_position).normalized()
		#vector_to.y = 0
		#vector_to = vector_to.normalized()
		agent_input.motion = Vector2(vector_to.x, vector_to.z)
		#print(vector_to)
		#if navigation_agent.avoidance_enabled:
			#navigation_agent.set_velocity(new_velocity)
		#else:
			#_on_velocity_computed(new_velocity)
	apply_input(delta)


func animate(anim: int, delta:=0.0):
	current_animation = anim

	if anim == ANIMATIONS.JUMP_DOWN:
		animation_tree["parameters/state/transition_request"] = "fall"
	elif anim == ANIMATIONS.STRAFE:
		animation_tree["parameters/state/transition_request"] = "strafe"
		# Change aim according to camera rotation.
		#animation_tree["parameters/aim/add_amount"] = player_input.get_aim_rotation()
		# The animation's forward/backward axis is reversed.
		animation_tree["parameters/strafe/blend_position"] = Vector2(motion.x, -motion.y)

	elif anim == ANIMATIONS.WALK:
		# Aim to zero (no aiming while walking).
		#animation_tree["parameters/aim/add_amount"] = 0
		# Change state to walk.
		animation_tree["parameters/state/transition_request"] = "walk"
		animation_tree["parameters/walk/blend_position"] = motion.length()
		# Blend position for walk speed based checked motion.
		if agent_input.running:
			animation_tree["parameters/run/transition_request"] = "run"
		else:
			animation_tree["parameters/run/transition_request"] = "walk"
		


func apply_input(delta: float):
	if ragdoll:
		return
	motion = motion.lerp(agent_input.motion, MOTION_INTERPOLATE_SPEED * delta)

	var camera_basis : Basis = Basis(orientation.basis)
	var camera_z := camera_basis.z
	var camera_x := camera_basis.x

	camera_z.y = 0
	camera_z = camera_z.normalized()
	camera_x.y = 0
	camera_x = camera_x.normalized()
	
	# pistol hide
	if not agent_input.aiming and current_pistol:
		current_pistol.hide()

	# Jump/in-air logic.
	airborne_time += delta
	if is_on_floor():
		if airborne_time > 0.5:
			animate(ANIMATIONS.WALK, delta)
		airborne_time = 0

	var on_air = airborne_time > MIN_AIRBORNE_TIME

	if on_air:
		if (velocity.y <0): 
			animate(ANIMATIONS.JUMP_DOWN, delta)
	elif agent_input.aiming and current_pistol != null:
		current_pistol.show()
		# Convert orientation to quaternions for interpolating rotation.
		var q_from = orientation.basis.get_rotation_quaternion()
		var q_to = agent_input.get_camera_base_quaternion()
		# Interpolate current rotation with desired one.
		orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

		# Change state to strafe.
		animate(ANIMATIONS.STRAFE, delta)
	elif animation_tree["parameters/state/current_state"] == "combat":
		if animation_tree["parameters/combat/playback"].get_current_node() == "basic_f_idle":
			animate(ANIMATIONS.WALK, delta)
	elif animation_tree["parameters/state/current_state"] == "talk":
		if agent_input.talking:
			animation_tree["parameters/state/transition_request"] = "walk"
	elif animation_tree["parameters/state/current_state"] == "sit":
		if animation_tree["parameters/sit/playback"].get_current_node() == "basic_f_idle":
			animate(ANIMATIONS.WALK, delta)
	elif animation_tree["parameters/state/current_state"] == "throw":
		if animation_tree["parameters/throw/playback"].get_current_node() == "basic_f_idle":
			animate(ANIMATIONS.WALK, delta)
	elif animation_tree["parameters/state/current_state"] == "open":
		if animation_tree["parameters/open/playback"].get_current_node() == "basic_f_idle":
			animate(ANIMATIONS.WALK, delta)
	elif animation_tree["parameters/state/current_state"] == "pick":
		if animation_tree["parameters/pick/playback"].get_current_node() == "basic_f_idle":
			animate(ANIMATIONS.WALK, delta)
	elif animation_tree["parameters/state/current_state"] == "hit":
		if animation_tree["parameters/hit/playback"].get_current_node() == "basic_f_idle":
			animate(ANIMATIONS.WALK, delta)
	else: # Not in air or aiming, idle.
		# Convert orientation to quaternions for interpolating rotation.
		var target = camera_x * motion.x + camera_z * motion.y
		target = Vector3(motion.x, 0, motion.y)
		if target.length() > 0.001:
			var q_from = orientation.basis.get_rotation_quaternion()
			var q_to = Transform3D().looking_at(target, Vector3.UP, true).basis.get_rotation_quaternion()
			# Interpolate current rotation with desired one.
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))
		
		animate(ANIMATIONS.WALK, delta)
		if agent_input.jumping and not animation_tree["parameters/jump/active"]:
			animation_tree["parameters/jump/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
			agent_input.jumping = false
		if agent_input.punching:
			animation_tree["parameters/state/transition_request"] = "combat"
			animation_tree["parameters/combat/choose_action/blend_position"] = 1
		if agent_input.kicking:
			animation_tree["parameters/state/transition_request"] = "combat"
			animation_tree["parameters/combat/choose_action/blend_position"] = -1
		if agent_input.talking:
			animation_tree["parameters/state/transition_request"] = "talk"


	root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())
	
	orientation *= root_motion
	
	var h_velocity = orientation.origin / delta

	velocity.x = h_velocity.x
	velocity.z = h_velocity.z
	if animation_tree["parameters/jump/active"] and not on_air:
		velocity.y = h_velocity.y
	else:
		velocity += gravity * delta
	if on_air:
		velocity += gravity * delta
	
	set_velocity(velocity)
	set_up_direction(Vector3.UP)
	move_and_slide()

	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # Orthonormalize orientation.

	player_model.global_transform.basis = orientation.basis

	# If we're below -40, respawn (teleport to the initial position).
	if transform.origin.y < -40:
		transform.origin = initial_position

	
func _process(delta):
	
	if agent_input.action_id > 0:
		do_action_by_number(agent_input.action_id)
	
func do_action_by_number(num):
	var i := 0
	for object in objects_to_actions:
		for action_info: ActionInfo in objects_to_actions[object]:
			i += 1
			if i == num: 
				object.act(action_info.object_action_id)
				match action_info.player_action_id:
					GLOBAL_DEFINITIONS.CHARACTER_ACTION.PICK: 
						animation_tree["parameters/state/transition_request"] = "pick"
						current_pistol = object
						current_pistol.reparent($Human_rig/GeneralSkeleton/BoneAttachment3D)
						current_pistol.transform = Transform3D(Basis(Quaternion(0.51, 0.53, 0.47, -0.48)), Vector3(-0.01, -0.014, 0.048))
					GLOBAL_DEFINITIONS.CHARACTER_ACTION.THROW: 
						animation_tree["parameters/state/transition_request"] = "throw"
					GLOBAL_DEFINITIONS.CHARACTER_ACTION.SIT: 
						animation_tree["parameters/state/transition_request"] = "sit"
						animation_tree["parameters/sit/conditions/stand"] =  false
					GLOBAL_DEFINITIONS.CHARACTER_ACTION.STAND: 
						animation_tree["parameters/sit/conditions/stand"] =  true
					GLOBAL_DEFINITIONS.CHARACTER_ACTION.OPEN: 
						animation_tree["parameters/state/transition_request"] = "open"
				return

func _on_actions_update(object):
	objects_to_actions[object] = []
	for action in object.get_possible_actions():
		var action_info = ActionInfo.new()
		action_info.desc = object.get_action_description(action)
		action_info.player_action_id = object.get_player_action(action)
		action_info.object_action_id = action
		
		objects_to_actions[object].push_back(action_info)
	

func _on_area_3d_area_entered(area):
	var object = area.get_parent()
	_on_actions_update(object)
	object.state_changed.connect(_on_actions_update)
	
func _on_area_3d_area_exited(area):
	var object = area.get_parent()
	objects_to_actions.erase(object)
	object.state_changed.disconnect(_on_actions_update)
	
@rpc("call_local")
func hit():
	$Human_rig/GeneralSkeleton.physical_bones_start_simulation()
	ragdoll = true
	schedule_ragdoll_end()
	#animation_tree["parameters/state/transition_request"] = "hit"
	
	
func schedule_ragdoll_end():
	await get_tree().create_timer(10.0).timeout
	$Human_rig/GeneralSkeleton.physical_bones_stop_simulation()
	ragdoll = false
