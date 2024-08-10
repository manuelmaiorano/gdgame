extends CharacterBody3D

enum ANIMATIONS {JUMP_UP, JUMP_DOWN, STRAFE, WALK}
enum CHARACTER_ACTION {SIT, THROW, OPEN, PICK}

const DIRECTION_INTERPOLATE_SPEED = 1
const MOTION_INTERPOLATE_SPEED = 10
const ROTATION_INTERPOLATE_SPEED = 10

const MIN_AIRBORNE_TIME = 0.7
const JUMP_SPEED = 5

const AI_RATE = 30

var ai_counter = 0

var airborne_time = 100

var orientation = Transform3D()
var root_motion = Transform3D()
var motion = Vector2()

@onready var initial_position = transform.origin
@onready var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * ProjectSettings.get_setting("physics/3d/default_gravity_vector")

@onready var player_input = $ControllablePlayer/InputSynchronizer
@onready var animation_tree = $AnimationManager/AnimationTree
@onready var player_model = $Human_rig
@onready var action_label = $ControllablePlayer/UI/Actions/RichTextLabel
@onready var close_interaction_area = $InteractionAreas/CloseInteraction
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D


@onready var fire_cooldown: Timer = $FireCoolDown
@onready var shoot_from = $Human_rig/GeneralSkeleton/GunBone/ShootFrom
@onready var sound_effects = $SoundEffects
@onready var sound_effect_shoot = sound_effects.get_node("Shoot")

@export var player_id := 1 :
	set(value):
		player_id = value
		$InputSynchronizer.set_multiplayer_authority(value)

@export var current_animation := ANIMATIONS.WALK
@onready var inside_car = false
@onready var ragdoll = false
@onready var current_pistol = null
@onready var current_car = null
@onready var seated = false
@onready var reached = false
@onready var agent_input = GLOBAL_DEFINITIONS.AgentInput.new()

class ActionInfo:
	var object
	var object_action_id
	var player_action_id
	var desc
	
@onready var possible_actions: Array[ActionInfo] = []

@onready var step_execution_state = GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
@onready var action_successful = true
@onready var action_done = false

@onready var controlled_by_player = false

func _ready():
	Characters.register(self)
	if name == Characters.player_controlled_character:
		controlled_by_player = true
		$ControllablePlayer/CameraBase/CameraRot/SpringArm3D/Camera3D.make_current()
	# Pre-initialize orientation transform.
	orientation = player_model.global_transform
	orientation.origin = Vector3()
	if not multiplayer.is_server():
		set_process(false)
	navigation_agent.velocity_computed.connect(Callable(_on_velocity_computed))
	
	close_interaction_area.area_entered.connect(_on_close_interaction_entered)
	close_interaction_area.area_exited.connect(_on_close_interaction_exited)
	close_interaction_area.body_entered.connect(_on_body_collision)
	
	if not controlled_by_player:
		$ControllablePlayer/UI.hide()

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	pass
	#velocity = safe_velocity
	#move_and_slide()

func execute_step(step: PlanStep):
	match step.step_type:
		PlanStep.STEP_TYPE.GOTO_POSITION:
			set_movement_target(step.position)
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING
		PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION:
			action_done = false
			for idx in possible_actions.size():

				var x = possible_actions[idx]
				if x.object.get_instance_id() == step.object_id and x.action_id == step.object_action_id:
					agent_input.action_id = idx
					return GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING
					
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED
		
		PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_BY_ACTION_ID:
			action_done = false
			for idx in possible_actions.size():

				var x = possible_actions[idx]
				if global_position.distance_to(x.object.global_position) < GLOBAL_DEFINITIONS.MIN_DISTANCE_TO_EXECUTE_ACTION and x.action_id == step.object_action_id:
					agent_input.action_id = idx
					return GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING
					
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED

		PlanStep.STEP_TYPE.EXECUTE_NPC_ACTION:
			match step.player_action_id:
				GLOBAL_DEFINITIONS.CHARACTER_ACTION.PUNCH:
					agent_input.punching = true
				GLOBAL_DEFINITIONS.CHARACTER_ACTION.KICK:
					agent_input.kicking = true
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
		_:
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE

func check_completion(step: PlanStep, navigation_completed: bool):
	match step.step_type:
		PlanStep.STEP_TYPE.GOTO_POSITION:
			if not navigation_completed:
				return GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING
			if navigation_completed and global_position.distance_to(step.position) < 1.0:
				return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED
		PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_BY_ACTION_ID or PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION:
			if action_done:
				if action_successful:
					return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
				return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING
		_:
			pass

func abort(step: PlanStep):
	match step.step_type:
		PlanStep.STEP_TYPE.GOTO_POSITION:
			set_movement_target(global_position)
		_:
			pass

func update_ai(player_position: Vector3, possible_obj_actions: Array[ActionInfo]):
	var should_abort = $AI.update(player_position, possible_obj_actions, step_execution_state, CurrentTimeManager.get_current_time_in_minutes())
	var current_step: PlanStep = $AI.current_step_task
	if current_step:
		DebugView.print_debug_info("STEP: %s" % current_step.name, self)
		match step_execution_state:
			GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE:
				step_execution_state = execute_step(current_step)
			GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED:
				step_execution_state = execute_step(current_step)
			GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING:
				step_execution_state = check_completion(current_step, navigation_agent.is_navigation_finished())

	if should_abort:
		abort(current_step)
		step_execution_state = GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE

func set_movement_target(movement_target: Vector3):
	navigation_agent.set_target_position(movement_target)
	reached = false
	
func _physics_process(delta: float):
	if controlled_by_player:
		if multiplayer.is_server():
			apply_input(delta)
		else:
			animate(current_animation, delta)
	else:
		if should_update_ai():
			update_ai(global_position, possible_actions)
			#agent_input = $AI.get_next_actions(position, possible_actions, reached, agent_input.motion, current_car)
		if navigation_agent.is_navigation_finished():
			agent_input.motion = Vector2()
			reached = true
		else:
			var next_path_position: Vector3 = navigation_agent.get_next_path_position()
			var vector_to: Vector3 = global_position.direction_to(next_path_position).normalized()
			agent_input.motion = Vector2(vector_to.x, vector_to.z)
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
		global_position = $Human_rig/GeneralSkeleton/PhysicalsBoneHips.global_position
		return
	if controlled_by_player:
		agent_input = player_input
	motion = motion.lerp(agent_input.motion, MOTION_INTERPOLATE_SPEED * delta)

	var camera_basis : Basis =  agent_input.get_camera_rotation_basis() if controlled_by_player else Basis(orientation.basis)
	var camera_z := camera_basis.z
	var camera_x := camera_basis.x

	camera_z.y = 0
	camera_z = camera_z.normalized()
	camera_x.y = 0
	camera_x = camera_x.normalized()
	
	if current_car:
		var target = camera_x * motion.x + camera_z * motion.y if controlled_by_player else Vector3(motion.x, 0, motion.y)
		current_car.set_motion(motion)
		global_position = current_car.global_position
		return
	
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
		var q_to = agent_input.get_camera_base_quaternion() if controlled_by_player else agent_input.q_to
		# Interpolate current rotation with desired one.
		orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

		# Change state to strafe.
		animate(ANIMATIONS.STRAFE, delta)
		
		if agent_input.shooting and fire_cooldown.time_left == 0:
			var shoot_origin = shoot_from.global_transform.origin
			var shoot_dir = (agent_input.shoot_target - shoot_origin).normalized()

			var bullet = preload("res://scenes/props/weapons/bullet.tscn").instantiate()
			get_parent().add_child(bullet, true)
			bullet.global_transform.origin = shoot_origin
			# If we don't rotate the bullets there is no useful way to control the particles ..
			bullet.look_at(shoot_origin + shoot_dir, Vector3.UP)
			bullet.add_collision_exception_with(self)
			shoot.rpc()
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
	else: # Not in air or aiming, idle.
		# Convert orientation to quaternions for interpolating rotation.
		var target = camera_x * motion.x + camera_z * motion.y if controlled_by_player else Vector3(motion.x, 0, motion.y)
		if target.length() > 0.001:
			var q_from = orientation.basis.get_rotation_quaternion()
			var use_nod_front = false if controlled_by_player else true
			var q_to = Transform3D().looking_at(target, Vector3.UP, use_nod_front).basis.get_rotation_quaternion()
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
	
	if not (motion.length() < 0.001 and animation_tree["parameters/state/current_state"] == "walk"):# or seated:#to fix
		orientation *= root_motion
	
	var h_velocity = orientation.origin / delta

	velocity.x = h_velocity.x
	velocity.z = h_velocity.z
	if not seated:
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
		#do_action_by_number(agent_input.action_id)
		action_successful = do_action_by_number_list(agent_input.action_id)
		action_done = true
		
func execute_action(action_info: ActionInfo):
	var object = action_info.object
	var is_successful = object.act(action_info.object_action_id, player_id)
	if not controlled_by_player and not is_successful:
		return false
	if not controlled_by_player:
		$AI.fulfill_object_adv(object.get_action_adv(action_info.object_action_id))
	match action_info.player_action_id:
		GLOBAL_DEFINITIONS.CHARACTER_ACTION.PICK: 
			animation_tree["parameters/state/transition_request"] = "pick"
			current_pistol = object
			current_pistol.reparent($Human_rig/GeneralSkeleton/GunBone/ShootFrom)
			#current_pistol.transform = Transform3D(Basis(Quaternion(0.51, 0.53, 0.47, -0.48)), Vector3(-0.01, -0.014, 0.048))
			current_pistol.transform = Transform3D(Basis.from_euler(Vector3(-1.57, -1.57 , 0)), Vector3(0, 0, 0))
		GLOBAL_DEFINITIONS.CHARACTER_ACTION.THROW: 
			animation_tree["parameters/state/transition_request"] = "throw"
		GLOBAL_DEFINITIONS.CHARACTER_ACTION.SIT: 
			animation_tree["parameters/state/transition_request"] = "sit"
			animation_tree["parameters/sit/conditions/stand"] =  false
			var sit_position: Transform3D = object.get_node("SitPosition").global_transform
			global_position.x = sit_position.origin.x
			global_position.z = sit_position.origin.z
			orientation.basis = sit_position.basis
			$CollisionShape3D.disabled = true
			seated = true
		GLOBAL_DEFINITIONS.CHARACTER_ACTION.STAND: 
			animation_tree["parameters/sit/conditions/stand"] =  true
			$CollisionShape3D.disabled = false
			seated = false
		GLOBAL_DEFINITIONS.CHARACTER_ACTION.OPEN: 
			pass
			#animation_tree["parameters/state/transition_request"] = "open"
		GLOBAL_DEFINITIONS.CHARACTER_ACTION.ENTER_CAR:
			current_car = object
			$CollisionShape3D.disabled = true
			hide()
		GLOBAL_DEFINITIONS.CHARACTER_ACTION.EXIT_CAR:
			current_car = null
			$CollisionShape3D.disabled = false
			show()
	return true
	
func do_action_by_number_list(num):
	if controlled_by_player:
		num -= 1
	if num < possible_actions.size():
		return execute_action(possible_actions[num])
	return false

			
func update_action_labels_list():
	action_label.clear()
	for action_info_idx in possible_actions.size():
		var action_info = possible_actions[action_info_idx]
		action_label.append_text("%d : %s \n" % [action_info_idx+1, action_info.desc])
		
		
	
func _on_actions_update(object):
	remove_object_from_action_list(object)
	if object.has_method("set_player"):
		object.set_player(self)
	for action in object.get_possible_actions(player_id):
		
		var action_info_list = ActionInfo.new()
		action_info_list.object = object
		action_info_list.desc = object.get_action_description(action)
		action_info_list.player_action_id = object.get_player_action(action)
		action_info_list.object_action_id = action
		
		possible_actions.push_back(action_info_list)
		
	update_action_labels_list()
	

func _on_close_interaction_entered(area):
	var object = area.get_parent()
	if not object.has_method("get_possible_actions"):
		return
	_on_actions_update(object)
	object.state_changed.connect(_on_actions_update)
	
func _on_close_interaction_exited(area):
	var object = area.get_parent()
	if not object.has_method("get_possible_actions"):
		return
	
	remove_object_from_action_list(object)
	
	object.state_changed.disconnect(_on_actions_update)
	update_action_labels_list()


@rpc("call_local")
func shoot():
	#var shoot_particle = $PlayerModel/Robot_Skeleton/Skeleton3D/GunBone/ShootFrom/ShootParticle
	#shoot_particle.restart()
	#shoot_particle.emitting = true
	#var muzzle_particle = $PlayerModel/Robot_Skeleton/Skeleton3D/GunBone/ShootFrom/MuzzleFlash
	#muzzle_particle.restart()
	#muzzle_particle.emitting = true
	fire_cooldown.start()
	sound_effect_shoot.play()
	#add_camera_shake_trauma(0.35)
	

func _on_body_collision(body: PhysicsBody3D):
	if body is RigidBody3D:
		if body.linear_velocity.length() > 5:
			hit()
	
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
	
func remove_object_from_action_list(object):
	var index_to_remove = []
	for action_info_idx in possible_actions.size():
		var action_info = possible_actions[action_info_idx]
		if action_info.object == object:
			index_to_remove.push_back(action_info_idx)
	
	var new_possible_actions: Array[ActionInfo] = []
	for action_info_idx in possible_actions.size():
		if index_to_remove.find(action_info_idx) == -1:
			new_possible_actions.push_back(possible_actions[action_info_idx])
	possible_actions = new_possible_actions

func should_update_ai():
	if ai_counter > AI_RATE:
		ai_counter = 0
		return true
	ai_counter += 1
	return false
