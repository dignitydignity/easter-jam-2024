extends CharacterBody3D
class_name Player

# Globally accessible instance; there is only one player.
static var instance : Player

# Design params.
@export_group("camera")
@export_range(0, 90) var _cam_pitch_max : float # 75

@export_group("jumping")
@export_range(0, 50) var _grav : float # 9.8
@export_range(0, 10) var _jump_height : float # 2

@export_group("walking")
@export_range(0.1, 100) var _max_speed : float # 5.0
@export_range(0.02, 3) var _time_to_max_speed : float # 0.05

@export_group("diving")
@export_range(0.5, 10) var _dive_height : float # 1.0
@export_range(0, 20) var _dive_dist : float # 5.0
@export_range(0, 5) var _dive_rot_start_time_offset : float # 0.25
@export_range(-90, 0) var _dive_cam_pitch_min : float # -50
@export_range(0, 5) var _dive_hitstun : float # 0.5

var _mouse_relative : Vector2
var _dive_start_time : float
var _dive_land_time : float
var _is_dive_queued : bool
var _is_diving : bool

@onready var cam : Camera3D = %Camera

func _ready() -> void:
	instance = self

func _input(event : InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	
	# If mouse position changed between polling, cache it's relative motion to
	# rotate the camera and player body (for FPS camera controls in `_process`).
	if event is InputEventMouseMotion:
		_mouse_relative = -event.relative
	
	if event.is_action_released("dive") and is_on_floor():
		_is_dive_queued = true

func _process(delta : float) -> void:
	
	# Since `_mouse_relative` is only updated when mouse position changes, we
	# manually reset it right before the next frame using `call_deferred`.
	var reset_mouse_relative = func() -> void: _mouse_relative = Vector2.ZERO
	
	# Set cam.rotation so that it look like a "dive".
	if _is_diving:
		if (Time.get_ticks_msec() / 1000.0) > _dive_start_time + _dive_rot_start_time_offset:
			cam.rotate_x(-PI/2 * delta)
		cam.rotation_degrees.x = clampf(cam.rotation_degrees.x, _dive_cam_pitch_min, _cam_pitch_max)
		reset_mouse_relative.call_deferred()
		return
	
	# FPS camera controls.
	const cam_rot_scale = 0.2 # TODO: Change this in settings menu.
	cam.rotate_x(cam_rot_scale * _mouse_relative.y * delta)
	cam.rotation_degrees.x = clampf(cam.rotation_degrees.x, -_cam_pitch_max, _cam_pitch_max)
	rotate_y(cam_rot_scale * _mouse_relative.x * delta)
	
	reset_mouse_relative.call_deferred()

func _physics_process(delta : float) -> void:
	# Set vertical velocity.	
	if not is_on_floor():
		velocity.y -= _grav * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		var jump_vel := sqrt(2 * _grav * _jump_height)
		velocity.y = jump_vel

	# If the player is airborne, have them maintain their momentum. Otherwise,
	# move them in accordance to user inputs.
	if is_on_floor():
		if _is_diving:
			_dive_land_time = Time.get_ticks_msec() / 1000.0

			var dive_hitstun_anim = create_tween().set_parallel()
			dive_hitstun_anim.tween_property(self, "rotation", rotation, _dive_hitstun)
			dive_hitstun_anim.tween_property(cam, "rotation", Vector3.ZERO, _dive_hitstun)
			_is_diving = false
		
		# If the player is in hitstun, prevent all movement.
		if (Time.get_ticks_msec() / 1000.0) < _dive_land_time + _dive_hitstun: return
		
		# Set horizontal velocity.
		var accel = _max_speed / _time_to_max_speed
		var input_dir := Input.get_vector("move_leftwards", "move_rightwards", "move_forwards", "move_backwards")
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if move_dir: # nonzero
			velocity.x = move_toward(velocity.x, move_dir.x * _max_speed, accel * delta)
			velocity.z = move_toward(velocity.z, move_dir.z * _max_speed, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, accel * delta)
			velocity.z = move_toward(velocity.z, 0, accel * delta)
		
		if _is_dive_queued:
			_is_diving = true
			_dive_start_time = Time.get_ticks_msec() / 1000.0
			var dive_y_vel := sqrt(2 * _grav * _dive_height)
			var t_up := dive_y_vel / _grav
			var t_total := 2.0 * (t_up)
			var dive_forward_vel := _dive_dist / t_total
			velocity.y = dive_y_vel
			velocity -= dive_forward_vel * transform.basis.z
			
		_is_dive_queued = false
	
	move_and_slide()
