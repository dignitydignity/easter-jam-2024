extends CharacterBody3D
class_name Player

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var _gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _mouse_relative : Vector2

@onready var _cam_pivot : Node3D = %CamPivot
@onready var cam : Camera3D = %Camera

func _input(event : InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	
	# If mouse position changed between polling, cache it's relative motion to
	# rotate the camera pivot and player body (for FPS camera controls).
	if event is InputEventMouseMotion:
		_mouse_relative = -event.relative

func _process(delta : float) -> void:
	# FPS camera controls.
	const camera_rot_scale = 0.2
	_cam_pivot.rotate_x(_mouse_relative.y * delta * camera_rot_scale)
	_cam_pivot.rotation_degrees.x = clampf(_cam_pivot.rotation_degrees.x, -75, 75)
	rotate_y(_mouse_relative.x * delta * camera_rot_scale)
	
	# Right before the next frame begins, reset mouse relative. So that camera
	# doesn't keep moving.
	var reset_mouse_relative = func() -> void: _mouse_relative = Vector2.ZERO
	reset_mouse_relative.call_deferred()

func _physics_process(delta : float) -> void:
	# Set vertical velocity.
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Set horizontal velocity.
	var input_dir := Input.get_vector("move_leftwards", "move_rightwards", "move_forwards", "move_backwards")
	var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if move_dir:
		velocity.x = move_dir.x * SPEED
		velocity.z = move_dir.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
