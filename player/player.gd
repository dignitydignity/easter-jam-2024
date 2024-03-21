extends CharacterBody3D
class_name Player

# Globally accessible instance; there is only one player.
static var instance : Player

# Design params (constants).
# 	Distance units = meters.
# 	Time units = seconds.
@export_group("General")
# To set grab range, modify reference's `TargetPosition`.
#@export var _grab_raycaster : RayCast3D
@export var _grab_hitbox : Area3D
@export var _interact_raycaster : RayCast3D
@export_range(0, 5) var _grab_cooldown : float
@export_range(0, 90) var _cam_pitch_max : float
@export_group("Jump")
@export_range(0, 10) var _jump_drag : float
@export_range(0, 50) var _upwards_grav : float
@export_range(0, 50) var _downwards_grav : float
@export_range(0, 10) var _jump_height : float
@export_range(0, 1) var _midair_accel_multiplier : float
@export_group("Walk")
@export_range(0.1, 100) var _max_walk_speed : float
@export_range(0.02, 3) var _time_to_max_walk_speed : float
@export_group("Sprint")
@export_range(0.1, 100) var _sprint_speed : float
@export_range(0.02, 5) var _time_to_sprint : float
@export_range(0.02, 5) var _time_to_stop_sprint : float
@export_range(75.1, 179.0) var _sprint_fov : float
@export_group("Dive")
# To adjust hitboxes, modify reference and it's children directly.
@export var _dive_grab_hitboxes : Array[Area3D]
@export_range(0.1, 100) var _min_speed_for_dive : float
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

var _last_grab_attempt_time : float

enum Movestate { WALK, SPRINT, JUMP_AIR, DIVE, DIVE_HITSTUN }
var _movestate : Movestate
var _is_sprint_toggled : bool
var _ground_takeoff_horz_speed : float
var _last_dive_start_time : float 
var _last_dive_land_time : float

@onready var _hud : Control = %Hud
@onready var _fps_label : Label = %FpsLabel
#@onready var _movestate_label : Label = %MovestateLabel
#@onready var _horizontal_speed_label : Label = %HorizontalSpeedLabel
#@onready var _grab_cooldown_label : Label = %GrabCooldownLabel
@onready var _headcount_label : Label = %HeadcountLabel
var _num_caught_rabbits := 0


@onready var _sfx_grab : AudioStreamPlayer = %SfxGrab
#const SFX_GRAB = preload("res://audio/sfx/grab_rabbit.wav")

@onready var _sfx_land : AudioStreamPlayer = %SfxLand
#const SFX_PLAYER_LAND = preload("res://audio/sfx/player_land.wav")

@onready var _sfx_catch : AudioStreamPlayer = %SfxCatch
#const SFX_CATCH_RABBIT = preload("res://audio/sfx/magic_game_win_success_cc0.wav")

var _is_dive_land_miss := true
signal dive_land_missed

func _ready() -> void:
	assert(_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(process_mode == PROCESS_MODE_PAUSABLE)
	instance = self
	
	for box in _dive_grab_hitboxes:
		assert(!box.monitoring)
		assert(!box.monitorable)
		assert(box.collision_mask == 2)
		box.body_entered.connect(
			func(body : Node3D) -> void:
				_is_dive_land_miss = false
				var rabbit := body as Rabbit
				assert(!rabbit._is_caught)
				rabbit.catch()
				assert(rabbit._is_caught)
				#rabbit.queue_free()
				_sfx_catch.play()
				_num_caught_rabbits += 1
				_headcount_label.text = "x %d" % _num_caught_rabbits
				print("dive grab!")
		)

func _input(event : InputEvent) -> void:
	# If mouse position changed between polling, cache it's relative motion to
	# rotate the camera and player body (for FPS camera controls in `_process`).
	if event is InputEventMouseMotion:
		_mouse_relative = - Main.mouse_sens * event.relative


func _process(delta : float) -> void:
	
	var horz_speed := sqrt(velocity.x ** 2 + velocity.z ** 2)
	
	# Update debug labels.
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	#_movestate_label.text = "Movestate: %s " % (
		#"WALK" if _movestate == Movestate.WALK else 
		#"SPRINT" if _movestate == Movestate.SPRINT else  
		#"JUMP_AIR" if _movestate == Movestate.JUMP_AIR else 
		#"DIVE" if _movestate == Movestate.DIVE else 
		#"DIVE HITSTUN" if _movestate == Movestate.DIVE_HITSTUN else 
		#""
	#)

	#var speed_text := "Speed: %.2f" % horz_speed
	#var is_sprinting_and_above_dive_speed_threshold := (
		#_movestate == Movestate.SPRINT 
		#and horz_speed >= _min_speed_for_dive - Main.ERR_TOL
	#)
	#if is_sprinting_and_above_dive_speed_threshold:
		#_horizontal_speed_label.modulate = Color.GREEN
		#_horizontal_speed_label.text = speed_text + " (can dive)"
	#else:
		#_horizontal_speed_label.modulate = Color.WHITE
		#_horizontal_speed_label.text = speed_text
	#
	#var remaining_grab_cooldown = maxf(_last_grab_attempt_time 
		#+ _grab_cooldown - Time.get_ticks_msec() / 1000.0, 0)
	#_grab_cooldown_label.text = "Grab Cooldown: %.2f" % remaining_grab_cooldown
	
	# Update camera and player rotation.
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
	var t := (horz_speed - _max_walk_speed) / (_sprint_speed - _max_walk_speed)
	t = clamp(t, 0, 1)
	const default_fov = 75.0
	cam.fov = lerp(default_fov, _sprint_fov, t * t) # Quadratic ease-in
	
	# Since `_mouse_relative` is only updated when mouse position changes, we
	# manually reset it right before the next frame using `call_deferred`.
	_reset_mouse_rel.call_deferred()
	#(func() -> void: _mouse_relative = Vector2.ZERO).call_deferred()

func _reset_mouse_rel() -> void:
	_mouse_relative = Vector2.ZERO

func _physics_process(delta : float) -> void:
	assert(_time_to_max_walk_speed >= delta) # no division by zero
	_grab_hitbox.monitoring = _movestate == Movestate.DIVE
	
	var move_input := Input.get_vector("move_leftwards", "move_rightwards", 
		"move_forwards", "move_backwards")
	var is_moving_forwards := (
		move_input != Vector2.ZERO 
		and move_input.angle_to(Vector2.UP) < PI/2 - Main.ERR_TOL
		and move_input.angle_to(Vector2.UP) > -PI/2 + Main.ERR_TOL
	)
	var move_input_rel_dir := (transform.basis 
		* Vector3(move_input.x, 0, move_input.y)).normalized()
	
	var accelerate_velocity_in_move_dir := func(max_speed : float,
		accel : float) -> void:
		if move_input_rel_dir: # nonzero
			velocity.x = move_toward(velocity.x, move_input_rel_dir.x * max_speed,
				accel * delta)
			velocity.z = move_toward(velocity.z, move_input_rel_dir.z * max_speed,
				accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, accel * delta)
			velocity.z = move_toward(velocity.z, 0, accel * delta)
	
	var handle_interact_and_grab_input := func() -> void:
		if Input.is_action_just_pressed("action"):
			#print("attempted action!")
			var is_grab_successful := false 
			var _is_grab_off_cooldown := ((Time.get_ticks_msec() / 1000.0) 
				>= _last_grab_attempt_time + _grab_cooldown)
			if _is_grab_off_cooldown:
				_sfx_grab.play()
				_last_grab_attempt_time = Time.get_ticks_msec() / 1000.0
				_grab_hitbox.monitoring = true # Turn it on for a frame (gets reset above).
				#if _grab_raycaster.is_colliding():
					#is_grab_successful = true
					#var rabbit := _grab_raycaster.get_collider() as Rabbit
					#rabbit.queue_free()
					#_num_caught_rabbits += 1
					#_headcount_label.text = "x %d" % _num_caught_rabbits
					#print("grabbed!")
			if _interact_raycaster.is_colliding() and !is_grab_successful:
				print("non-grab action!")
	
	# Only call this after horizontal velocity is updated.
	var handle_jump_input := func() -> void:
		if Input.is_action_just_pressed("jump") and is_on_floor():
			var jump_vel := sqrt(2 * _upwards_grav * _jump_height)
			velocity.y = jump_vel
			_ground_takeoff_horz_speed = sqrt(velocity.x ** 2 + 
				velocity.z ** 2)
	
	match _movestate:
		Movestate.WALK:
			
			handle_interact_and_grab_input.call()
			
			var accel := _max_walk_speed / _time_to_max_walk_speed
			var horz_speed := sqrt(velocity.x ** 2 + velocity.z ** 2)
			if horz_speed > _max_walk_speed + Main.ERR_TOL:
				# If the player stopped sprinting, they decelerate slower.
				var decel := absf(_sprint_speed - _max_walk_speed) / _time_to_stop_sprint
				accelerate_velocity_in_move_dir.call(_max_walk_speed, decel)
			else:
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
			
			var horz_speed := sqrt(velocity.x ** 2 + velocity.z ** 2)
			var is_at_min_speed_for_dive := horz_speed >= (_min_speed_for_dive - Main.ERR_TOL)
			
			var _is_dive_just_started := false
			if is_on_floor() and Input.is_action_just_pressed("action") and is_at_min_speed_for_dive:
				#assert(is_on_floor())
				_is_dive_land_miss = true
				_is_dive_just_started = true
				_last_dive_start_time = Time.get_ticks_msec() / 1000.0
				
				# Perform dive.
				var dive_y_vel := sqrt(2 * _dive_grav * _dive_height)
				var t_up := dive_y_vel / _dive_grav
				var t_total := 2.0 * (t_up)
				var dive_forward_vel := _dive_dist / t_total
				velocity = dive_forward_vel * move_input_rel_dir
				_ground_takeoff_horz_speed = sqrt(velocity.x ** 2 
					+ velocity.z ** 2)
				velocity.y = dive_y_vel
				
				# Turn player body in dive direction.
				var turn_anim := create_tween()
				var target_rot := transform.looking_at(
					global_position + move_input_rel_dir
				).basis.get_euler()
				turn_anim.tween_property(self, "rotation", 
					target_rot, _dive_body_yaw_rot_time_length)
				
				# Start grabbing rabbits.
				for box in _dive_grab_hitboxes:
					box.monitoring = true
			
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
				velocity.y -= ( # For gamefeel.
					_downwards_grav if velocity.y < 0 else 
					_upwards_grav
				) * delta
			
			# User inputs only maintains a fraction of their normal control
			# while airborne.
			var accel := _midair_accel_multiplier * (_max_walk_speed 
				/ _time_to_max_walk_speed)
			if _ground_takeoff_horz_speed > Main.ERR_TOL:
				accelerate_velocity_in_move_dir.call(
					_ground_takeoff_horz_speed, accel
				)
			else:
				var from_rest_jump_speed = 0.5 * _max_walk_speed 
				accelerate_velocity_in_move_dir.call(
					from_rest_jump_speed, accel
				)
			
			velocity.x -= _jump_drag * velocity.x * delta
			velocity.z -= _jump_drag * velocity.z * delta
			
			# Player can hit the ground sprinting, even if they weren't before.
			if Input.is_action_just_pressed("sprint"):
				_is_sprint_toggled = !_is_sprint_toggled
			
			# But they can cancel their sprint by not holding forwards.
			if is_on_floor() and _is_sprint_toggled and !is_moving_forwards: 
				_is_sprint_toggled = false
			
			_movestate = (
				Movestate.SPRINT if is_on_floor() and _is_sprint_toggled else
				Movestate.WALK if is_on_floor() else 
				Movestate.JUMP_AIR
			)
			
		Movestate.DIVE:
			
			# When the dive ends, animate the camera so that it looks like
			# the player is picking themselves off the ground.
			if is_on_floor():
				_last_dive_land_time = Time.get_ticks_msec() / 1000.0
				_sfx_land.play()
				if _is_dive_land_miss:
					dive_land_missed.emit()
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
			
			# Stop grabbing rabbits.
			for box in _dive_grab_hitboxes:
				box.monitoring = false
			
			velocity = Vector3.ZERO
			
			var _is_hitstun_over := ((Time.get_ticks_msec() / 1000.0) 
				>= _last_dive_land_time + _dive_hitstun)
			_movestate = (
				Movestate.WALK if _is_hitstun_over else
				Movestate.DIVE_HITSTUN
			)
	
	move_and_slide()
