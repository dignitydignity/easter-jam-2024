extends CharacterBody3D
class_name Rabbit

@export_group("Wander")
@export_range(0.1, 10) var _walk_speed : float
@export_range(1, 20) var _wander_dist_min : float
@export_range(1, 20) var _wander_dist_max : float
@export_range(0, 20) var _idle_time_min : float
@export_range(0, 20) var _idle_time_max : float
@export_group("Flee")
@export_range(0, 10) var _jump_height : float
@export_range(0, 100) var _grav : float
@export_range(0, 30) var _flee_dist : float
@export_range(0, 90) var _flee_angle_deg : float
@export_range(0, 100) var _jump_dist_grav_scale_factor : float
@export_range(0.1, 100) var _forget_dist : float
@export_range(0.1, 100) var _forget_time : float

@export_group("References")
@export var _rabbit_body : MeshInstance3D
@export var _rabbit_tail : MeshInstance3D

@onready var _nav_agent : NavigationAgent3D = %NavigationAgent3D
enum AiState { WANDER, FLEE }
var _ai_state := AiState.WANDER
var _last_nav_finish_time : float
var _idle_time : float
var _last_scaled_grav : float

# ANIMATIONS
@onready var _animtree : AnimationTree = %AnimationTree

# AUDIO
@onready var _sfx : AudioStreamPlayer3D = %Sfx
@onready var _sfx_giggle : AudioStreamPlayer3D = %Sfx
const SFX_GIGGLE = preload("res://audio/sfx/rabbit_giggle.wav")
const SFX_JUMP1 = preload("res://audio/sfx/rabbit_jump.wav")
const SFX_JUMP2	 = preload("res://audio/sfx/rabbit_jump2.wav")
const SFX_VOL = -40.0 # Default val, but not for giggle (0)

var _jump_count : int = 0
var _catch_time : float
static var _respawn_cooldown := 30

@onready var _collider : CollisionShape3D = %CollisionShape3D

var _is_caught := false
func catch() -> void:
	#print("catch called")
	if _is_caught: return
	#print("_is_caught is false")
	assert(!_is_caught)
	_is_caught = true
	_catch_time = Time.get_ticks_msec() / 1000.0
	visible = false
	_collider.set_deferred("disabled", true)
	_flee_target = null

var start_pos : Vector3
func respawn() -> void:
	_is_caught = false
	visible = true
	_collider.set_deferred("disabled", false)
	global_position = start_pos
	_respawn_cooldown -= 0.1
	_respawn_cooldown = max(_respawn_cooldown, 10.0)
	_flee_target = null
	
# Flee target is the object to flee from. Not the target to flee towards.
var _player_in_cone : Player # When walks into vision cone.
var _flee_target : Node3D:
	get: return _flee_target
	set(value):
		if value != null:
			if _flee_target != null and !(_flee_target is Player): # is breadcrumb
				_flee_target.queue_free()
			_last_flee_start_time = Time.get_ticks_msec() / 1000.0
			_ai_state = AiState.FLEE
		else:
			if _flee_target != null and !(_flee_target is Player): # is breadcrumb
				_flee_target.queue_free()
			_ai_state = AiState.WANDER
		_flee_target = value
var _last_flee_start_time : float

@onready var _vision_cone : Area3D = %VisionCone
@onready var _line_of_sight_raycaster : RayCast3D = %LineOfSightRaycaster

const _pfx_factory : PackedScene = preload("res://pfx/pfx_2.tscn")

func _set_random_nav_agent_target_pos(dist : float) -> void:
	if _is_caught: return
	var rand_angle := randf() * 2 * PI
	var rand_dir := Vector3(cos(rand_angle), 0,  sin(rand_angle))
	_nav_agent.target_position = global_position + rand_dir * dist

func _set_random_nav_agent_target_pos_away_fom_flee_target(dist : float) -> void:
	if _is_caught: return
	var dir_to_flee_targ := global_position.direction_to(_flee_target.global_position)
	var angle_to_flee_targ := atan2(dir_to_flee_targ.z, dir_to_flee_targ.x)
	var opp_angle := angle_to_flee_targ + PI
	var arc_width := deg_to_rad(_flee_angle_deg)
	var rand_angle := opp_angle + randf() * arc_width - arc_width / 2
	var rand_dir_away_from_flee_targ := Vector3(cos(rand_angle), 0, sin(rand_angle))
	_nav_agent.target_position = global_position + rand_dir_away_from_flee_targ * dist

func _ready() -> void:
	_is_caught = false
	
	start_pos = global_position

	assert(process_mode == PROCESS_MODE_PAUSABLE)
	assert(_wander_dist_max > _wander_dist_min)
	assert(_idle_time_max > _idle_time_min)
	
	# Giggle if player dives and misses.
	Player.instance.dive_land_missed.connect(
		func(): 
			if _is_caught: return
			if _ai_state == AiState.FLEE:
				_sfx_giggle.stream = SFX_GIGGLE
				_sfx_giggle.play()
	)
	
	# Randomize the rabbit's color.
	var mat_body := _rabbit_body.get_surface_override_material(0) as ORMMaterial3D
	var mat_tail := _rabbit_tail.get_surface_override_material(0) as ORMMaterial3D
	var rand_f := randf()
	const n_rand_colors = 6.0
	const rand_percent_change = 1.0/n_rand_colors
	var rand_color := (
		Color.RED if rand_f < rand_percent_change else
		Color.SKY_BLUE if rand_f < 2 * rand_percent_change else
		Color.LIGHT_GREEN if rand_f < 3 * rand_percent_change else 
		Color.YELLOW if rand_f < 4 * rand_percent_change else 
		Color.HOT_PINK if rand_f < 5 * rand_percent_change else
		Color.PURPLE 
	)
	mat_body.albedo_color = rand_color
	mat_tail.albedo_color = rand_color
	assert(mat_body.emission_enabled)
	assert(mat_tail.emission_enabled)
	mat_body.emission = rand_color
	mat_tail.emission = rand_color
	# Don't share materials. Each rabbit get's it's own color.
	assert(mat_body.is_local_to_scene())
	assert(mat_tail.is_local_to_scene())
	
	# Ai detection.
	assert(_vision_cone.collision_mask == 8)
	assert(!_vision_cone.monitorable)
	#assert(!_line_of_sight_raycaster.enabled)
	# TODO: `for` loop over vision cones array.
	_vision_cone.body_entered.connect(
		func(body: Node3D):
			if _is_caught: return
			var other_rabbit := body as Rabbit
			var saw_fleeing_rabbit := (other_rabbit != null 
				and other_rabbit != self)
			
			if saw_fleeing_rabbit:
				if _ai_state != AiState.FLEE:
					_ai_state = AiState.FLEE
					var spook_breadcrumb := Node3D.new()
					get_tree().current_scene.add_child(spook_breadcrumb)
					spook_breadcrumb.global_position = other_rabbit.global_position
					_flee_target = spook_breadcrumb
			elif other_rabbit == self:
				pass
			else:
				var player := body as Player
				assert(player != null)
				_player_in_cone = player
				_check_player_in_los_and_begin_flee_if_so()
	)
	
	_vision_cone.body_exited.connect(
		func(body : Node3D) -> void:
			if _is_caught: return
			if body is Player:
				_player_in_cone = null
	)
	
	# Rest of `_ready` is dedicated to setting up ai navigation.
	_ai_state = AiState.WANDER
	#_last_nav_finish_time = 0.0
	_set_random_nav_agent_target_pos(
		randf_range(_wander_dist_min, _wander_dist_max)
	)
	
	# When navigation finishes, decide for how long to idle.
	_nav_agent.navigation_finished.connect(
		func() -> void:
			if _is_caught: return
			# TODO: Bias THE `_idle_time` to be above a min threshold.
			# Beyond the min threshold, the rabbit can look around.
			_last_nav_finish_time = Time.get_ticks_msec() / 1000.0
			_idle_time = randf_range(_idle_time_min, _idle_time_max)
			#_idling_label.text = "Idling?: True (%.2f s)" % _idle_time
			#_idling_label.modulate = Color.GREEN
	)

func _check_player_in_los_and_begin_flee_if_so():
	if _is_caught: return
	if _player_in_cone == null: return
	_line_of_sight_raycaster.target_position = _line_of_sight_raycaster.to_local(
		_player_in_cone.global_position + Vector3.UP)
	var is_col := _line_of_sight_raycaster.is_colliding()
	var is_player := _line_of_sight_raycaster.get_collider() is Player
	
	if is_col and is_player:
		_flee_target = _player_in_cone
		
var first_one := true # prevent annoying debug messages

var _time_since_idle_ended : float

func _physics_process(delta : float) -> void:
	if _is_caught:
		var is_respawn_off_cd := (Time.get_ticks_msec() / 1000.0 
			> _catch_time + _respawn_cooldown)
		if is_respawn_off_cd:
			respawn()
		return
	
	if first_one:
		first_one = false
		return
	
	var horz_vel := sqrt(velocity.x ** 2 + velocity.z ** 2)
	_animtree.set("parameters/idle_walk/blend_position", horz_vel/_walk_speed)
	_animtree.set("parameters/jump_blend/blend_amount", (
		0.0 if is_on_floor() else 
		1.0
	))
	
	#if _ai_state == AiState.WANDER and horz_vel < Main.ERR_TOL and randf() < .0001: # 1% chance of doing
		#_animtree.set("parameters/oneshot_look/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	_check_player_in_los_and_begin_flee_if_so()
	
	# End flee if _flee_target is far
	if _flee_target != null:
		var flee_target_is_far = global_position.distance_to(_flee_target.global_position) >= _forget_dist
		if flee_target_is_far:
			var enough_time_has_passed := Time.get_ticks_msec() / 1000.0 >= _last_flee_start_time + _forget_time
			if enough_time_has_passed:
				_flee_target = null
	
	match _ai_state:
		AiState.WANDER:
			
			#if !_nav_agent.is_target_reachable():
				#print("Unreachable Target on rabbit: ", name)
			
			if !_nav_agent.is_navigation_finished():
				var next_path_pos := _nav_agent.get_next_path_position()
				velocity = _walk_speed * Vector3(
					next_path_pos.x - global_position.x,
					0,
					next_path_pos.z - global_position.z
				).normalized()
				# TODO: lerp to target look_at.
				if global_position.distance_to(next_path_pos) > Main.ERR_TOL:
					look_at(next_path_pos)
					rotation.x = 0
					rotation.z = 0
				_time_since_idle_ended += delta
				const _rabbit_unstuck_time = 7.0
				if _time_since_idle_ended > _rabbit_unstuck_time:
					_set_random_nav_agent_target_pos(
						randf_range(_wander_dist_min, _wander_dist_max)
					)
					_time_since_idle_ended = 0.0
			else:
				velocity = Vector3.ZERO
				var is_done_idling := (Time.get_ticks_msec() / 1000.0 
					>= _last_nav_finish_time + _idle_time)
				if is_done_idling:
					#_idling_label.text = "Idling?: False"
					#_idling_label.modulate = Color.RED
					_time_since_idle_ended = 0.0
					_set_random_nav_agent_target_pos(
						randf_range(_wander_dist_min, _wander_dist_max)
					)
				
				
			if !is_on_floor():
				velocity.y -= 40 * _grav * delta
				
		AiState.FLEE:
					
				if is_on_floor():
					
					_set_random_nav_agent_target_pos_away_fom_flee_target(_flee_dist)
					
					var pos_to_jump_to := _nav_agent.get_next_path_position()
					look_at(_nav_agent.get_next_path_position())
					rotation.x = 0
					rotation.z = 0
					
					var jump_dir := Vector3(
						pos_to_jump_to.x - global_position.x,
						0,
						pos_to_jump_to.z - global_position.z
					).normalized()
					
					#var jump_dir_rel := -(transform.basis * jump_dir).normalized()
					var jump_dist_concrete := sqrt(
						(pos_to_jump_to.x - global_position.x) ** 2 
						+ (pos_to_jump_to.z - global_position.z) ** 2
					)
					# Used to increase rabbit speed
					#assert(jump_dist_concrete > Main.ERR_TOL) # THIS GETS HIT, LEADING TO INF VELOCITY!
					jump_dist_concrete = max(jump_dist_concrete, 10.0 * Main.ERR_TOL) # Prevent division by zero
					_last_scaled_grav = _grav * (1 + (_jump_dist_grav_scale_factor / jump_dist_concrete))
					var jump_y_vel := sqrt(2 * _last_scaled_grav * _jump_height)
					var t_up := jump_y_vel / _last_scaled_grav
					var t_total := 2.0 * (t_up)
					var jump_forwards_vel := jump_dist_concrete / t_total # _jump_dist
					
					#_wallchecker.target_position = jump_dist_concrete * jump_dir
					#print(_wallchecker.target_position)
					#_wallchecker.force_raycast_update()
					#if _wallchecker.is_colliding():
						#jump_dir = -jump_dir
					
					velocity = jump_forwards_vel * jump_dir
					velocity.y = jump_y_vel
					
					var pfx := _pfx_factory.instantiate() as GPUParticles3D
					assert(pfx != null)
					add_child(pfx)
					pfx.emitting = true
					pfx.finished.connect(func() -> void: pfx.queue_free())
					
					_jump_count += 1
					if _jump_count % 2 == 0:
						_sfx.stream = SFX_JUMP1
					else:
						_sfx.stream = SFX_JUMP2
					_sfx.play()
				else:
					
					velocity.y -= _last_scaled_grav * delta

	move_and_slide()
