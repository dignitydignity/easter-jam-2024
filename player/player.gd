extends CharacterBody3D
class_name Player

# TODO: Diving -> leftclick while sprinting.
# TODO: Make `func`s non-local for performance if needed.
# TODO: Compute initial `_movestate`, so that I can use `assert()` later.

# Globally accessible instance; there is only one player.
static var instance : Player

# Design params (constants).
@export_group("General")
@export_range(0.1, 3) var _grab_range : float
@export_range(0, 5) var _grab_cooldown : float
@export_range(0, 90) var _cam_pitch_max : float
@export_group("Jump")
@export_range(0, 50) var _grav : float
@export_range(0, 10) var _jump_height : float
@export_range(0, 1) var _midair_accel_multiplier : float
@export_group("Walk")
@export_range(0.1, 100) var _max_walk_speed : float
@export_range(0.02, 3) var _time_to_max_walk_speed : float
@export_group("Sprint")
@export_range(0.1, 100) var _sprint_speed : float
@export_range(0.02, 5) var _time_to_sprint: float
@export_range(75.1, 179.0) var _sprint_fov : float
@export_group("Dive")
@export_range(0.5, 10) var _dive_height : float
@export_range(0, 20) var _dive_dist : float
@export_range(0, 5) var _dive_cam_pitch_rot_delay : float
@export_range(-90, 0) var _dive_cam_pitch_min : float
@export_range(0, 5) var _dive_hitstun : float
@export_range(.02, 0.5) var _dive_body_yaw_rot_time_length : float
@export_range(0, 50) var _dive_grav : float

# Internal state.
@onready var cam : Camera3D = %Camera
var _mouse_relative : Vector2

@onready var _grab_raycaster : RayCast3D = %GrabRaycaster
@onready var _interact_raycaster : RayCast3D = %InteractRaycaster
var _last_grab_attempt_time : float

enum Movestate { WALK, SPRINT, JUMP_AIR, DIVE, DIVE_HITSTUN }
var _ground_takeoff_horz_velocity : Vector2
var _movestate : Movestate
var _last_dive_start_time : float # Time units = seconds.
var _last_dive_land_time : float
var _is_sprint_toggled : bool

func _ready() -> void:
	instance = self
	assert(_interact_raycaster.target_position == _grab_range * Vector3.FORWARD)

func _input(event : InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	
	# If mouse position changed between polling, cache it's relative motion to
	# rotate the camera and player body (for FPS camera controls in `_process`).
	if event is InputEventMouseMotion:
		_mouse_relative = -event.relative

# `_process` only contains camera related stuff.
func _process(delta : float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	
	match _movestate:
		Movestate.WALK, Movestate.JUMP_AIR, Movestate.SPRINT:
			# Standard FPS cam controller.
			const cam_sens = 0.2 # TODO: Make `cam_sens` changeable in settings menu.
			cam.rotate_x(cam_sens * _mouse_relative.y * delta)
			cam.rotation_degrees.x = clampf(cam.rotation_degrees.x, -_cam_pitch_max, _cam_pitch_max)
			rotate_y(cam_sens * _mouse_relative.x * delta)
		Movestate.DIVE:
			# Cam pitch begins downwards rotation after brief time period.
			var is_cam_rot_start_time_passed := ((Time.get_ticks_msec() / 1000.0) 
				> _last_dive_start_time + _dive_cam_pitch_rot_delay)
			if is_cam_rot_start_time_passed:
				const rot_speed = PI/2 # radians/second
				cam.rotate_x(-rot_speed * delta)
			cam.rotation_degrees.x = clampf(cam.rotation_degrees.x, 
				_dive_cam_pitch_min, _cam_pitch_max)
		Movestate.DIVE_HITSTUN:
			# Camera doesn't move while in hitstun.
			pass
	
	# Cam FoV scales with with speed slightly.
	var horz_speed := sqrt(velocity.z**2 + velocity.x**2)
	var t := (horz_speed - _max_walk_speed) / (_sprint_speed - _max_walk_speed)
	t = clamp(t, 0, 1)
	const default_fov = 75.0
	cam.fov = lerp(default_fov, _sprint_fov, t * t) # Quadratic ease-in
	
	# Since `_mouse_relative` is only updated when mouse position changes, we
	# manually reset it right before the next frame using `call_deferred`.
	(func() -> void: _mouse_relative = Vector2.ZERO).call_deferred()

func _physics_process(delta : float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	assert(_time_to_max_walk_speed >= delta) # no division by zero
	
	print(
		"WALK" if _movestate == Movestate.WALK else 
		"SPRINT" if _movestate == Movestate.SPRINT else  
		"JUMP_AIR" if _movestate == Movestate.JUMP_AIR else 
		"DIVE" if _movestate == Movestate.DIVE else 
		"DIVE HITSTUN" if _movestate == Movestate.DIVE_HITSTUN else 
		""
	)

	const err_tol = 0.0001

	var move_input := Input.get_vector("move_leftwards", "move_rightwards", 
		"move_forwards", "move_backwards")
	var is_moving_forwards := (
		move_input != Vector2.ZERO 
		and move_input.angle_to(Vector2.UP) < PI/2 - err_tol
		and move_input.angle_to(Vector2.UP) > -PI/2 + err_tol
	)
	var move_input_dir := (transform.basis 
		* Vector3(move_input.x, 0, move_input.y)).normalized()
	
	var accelerate_velocity_in_move_dir := func(max_speed : float,
		accel : float) -> void:
		if move_input_dir: # nonzero
			velocity.x = move_toward(velocity.x, move_input_dir.x * max_speed,
				accel * delta)
			velocity.z = move_toward(velocity.z, move_input_dir.z * max_speed,
				accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, accel * delta)
			velocity.z = move_toward(velocity.z, 0, accel * delta)
	
	var handle_interact_and_grab_input := func() -> void:
		if Input.is_action_just_pressed("interact"):
			print("attempted interact / grab!")
			var is_grab_successful := false 
			var _is_grab_off_cooldown := ((Time.get_ticks_msec() / 1000.0) 
				>= _last_grab_attempt_time + _grab_cooldown)
			if _is_grab_off_cooldown:
				_last_grab_attempt_time = Time.get_ticks_msec() / 1000.0
				if _grab_raycaster.is_colliding():
					is_grab_successful = true
					var rabbit := _grab_raycaster.get_collider()
					rabbit.queue_free()
					print("grabbed!")
			if _interact_raycaster.is_colliding() and !is_grab_successful:
				print("interacted!")
	
	# Only call this after horizontal velocity is updated.
	var handle_jump_input := func() -> void:
		if Input.is_action_just_pressed("jump"):
			assert(is_on_floor())
			var jump_vel := sqrt(2 * _grav * _jump_height)
			velocity.y = jump_vel
			_ground_takeoff_horz_velocity = Vector2(velocity.x, velocity.z)
	
	match _movestate:
		Movestate.WALK:
			
			handle_interact_and_grab_input.call()
			
			var accel := _max_walk_speed / _time_to_max_walk_speed
			accelerate_velocity_in_move_dir.call(_max_walk_speed, accel)
			
			handle_jump_input.call()
			
			if Input.is_action_just_pressed("sprint") and is_moving_forwards:
				_is_sprint_toggled = true
			
			_movestate = (
				Movestate.JUMP_AIR if !is_on_floor() else 
				Movestate.SPRINT if _is_sprint_toggled else
				Movestate.WALK
			)
			
		Movestate.SPRINT:
			
			var accel := _sprint_speed / _time_to_sprint
			accelerate_velocity_in_move_dir.call(_sprint_speed, accel)
			
			var is_at_max_sprint_speed := (sqrt(velocity.z ** 2
				 + velocity.x ** 2) >= _sprint_speed - err_tol)
			
			var _is_dive_just_started := false
			if Input.is_action_just_pressed("dive") and is_at_max_sprint_speed:
				assert(is_on_floor())
				_is_dive_just_started = true
				_last_dive_start_time = Time.get_ticks_msec() / 1000.0
				
				# Perform dive.
				var dive_y_vel := sqrt(2 * _dive_grav * _dive_height)
				var t_up := dive_y_vel / _dive_grav
				var t_total := 2.0 * (t_up)
				var dive_forward_vel := _dive_dist / t_total
				velocity = dive_forward_vel * move_input_dir
				_ground_takeoff_horz_velocity = Vector2(velocity.x, velocity.x)
				velocity.y = dive_y_vel
				
				# Turn player body in dive direction.
				var turn_anim := create_tween()
				var target_rot := transform.looking_at(
					global_position + move_input_dir
				).basis.get_euler()
				turn_anim.tween_property(self, "rotation", 
					target_rot, _dive_body_yaw_rot_time_length)
			
			handle_jump_input.call()
			
			var should_sprint_break := (Input.is_action_just_pressed("sprint") 
				or !is_moving_forwards or _is_dive_just_started)
			
			if should_sprint_break:
				_is_sprint_toggled = false
			
			_movestate = (
				Movestate.DIVE if _is_dive_just_started else
				Movestate.JUMP_AIR if !is_on_floor() else
				Movestate.WALK if !_is_sprint_toggled else
				Movestate.SPRINT
			)
			
		Movestate.JUMP_AIR:
			
			handle_interact_and_grab_input.call()
			
			if !is_on_floor():
				velocity.y -= _grav * delta
			
			var accel := _midair_accel_multiplier * (_max_walk_speed 
				/ _time_to_max_walk_speed)
			accelerate_velocity_in_move_dir.call(
				_ground_takeoff_horz_velocity.length(), accel
			)
			
			if Input.is_action_just_pressed("sprint"):
				_is_sprint_toggled = true
			
			if is_on_floor() and _is_sprint_toggled and !is_moving_forwards: 
				_is_sprint_toggled = false
			
			_movestate = (
				Movestate.SPRINT if is_on_floor() and _is_sprint_toggled else
				Movestate.WALK if is_on_floor() else 
				Movestate.JUMP_AIR
			)
			
		Movestate.DIVE:
			
			if is_on_floor():
				_last_dive_land_time = Time.get_ticks_msec() / 1000.0
				var dive_hitstun_anim := create_tween().set_parallel()
				dive_hitstun_anim.tween_property(self, "rotation", rotation,
					_dive_hitstun)
				dive_hitstun_anim.tween_property(cam, "rotation", Vector3.ZERO,
					_dive_hitstun)
			else:
				velocity.y -= _dive_grav * delta
			_movestate = (
				Movestate.DIVE_HITSTUN if is_on_floor() else 
				Movestate.DIVE
			)
			
		Movestate.DIVE_HITSTUN:
			
			assert(is_on_floor()) # TODO: This gets hit when colliding into rabbit.
								  # So make that impossible while diving.
			velocity = Vector3.ZERO
			var _is_hitstun_over := ((Time.get_ticks_msec() / 1000.0) 
				>= _last_dive_land_time + _dive_hitstun)
			_movestate = (
				Movestate.WALK if _is_hitstun_over else
				Movestate.DIVE_HITSTUN
			)
			
	move_and_slide()
