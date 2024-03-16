extends CharacterBody3D
class_name Player

# TODO: Sprinting.
# TODO: Diving -> leftclick while sprinting.

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
@export_range(-0.1, 100) var _sprint_speed : float
@export_range(0.1, 100) var _max_walk_speed : float
@export_range(0.02, 3) var _time_to_max_walk_speed : float
@export_group("Dive")
@export_range(0.5, 10) var _dive_height : float
@export_range(0, 20) var _dive_dist : float
@export_range(0, 5) var _dive_cam_rot_delay : float
@export_range(-90, 0) var _dive_cam_pitch_min : float
@export_range(0, 5) var _dive_hitstun : float

# Internal state.
@onready var cam : Camera3D = %Camera
var _mouse_relative : Vector2

@onready var _grab_raycaster : RayCast3D = %GrabRaycaster
@onready var _interact_raycaster : RayCast3D = %InteractRaycaster
var _last_grab_attempt_time : float

enum Movestate { WALK, SPRINT, JUMP_AIR, DIVE, DIVE_HITSTUN }
var _movestate : Movestate
var _last_dive_start_time : float # Time units = seconds.
var _last_dive_land_time : float

func _ready() -> void:
	instance = self
	assert(_interact_raycaster.target_position == _grab_range * Vector3.FORWARD)
	# TODO: Compute initial `_movestate`, so that I can use `assert()` later.

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
		Movestate.WALK, Movestate.JUMP_AIR:
			# Standard FPS cam controls.
			const cam_sens = 0.2 # TODO: Make `cam_sens` changeable in settings menu.
			cam.rotate_x(cam_sens * _mouse_relative.y * delta)
			cam.rotation_degrees.x = clampf(cam.rotation_degrees.x, -_cam_pitch_max, _cam_pitch_max)
			rotate_y(cam_sens * _mouse_relative.x * delta)
		Movestate.DIVE:
			# Cam pitch begins downwards rotation after brief time period.
			var is_cam_rot_start_time_passed := ((Time.get_ticks_msec() / 1000.0) 
				> _last_dive_start_time + _dive_cam_rot_delay)
			if is_cam_rot_start_time_passed:
				const rot_speed = PI/2 # radians/second
				cam.rotate_x(-rot_speed * delta)
			cam.rotation_degrees.x = clampf(cam.rotation_degrees.x, 
				_dive_cam_pitch_min, _cam_pitch_max)
		Movestate.DIVE_HITSTUN:
			# Camera doesn't move while in hitstun.
			pass
	
	# Since `_mouse_relative` is only updated when mouse position changes, we
	# manually reset it right before the next frame using `call_deferred`.
	(func() -> void: _mouse_relative = Vector2.ZERO).call_deferred()

func _physics_process(delta : float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	assert(_time_to_max_walk_speed >= delta) # no division by zero
	
	# TODO: Make `func`s non-local for performance reasons if needed.
	var accelerate_velocity_in_move_dir := func(max_speed : float,
		accel : float) -> void:
		var input_dir := Input.get_vector("move_leftwards", "move_rightwards", 
			"move_forwards", "move_backwards")
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if move_dir: # nonzero
			velocity.x = move_toward(velocity.x, move_dir.x * max_speed, accel * delta)
			velocity.z = move_toward(velocity.z, move_dir.z * max_speed, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, accel * delta)
			velocity.z = move_toward(velocity.z, 0, accel * delta)
	
	var handle_interact_and_grab_input := func() -> void:
		if Input.is_action_just_pressed("interact"):
			print("attempted interact / grab!")
			# `was_grab` is so player can't both grab and interact at same time.
			var was_grab := false 
			var _is_grab_off_cooldown := ((Time.get_ticks_msec() / 1000.0) 
				>= _last_grab_attempt_time + _grab_cooldown)
			if _is_grab_off_cooldown:
				_last_grab_attempt_time = Time.get_ticks_msec() / 1000.0
				if _grab_raycaster.is_colliding():
					was_grab = true
					var rabbit := _grab_raycaster.get_collider()
					rabbit.queue_free()
					print("grabbed!")
			if _interact_raycaster.is_colliding() and !was_grab:
				print("interacted!")
	
	match _movestate:
		Movestate.WALK:
			handle_interact_and_grab_input.call()
			
			var accel := _max_walk_speed / _time_to_max_walk_speed
			accelerate_velocity_in_move_dir.call(_max_walk_speed, accel)
			
			if Input.is_action_just_pressed("jump"):
				assert(is_on_floor())
				var jump_vel := sqrt(2 * _grav * _jump_height)
				velocity.y = jump_vel
			
			var _is_dive_just_started := false
			if Input.is_action_just_released("dive"):
				assert(is_on_floor())
				_is_dive_just_started = true
				_last_dive_start_time = Time.get_ticks_msec() / 1000.0
				var dive_y_vel := sqrt(2 * _grav * _dive_height)
				var t_up := dive_y_vel / _grav
				var t_total := 2.0 * (t_up)
				var dive_forward_vel := _dive_dist / t_total
				velocity = -dive_forward_vel * transform.basis.z
				velocity.y = dive_y_vel
			
			_movestate = (
				Movestate.DIVE if _is_dive_just_started else
				Movestate.JUMP_AIR if !is_on_floor() else 
				Movestate.WALK
			)
		Movestate.JUMP_AIR:
			handle_interact_and_grab_input.call()
			
			if !is_on_floor():
				velocity.y -= _grav * delta
			
			var accel := _midair_accel_multiplier * (_max_walk_speed 
				/ _time_to_max_walk_speed)
			accelerate_velocity_in_move_dir.call(_max_walk_speed, accel)
			
			_movestate = (
				Movestate.WALK if is_on_floor() else 
				Movestate.JUMP_AIR
			)
		Movestate.DIVE:
			if is_on_floor():
				_last_dive_land_time = Time.get_ticks_msec() / 1000.0
				var dive_hitstun_anim := create_tween().set_parallel()
				dive_hitstun_anim.tween_property(self, "rotation", rotation, _dive_hitstun)
				dive_hitstun_anim.tween_property(cam, "rotation", Vector3.ZERO, _dive_hitstun)
			else:
				velocity.y -= _grav * delta
			_movestate = (
				Movestate.DIVE_HITSTUN if is_on_floor() else 
				Movestate.DIVE
			)
		Movestate.DIVE_HITSTUN:
			assert(is_on_floor()) # TODO: This gets hit when colliding into rabbit.
								  # So make that impossible while diving.
			var _is_hitstun_over := ((Time.get_ticks_msec() / 1000.0) 
				>= _last_dive_land_time + _dive_hitstun)
			_movestate = (
				Movestate.WALK if _is_hitstun_over else
				Movestate.DIVE_HITSTUN
			)
	move_and_slide()
