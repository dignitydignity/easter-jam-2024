extends Node3D
class_name Main

static var rng := RandomNumberGenerator.new()
var pause : Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause = $Pause

func _input(input: InputEvent) -> void:
	if input.is_action_pressed("pause"):
		pause.visible = !pause.visible
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
