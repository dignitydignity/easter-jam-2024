extends Node3D
class_name Main

static var cam : Camera3D
static var rng := RandomNumberGenerator.new()

func _ready():
	cam = %Camera
