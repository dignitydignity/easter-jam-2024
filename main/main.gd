extends Node3D
class_name Main

static var cam : Camera3D
static var player : Player
static var rng := RandomNumberGenerator.new()

func _ready() -> void:
	player = %Player
	cam = player.cam
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
