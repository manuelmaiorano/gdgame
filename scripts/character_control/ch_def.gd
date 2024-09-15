extends CharacterBody3D
class_name CHARACTER_CONTROLLER

enum ANIMATIONS {JUMP_UP, JUMP_DOWN, STRAFE, WALK}
enum CHARACTER_ACTION {SIT, THROW, OPEN, PICK}

const DIRECTION_INTERPOLATE_SPEED = 1
const MOTION_INTERPOLATE_SPEED = 10
const ROTATION_INTERPOLATE_SPEED = 10

const MIN_AIRBORNE_TIME = 0.7
const JUMP_SPEED = 5

const AI_RATE = 10

var ai_counter = 0

var airborne_time = 100

var orientation = Transform3D()
var root_motion = Transform3D()
var motion = Vector2()

@onready var initial_position = transform.origin
@onready var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * ProjectSettings.get_setting("physics/3d/default_gravity_vector")

@onready var player_input = $ControllablePlayer/InputSynchronizer
@onready var animation_tree = $AnimationManager/AnimationTree
@onready var player_model = $GeneralSkeleton
@onready var action_label = $ControllablePlayer/UI/Actions/RichTextLabel
@onready var close_interaction_area = $InteractionAreas/CloseInteraction
@onready var far_interaction_area = $InteractionAreas/FarInteraction
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var ai: AI = $AI


@onready var fire_cooldown: Timer = $FireCoolDown
@onready var shoot_from = $GeneralSkeleton/GunBone/ShootFrom

@onready var sound_effects = $SoundEffects
@onready var sound_effect_shoot = sound_effects.get_node("Shoot")

@export var player_id := 1 :
	set(value):
		player_id = value
		$InputSynchronizer.set_multiplayer_authority(value)

@export var current_animation := ANIMATIONS.WALK
@onready var inside_car = false
@onready var ragdoll = false
#@onready var current_pistol = null
@onready var current_car = null
#@onready var seated = false
#@onready var reached = false
@onready var agent_input = GLOBAL_DEFINITIONS.AgentInput.new()

class ActionInfo:
	var object
	var object_action_id
	var player_action_id
	var desc

class Perception:
	var event: String
	var params
	var character
	
@onready var possible_actions: Array[ActionInfo] = []
@onready var perceptions: Array[Perception] = []

@onready var step_execution_state = GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
@onready var action_successful = true
@onready var action_done = false
#@onready var variables: Dictionary = {}
@onready var variables_stack = []
@onready var popped_variable = null


@onready var agent_running = false

@onready var controlled_by_player = false

@onready var inventory: Array[GLOBAL_DEFINITIONS.InventoryItem] = []
@onready var equipped_item_idx = -1

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
	
	close_interaction_area.body_entered.connect(_on_body_collision)
	if controlled_by_player:
		far_interaction_area.monitorable = false
		far_interaction_area.monitoring = false
		close_interaction_area.area_entered.connect(_on_interaction_entered)
		close_interaction_area.area_exited.connect(_on_interaction_exited)
	else:
		far_interaction_area.area_entered.connect(_on_interaction_entered)
		far_interaction_area.area_exited.connect(_on_interaction_exited)
	
	if not controlled_by_player:
		$ControllablePlayer/UI.hide()
		$AI.player = self
		agent_input.action_id = -1

	if controlled_by_player:
		$ControllablePlayer/UI.equip.connect(_on_inventory_item_changed)
	
	$AnimationManager/AnimationTree.animation_finished.connect(_animation_finished)

func _animation_finished(name):
	action_done = true

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	pass
	#velocity = safe_velocity
	#move_and_slide()

func execute_step(step: PlanStep):
	match step.step_type:
		PlanStep.STEP_TYPE.AIM_AT:
			var pos = variables_stack.pop_back()
			agent_input.aiming = true
			var current_trans = Transform3D(transform)
			agent_input.q_to = Quaternion(current_trans.looking_at(pos, Vector3.UP, true).basis)
			agent_input.shoot_target = pos
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
		
		PlanStep.STEP_TYPE.QUERY_PERSON:
			var ch = Characters.get_by_name(step.who)
			if ch == null:
				return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED
			var prop = ch.get(step.property_name)
			variables_stack.append(prop)
			if prop is bool and prop == false:
				return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE

		PlanStep.STEP_TYPE.QUERY_INVENTORY:
			for item in inventory:
				if item.type == step.obj_type:
					variables_stack.append(item)
					return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED

		PlanStep.STEP_TYPE.QUERY_CLOSE:
			for action in possible_actions:
				if action.object.get_type() == step.obj_type and action.object_action_id == step.object_action_type:
					variables_stack.append(action)
					variables_stack.append(action.object.global_position)
					return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED
		
		PlanStep.STEP_TYPE.QUERY_ACTION_UITILITY:
			var chosen = $AI.pick_obj_action(possible_actions)
			if chosen == null:
				return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED
			variables_stack.append(chosen)
			variables_stack.append(chosen.object.global_position)
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
		
		PlanStep.STEP_TYPE.QUERY_NAVIGATION:
			var location_name = step.location.place_name
			if location_name == "home":
				location_name = ai.agent_kb.house_name
			var pl_loc_name = Locations.get_node_from_position(global_position).name
			var nav_steps = Locations.plan_navigation_from_names(pl_loc_name, location_name)
			$AI.nav_steps = nav_steps
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
		
		PlanStep.STEP_TYPE.EQUIP:
			for idx in inventory.size():
				var item = inventory[idx]
				popped_variable = variables_stack.pop_back()
				if popped_variable == item:
					equipped_item_idx = idx
					$ControllablePlayer/UI.update_inventory(inventory, equipped_item_idx)
					item.object.equip()
					return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED

		PlanStep.STEP_TYPE.UNEQUIP:
			if equipped_item_idx != -1:
				inventory[equipped_item_idx].object.unequip()
				equipped_item_idx = -1
				$ControllablePlayer/UI.update_inventory(inventory, equipped_item_idx)
			agent_input.aiming = false
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE

		PlanStep.STEP_TYPE.GOTO_POSITION:
			if animation_tree["parameters/StateMachine/playback"].get_current_node() == "execute_action"\
			 and animation_tree["parameters/StateMachine/execute_action/Transition/current_state"] == "sit":
				for idx in possible_actions.size():
					var x = possible_actions[idx]
					if x.object_action_id == Chair.ACTION.STAND:
						agent_input.action_id = idx 

			if step.should_run:
				agent_running = true
			if step.use_stored_pos:
				popped_variable = variables_stack.pop_back()
				set_movement_target(popped_variable)
				return GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING
			set_movement_target(step.position)
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING

		PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION:
			action_done = false
			for idx in possible_actions.size():

				var x = possible_actions[idx]
				if x.get_instance_id() == step.object_action_id:
					agent_input.action_id = idx 
					return GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING
					
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED
		
		PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_STORED:
			action_done = false
			popped_variable = variables_stack.pop_back()
			for idx in possible_actions.size():

				var x = possible_actions[idx]
				
				if x == popped_variable:
					agent_input.action_id = idx 
					return GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING
					
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED
		
		PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_BY_ACTION_TYPE:
			action_done = false
			for idx in possible_actions.size():

				var x = possible_actions[idx]
				if global_position.distance_to(x.object.global_position) < GLOBAL_DEFINITIONS.MIN_DISTANCE_TO_EXECUTE_ACTION and x.action_id == step.object_action_type:
					agent_input.action_id = idx 
					return GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING
					
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED

		PlanStep.STEP_TYPE.EXECUTE_NPC_ACTION:
			match step.player_action_id:
				GLOBAL_DEFINITIONS.CHARACTER_ACTION.PUNCH:
					agent_input.punching = true
				GLOBAL_DEFINITIONS.CHARACTER_ACTION.KICK:
					agent_input.kicking = true
				GLOBAL_DEFINITIONS.CHARACTER_ACTION.SHOOT:
					agent_input.shooting = true
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
		PlanStep.STEP_TYPE.BROADCAST:
			$InteractionAreas.broadcast(step.who, step.params)
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
		_:
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE

func check_completion(step: PlanStep, navigation_completed: bool):
	match step.step_type:
		PlanStep.STEP_TYPE.GOTO_POSITION:
			if not navigation_completed:
				return GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING
			var pos = step.position
			if step.use_stored_pos:
				pos = popped_variable
			if navigation_completed and global_position.distance_to(pos) < 1.0:
				agent_running = false
				return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
			agent_running = false
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED

	if step.step_type == PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_BY_ACTION_TYPE or step.step_type == PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION or step.step_type == PlanStep.STEP_TYPE.EXECUTE_OBJ_ACTION_STORED:
		if action_done:
			if action_successful:
				return GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE
			return GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED
		return GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING


func abort(step: PlanStep):
	match step.step_type:
		PlanStep.STEP_TYPE.GOTO_POSITION:
			set_movement_target(global_position)
		_:
			pass

func update_ai(player_position: Vector3, possible_obj_actions: Array[ActionInfo]):
	DebugView.clear_debug_info(self)
	var should_abort = $AI.update(player_position, possible_obj_actions, perceptions, step_execution_state, CurrentTimeManager.get_current_time_in_minutes())
	perceptions.clear()
	var current_step: PlanStep = $AI.current_step_task
	if current_step:
		match step_execution_state:
			GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE:
				step_execution_state = execute_step(current_step)
			GLOBAL_DEFINITIONS.AI_FEEDBACK.FAILED:
				step_execution_state = execute_step(current_step)
			GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING:
				step_execution_state = check_completion(current_step, navigation_agent.is_navigation_finished())
		var step_type_str = PlanStep.STEP_TYPE.keys()[current_step.step_type]
		var exec_state_str = GLOBAL_DEFINITIONS.AI_FEEDBACK.keys()[step_execution_state]
		DebugView.append_debug_info("STEP: %s\n 	TYPE: %s\n	STATE: %s" % [current_step.name, step_type_str, exec_state_str], self)
	else:
		DebugView.append_debug_info("STEP: \n 	TYPE: " , self)
		
	if should_abort:
		abort(current_step)
		step_execution_state = GLOBAL_DEFINITIONS.AI_FEEDBACK.DONE

func set_movement_target(movement_target: Vector3):
	navigation_agent.set_target_position(movement_target)
	#reached = false
	
func _physics_process(delta: float):
	pass


func apply_input(delta: float):
	if ragdoll:
		global_position = $GeneralSkeleton/Hips.global_position
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
	
	#car control
	if current_car:
		var target = camera_x * motion.x + camera_z * motion.y if controlled_by_player else Vector3(motion.x, 0, motion.y)
		current_car.set_motion(motion)
		global_position = current_car.global_position
		return

	# Jump/in-air logic.
	airborne_time += delta
	if is_on_floor():
		if airborne_time > 0.5:
			# Change state to walk.
			animation_tree["parameters/StateMachine/playback"].travel("walk")
			
		airborne_time = 0

	var on_air = airborne_time > MIN_AIRBORNE_TIME


	var current_node = animation_tree["parameters/StateMachine/playback"].get_current_node()
	if current_node == "walk" or current_node == "strafe":
		if agent_input.aiming and equipped_item_idx != -1 and inventory[equipped_item_idx].object.get_type() == GLOBAL_DEFINITIONS.OBJECTS.PISTOL != null:
			# Convert orientation to quaternions for interpolating rotation.
			var q_from = orientation.basis.get_rotation_quaternion()
			var q_to = agent_input.get_camera_base_quaternion() if controlled_by_player else agent_input.q_to
			# Interpolate current rotation with desired one.
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

			# Change state to strafe.
			animation_tree["parameters/StateMachine/playback"].travel("strafe")
			animation_tree["parameters/StateMachine/strafe/blend_position"] = Vector2(motion.x, -motion.y)
			
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
		else: # Not in air or aiming, idle.
			# Convert orientation to quaternions for interpolating rotation.
			var target = camera_x * motion.x + camera_z * motion.y if controlled_by_player else Vector3(motion.x, 0, motion.y)
			if target.length() > 0.001:
				var q_from = orientation.basis.get_rotation_quaternion()
				var use_nod_front = false if controlled_by_player else true
				var q_to = Transform3D().looking_at(target, Vector3.UP, use_nod_front).basis.get_rotation_quaternion()
				# Interpolate current rotation with desired one.
				orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))
			
			# Change state to walk.
			#animation_tree["parameters/StateMachine/conditions/stop_fall"] = true
			animation_tree["parameters/StateMachine/playback"].travel("walk")
			animation_tree["parameters/StateMachine/walk/BlendSpace1D/blend_position"] = motion.length()
			
			
			var should_run = agent_input.running
			if not controlled_by_player:
				should_run = agent_running
			if should_run:
				animation_tree["parameters/StateMachine/walk/Transition/transition_request"] = "run"
			else:
				animation_tree["parameters/StateMachine/walk/Transition/transition_request"] = "walk"

			if agent_input.jumping and not animation_tree["parameters/StateMachine/walk/OneShot/active"]:
				animation_tree["parameters/StateMachine/walk/OneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
				agent_input.jumping = false
			if agent_input.punching:
				animation_tree["parameters/StateMachine/playback"].travel("execute_action")
				animation_tree["parameters/StateMachine/execute_action/Transition/transition_request"] = "combat"
				animation_tree["parameters/StateMachine/execute_action/StateMachine 2/BlendSpace1D/blend_position"] = 1
			if agent_input.kicking:
				animation_tree["parameters/StateMachine/playback"].travel("execute_action")
				animation_tree["parameters/StateMachine/execute_action/Transition/transition_request"] = "combat"
				animation_tree["parameters/StateMachine/execute_action/StateMachine 2/BlendSpace1D/blend_position"] = -1
			# if agent_input.talking:
			# 	animation_tree["parameters/state/transition_request"] = "talk"

	if on_air:
		if (velocity.y <0): 
			animation_tree["parameters/StateMachine/playback"].travel("fall")
	


	root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())
	
	#fix sliding when idle
	if not (motion.length() < 0.001 and animation_tree["parameters/StateMachine/playback"].get_current_node() == "walk"):# or seated:#to fix
		orientation *= root_motion
	
	var h_velocity = orientation.origin / delta

	velocity.x = h_velocity.x
	velocity.z = h_velocity.z
	#if not seated:
	if animation_tree["parameters/StateMachine/walk/OneShot/active"] and not on_air:
		velocity.y = h_velocity.y
	else:
		velocity += gravity * delta
	if on_air:
		velocity += gravity * delta
		
	#DebugView.print_debug_info("velocity: %s" % DebugView.format_vector3(velocity), self)
	#DebugView.append_debug_info("\nrootpos: %s" % DebugView.format_vector3(animation_tree.get_root_motion_position()), self)
	#DebugView.append_debug_info("\n delta: %f" % delta, self)
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
	if controlled_by_player:
		apply_input(delta)
	else:
		if should_update_ai():
			update_ai(global_position, possible_actions)
			if step_execution_state != GLOBAL_DEFINITIONS.AI_FEEDBACK.RUNNING:
				update_ai(global_position, possible_actions)
			#agent_input = $AI.get_next_actions(position, possible_actions, reached, agent_input.motion, current_car)
		if navigation_agent.is_navigation_finished():
			agent_input.motion = Vector2()
			#reached = true
		else:
			var next_path_position: Vector3 = navigation_agent.get_next_path_position()
			var vector_to: Vector3 = global_position.direction_to(next_path_position).normalized()
			agent_input.motion = Vector2(vector_to.x, vector_to.z)
		apply_input(delta)
	if controlled_by_player:
		agent_input.action_id -= 1
	if agent_input.action_id >= 0:
		#do_action_by_number(agent_input.action_id)
		action_successful = do_action_by_number_list(agent_input.action_id)
		agent_input.action_id = -1
		#action_done = true
			
func execute_action(action_info: ActionInfo):
	var object = action_info.object
	var is_successful = object.act(action_info.object_action_id, self)
	if  not is_successful:
		action_done = true
		return false
	if not controlled_by_player and object.include_in_utility_search():
		$AI.fulfill_object_adv(object.get_action_adv(action_info.object_action_id))
	match action_info.player_action_id:
		GLOBAL_DEFINITIONS.CHARACTER_ACTION.PICK: 
			animation_tree["parameters/StateMachine/playback"].travel("execute_action")
			animation_tree["parameters/StateMachine/execute_action/Transition/transition_request"] = "pick"
			var item = GLOBAL_DEFINITIONS.InventoryItem.new()
			item.object = action_info.object
			item.type = action_info.object.get_type()
			item.object.reparent(shoot_from)
			item.object.transform = Transform3D()
			
			inventory.append(item)
			equipped_item_idx = inventory.size()-1
			$ControllablePlayer/UI.update_inventory(inventory, equipped_item_idx)
			object.equip()
			variables_stack.append(item)
			
		GLOBAL_DEFINITIONS.CHARACTER_ACTION.THROW: 
			animation_tree["parameters/state/transition_request"] = "throw"
		GLOBAL_DEFINITIONS.CHARACTER_ACTION.SIT: 
			#TODO: when runnning start pos different
			animation_tree["parameters/StateMachine/playback"].travel("execute_action")
			animation_tree["parameters/StateMachine/execute_action/Transition/transition_request"] = "sit"
			animation_tree["parameters/StateMachine/execute_action/StateMachine/playback"].travel("items_stand_to_sit")
			#animation_tree["parameters/sit/conditions/stand"] =  false
			var sit_position: Transform3D = object.get_node("SitPosition").global_transform
			global_position.x = sit_position.origin.x
			global_position.z = sit_position.origin.z
			orientation.basis = sit_position.basis
			#$CollisionShape3D.disabled = true
			#seated = true
		GLOBAL_DEFINITIONS.CHARACTER_ACTION.STAND: 
			animation_tree["parameters/StateMachine/execute_action/StateMachine/playback"].travel("items_sit_to_stand")
			#$CollisionShape3D.disabled = false
			#seated = false
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
		_: 
			action_done = true
	return true
	
func do_action_by_number_list(num):
	if num < possible_actions.size() and num >= 0:
		return execute_action(possible_actions[num])
	return false

			
func update_action_labels_list():
	action_label.clear()
	for action_info_idx in possible_actions.size():
		var action_info = possible_actions[action_info_idx]
		action_label.append_text("%d : %s \n" % [action_info_idx+1, action_info.desc])
		
		
	
func _on_actions_update(object):
	remove_object_from_action_list(object)
	
	for action in object.get_possible_actions(self):
		
		var action_info_list = ActionInfo.new()
		action_info_list.object = object
		action_info_list.desc = object.get_action_description(action)
		action_info_list.player_action_id = object.get_player_action(action)
		action_info_list.object_action_id = action
		
		possible_actions.push_back(action_info_list)
		
	update_action_labels_list()
	

func _on_interaction_entered(area):
	var object = area.get_parent()
	if not object.has_method("get_possible_actions"):
		return
	_on_actions_update(object)
	object.state_changed.connect(_on_actions_update)
	if object.has_signal("character_event_broadcast"):
		object.character_event_broadcast.connect(_on_character_event)
	
func _on_interaction_exited(area):
	var object = area.get_parent()
	if not object.has_method("get_possible_actions"):
		return
	
	remove_object_from_action_list(object)
	
	object.state_changed.disconnect(_on_actions_update)
	update_action_labels_list()

func _on_inventory_item_changed(selected_idx):
	if selected_idx == equipped_item_idx:
		inventory[equipped_item_idx].object.unequip()
		equipped_item_idx = -1
		return
	inventory[equipped_item_idx].object.unequip()
	inventory[selected_idx].object.equip()
	equipped_item_idx = selected_idx

func _on_character_event(ch, event, params):
	var perception = Perception.new()
	perception.event = event
	perception.character = ch
	perception.params = params
	perceptions.append(perception)

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
	$GeneralSkeleton.physical_bones_start_simulation()
	$MainCollider.disabled = true
	ragdoll = true
	schedule_ragdoll_end()
	#animation_tree["parameters/state/transition_request"] = "hit"
	
	
func schedule_ragdoll_end():
	await get_tree().create_timer(10.0).timeout
	$GeneralSkeleton.physical_bones_stop_simulation()
	$MainCollider.disabled = false
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
