extends CharacterBody3D
class_name Player

# Globally accessible instance; there is only one player.
static var instance : Player

# Sync gravity with value used by RigidBodies.
var _grav : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _mouse_relative : Vector2
var _dive_queued : bool
var _is_diving : bool
var _dive_land_time : float

@onready var cam : Camera3D = %Camera

func _ready() -> void:
	instance = self

func _input(event : InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	
	# If mouse position changed between polling, cache it's relative motion to
	# rotate the camera pivot and player body (for FPS camera controls).
	if event is InputEventMouseMotion:
		_mouse_relative = -event.relative
	
	if event.is_action_released("dive") and is_on_floor():
		_dive_queued = true

func _process(delta : float) -> void:
	# FPS camera controls.
	const cam_rot_scale = 0.2 # TODO: Change this in settings menu.
	const pitch_max = 75.0
	cam.rotate_x(cam_rot_scale * _mouse_relative.y * delta)
	cam.rotation_degrees.x = clampf(cam.rotation_degrees.x, -pitch_max, pitch_max)
	rotate_y(cam_rot_scale * _mouse_relative.x * delta)
	
	# Right before the next frame begins, reset mouse relative. So that camera
	# doesn't keep moving.
	var reset_mouse_relative = func() -> void: _mouse_relative = Vector2.ZERO
	reset_mouse_relative.call_deferred()

func _physics_process(delta : float) -> void:
	# Set vertical velocity.	
	if not is_on_floor():
		velocity.y -= _grav * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		const jump_height = 2.0
		var jump_vel := sqrt(2 * _grav * jump_height)
		velocity.y = jump_vel

	# If the player is airborne, have them maintain their momentum. Otherwise,
	# move them in accordance to user inputs.
	if is_on_floor():
		if _is_diving:
			_dive_land_time = Time.get_ticks_msec() / 1000.0
			_is_diving = false
			
		const dive_hitstun = 1.0
		
		if (Time.get_ticks_msec() / 1000.0) < _dive_land_time + dive_hitstun: return
		
		# Set horizontal velocity.
		const time_to_max_speed = 0.05
		const max_speed = 5.0
		const accel = max_speed / time_to_max_speed
		
		var input_dir := Input.get_vector("move_leftwards", "move_rightwards", "move_forwards", "move_backwards")
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if move_dir: # nonzero
			velocity.x = move_toward(velocity.x, move_dir.x * max_speed, accel * delta)
			velocity.z = move_toward(velocity.z, move_dir.z * max_speed, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, accel * delta)
			velocity.z = move_toward(velocity.z, 0, accel * delta)
		
		if _dive_queued:
			const dive_height = 1.0
			var dive_y_vel := sqrt(2 * _grav * dive_height)
			
			const dive_dist = 10.0
			var t_up := dive_y_vel / _grav
			var t_total := 2.0 * (t_up)
			var dive_forward_vel := dive_dist / t_total
			velocity.y = dive_y_vel
			velocity -= dive_forward_vel * transform.basis.z
			_is_diving = true
			
		_dive_queued = false
	
	move_and_slide()
