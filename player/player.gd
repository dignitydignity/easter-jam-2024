extends CharacterBody3D
class_name Player

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@onready var _cam_pivot : Node3D = %CamPivot
@onready var cam : Camera3D = %Camera

# Get the gravity from the project settings to be synced with RigidBody nodes.
var _gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _mouse_relative : Vector2

func _input(event : InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	
	# If mouse position changed between polling, cache it's relative motion to
	# rotate the camera pivot and player body (for FPS camera controls).
	if event is InputEventMouseMotion:
		_mouse_relative = -event.relative

func _process(delta : float) -> void:
	# Rotate camera pitch.
	_cam_pivot.rotate_x(_mouse_relative.y * delta)
	_cam_pivot.rotation_degrees.x = clampf(_cam_pivot.rotation_degrees.x, -75, 75)
	
	# Rotate player body yaw.
	rotate_y(_mouse_relative.x * delta)
	
	# Right before the next frame begins, reset mouse relative. So that camera
	# doesn't keep moving.
	var reset_mouse_relative = func() -> void: _mouse_relative = Vector2.ZERO
	reset_mouse_relative.call_deferred()

func _physics_process(delta : float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
