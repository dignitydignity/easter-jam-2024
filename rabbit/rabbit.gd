extends CharacterBody3D
class_name Rabbit

# TODO: Color patterns / "rabbit types"?
# TODO: Player detection.

@export_group("References")
@export var _rabbit_body : MeshInstance3D
@export var _rabbit_tail : MeshInstance3D

@onready var _nav_agent : NavigationAgent3D = %NavigationAgent3D

enum AiState { WANDER, FLEE }
var _ai_state := AiState.WANDER

func _ready() -> void:
	assert(process_mode == PROCESS_MODE_PAUSABLE)
	
	# Randomize the rabbit's color.
	var mat_body := _rabbit_body.get_surface_override_material(0) as ORMMaterial3D
	var mat_tail := _rabbit_tail.get_surface_override_material(0) as ORMMaterial3D
	var rand_f := Main.rng.randf()
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
	
	_ai_state = AiState.WANDER
	
	# Avoid other agents.
	_nav_agent.velocity_computed.connect(
		func(safe_velocity : Vector3):
			velocity = safe_velocity
			move_and_slide()
	)

func physics_process(_delta : float) -> void:
	# Anims can be driven by AiState + velocity.
	match _ai_state:
		AiState.WANDER:
			# - If has target, and isn't at target, walk towards it.
			# - If has target, and is at/near target, stand still (cache time).
			#    This means rabbit will always have a "target".
			# - Make the "stand still time" random from 0 to X secs.
			# - Bias "stand still time" to be above a min threshold. Beyond the
			#    min threshold, the rabbit can look around.
			# - After "stand still time" is reached, acquire new target.
			# - Make sure that the target is from X to Y dist away and is 
			#    walkable.
			# - If rabbit detects player, grab hold of reference and enter 
			#    flee state.
			pass
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
			#    terrain). If one is found, can do "superjump" or "drop"
			#    to try to dodge player.
			# - If player is far from rabbit and behind, rabbit can "forget" 
			#    about player and return to wander state. But a flag should be
			#    set to make the rabbit more "wary" of player in future, until
			#    enough time has passed ("wary" = increased sensor size).
			pass
