extends CharacterBody3D
class_name Rabbit

# TODO: Better vision cone (multiple area 3Ds).
# Rabbits only run away when player looks at them? Otherwise, they stop and
# stare?
# Game is about chasing rabbits, not stealth. So, make a good
# initial impression/spectable by watching rabbits bounce around?

@export_group("Wander")
@export_range(0.1, 10) var _walk_speed : float
@export_range(1, 20) var _wander_dist_min : float
@export_range(1, 20) var _wander_dist_max : float
@export_range(0, 20) var _idle_time_min : float
@export_range(0, 20) var _idle_time_max : float
@export_group("Flee")

@export_group("References")
@export var _rabbit_body : MeshInstance3D
@export var _rabbit_tail : MeshInstance3D

@onready var _nav_agent : NavigationAgent3D = %NavigationAgent3D
enum AiState { WANDER, FLEE }
var _ai_state := AiState.WANDER
var _last_nav_finish_time : float
var _idle_time : float
var _flee_target : Node3D

@onready var _vision_cone : Area3D = %VisionCone

@onready var _ai_state_label : Label3D = %AiStateLabel
@onready var _horz_speed_label : Label3D = %HorzSpeedLabel
@onready var _target_pos_label : Label3D = %TargetPosLabel
@onready var _current_pos_label : Label3D = %CurrentPosLabel
@onready var _dist_to_targ_label : Label3D = %DistToTargLabel
@onready var _nav_fin_label : Label3D = %NavFinLabel
@onready var _targ_reached_label : Label3D = %TargReachedLabel
@onready var _reachable_label : Label3D = %ReachableLabel
@onready var _idling_label : Label3D = %IdlingLabel
@onready var _flee_targ_label : Label3D = %FleeTargLabel

func _acquire_random_wander_target() -> void:
	var rand_angle := randf() * 2 * PI
	var rand_dir := Vector3(cos(rand_angle), 0,  sin(rand_angle))
	var rand_dist := randf_range(_wander_dist_min,
		 _wander_dist_max)
	_nav_agent.target_position = global_position + rand_dir * rand_dist

func _ready() -> void:
	seed(12345) # Fix seed for testing.
	# TODO: REMOVE FIXED SEED
	assert(process_mode == PROCESS_MODE_PAUSABLE)
	assert(_wander_dist_max > _wander_dist_min)
	assert(_idle_time_max > _idle_time_min)
	
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
	mat_body.emission = rand_color
	mat_tail.emission = rand_color
	# Don't share materials. Each rabbit get's it's own color.
	assert(mat_body.is_local_to_scene())
	assert(mat_tail.is_local_to_scene())
	
	# Ai detection.
	assert(_vision_cone.collision_mask == 8)
	assert(!_vision_cone.monitorable)
	# TODO: `for` loop over vision cones array.
	_vision_cone.body_entered.connect(
		func(body: Node3D):
			var other_rabbit := body as Rabbit
			var saw_fleeing_rabbit := (other_rabbit != null 
				and other_rabbit != self)
			
			if saw_fleeing_rabbit:
				print("%s: saw fleeing rabbit!" % name)
				if _ai_state != AiState.FLEE:
					_ai_state = AiState.FLEE
					var spook_breadcrumb := Node3D.new()
					# When return to Wander, delete spook breadcrumb.
					get_tree().current_scene.add_child(spook_breadcrumb)
					spook_breadcrumb.global_position = other_rabbit.global_position
					_flee_target = spook_breadcrumb
			elif other_rabbit == self:
				pass
			else:
				var player := body as Player
				assert(player != null)
				print("%s: saw player!" % name)
				_flee_target = player # TODO: Forget the reference eventually.
				if _ai_state != AiState.FLEE:
					_ai_state = AiState.FLEE
	)
	
	# Rest of `_ready` is dedicated to setting up ai navigation.
	_ai_state = AiState.WANDER
	_acquire_random_wander_target()
	_idling_label.text = "Idling?: false"
	_idling_label.modulate = Color.RED
	
	# When navigation finishes, decide for how long to idle.
	_nav_agent.navigation_finished.connect(
		func() -> void:
			# TODO: Bias THE `_idle_time` to be above a min threshold.
			# Beyond the min threshold, the rabbit can look around.
			_last_nav_finish_time = Time.get_ticks_msec() / 1000.0
			_idle_time = randf_range(_idle_time_min, _idle_time_max)
			_idling_label.text = "Idling?: True (%.2f s)" % _idle_time
			_idling_label.modulate = Color.GREEN
	)
	
	# Avoid other agents.
	_nav_agent.velocity_computed.connect(
		func(safe_velocity : Vector3) -> void:
			velocity = safe_velocity
			move_and_slide()
	)

# Labels.
func _process(_delta : float) -> void:
	_ai_state_label.text = (
		"WANDER" if _ai_state == AiState.WANDER else
		"FLEE" if _ai_state == AiState.FLEE else 
		"INVALID"
	)
	_horz_speed_label.text = "%.2f m/s" % sqrt(velocity.x ** 2 
		+ velocity.z ** 2)
	_target_pos_label.text = "TargetPos: %.2v" % _nav_agent.target_position
	_current_pos_label.text = "CurrentPos: %.2v" % global_position
	_dist_to_targ_label.text = ("DistToTarg: %.2f" 
		% _nav_agent.distance_to_target())
	
	_nav_fin_label.text = ("NavFin?: %s" 
		% _nav_agent.is_navigation_finished())
	_nav_fin_label.modulate = (
		Color.GREEN if _nav_agent.is_navigation_finished() else
		Color.RED
	)
	
	_targ_reached_label.text = ("TargReached?: %s" 
		% _nav_agent.is_target_reached())
	_targ_reached_label.modulate = (
		Color.GREEN if _nav_agent.is_target_reached() else
		Color.RED
	)
	
	_reachable_label.text = ("Reachable?: %s" 
		% _nav_agent.is_target_reachable())
	_reachable_label.modulate = (
		Color.GREEN if _nav_agent.is_target_reachable() else
		Color.RED
	)
	
	var is_idling := _idling_label.modulate == Color.GREEN
	if is_idling:
		var remaining_idle_time = maxf(_last_nav_finish_time 
			+ _idle_time - Time.get_ticks_msec() / 1000.0, 0)
		_idling_label.text = "Idling?: True (%.2f s)" % remaining_idle_time
	
	if _flee_target != null:
		_flee_targ_label.text = "FleeTarg: %s" % _flee_target.name
		_flee_targ_label.modulate = Color.GREEN
	else:
		_flee_targ_label.text = "FleeTarg: NONE"
		_flee_targ_label.modulate = Color.RED

func _physics_process(_delta : float) -> void:
	# Anims can be driven by AiState + velocity.
	match _ai_state:
		AiState.WANDER:
			if !_nav_agent.is_navigation_finished():
				var next_path_position := _nav_agent.get_next_path_position()
				velocity = (global_position.direction_to(next_path_position) 
					* _walk_speed)
				if global_position.distance_to(next_path_position) > Main.ERR_TOL:
					look_at(next_path_position)
			else:
				velocity = Vector3.ZERO
				var is_done_idling := (Time.get_ticks_msec() / 1000.0 
					>= _last_nav_finish_time + _idle_time)
				if is_done_idling:
					_idling_label.text = "Idling?: False"
					_idling_label.modulate = Color.RED
					_acquire_random_wander_target()

		AiState.FLEE:
			# - If has target, jump towards it.
			# - Jumps should be fixed height (or within narrow range).
			# - Jumps should be fixed distance or takeoff horz_vel
			#    (or within a narrow-ish range).
			# - Precompute jump landing position, and see if it's on the NavMesh.
			#   If it isn't, then check earlier / less distant landing points in
			#   same dir until one within the fixed distance range is found.
			#   If no valid points on NavMesh in that direction, then pick 
			#   another random direction and repeat. Once one is finally found, 
			#   that is going to be the landing position (jump height may
			#   need to be adjusted to fit, perhaps ignore fixed height?).
			# - When landing, immediately set a new target, then jump again.
			# - Sometimes sample very nearby "islands" (high or lower segments of 
			#   terrain). If one is found, can do "superjump" or "drop"
			#   to try to dodge player.
			# - If _flee_from is far from rabbit and behind, rabbit can "forget" 
			#   about _flee_from and return to wander state.
			# If _flee_from != player, and rabbit detects / sees player, 
			#   immediately set _flee_from = player.
			pass
	move_and_slide()
