extends Control
class_name PauseMenu

@onready var _resume : TextureButton = %Resume
@onready var _options : TextureButton = %Options
@onready var _exit : TextureButton = %Exit

signal resume_pressed
signal options_pressed
	
func _ready() -> void:
	assert(mouse_filter == MOUSE_FILTER_IGNORE)
	assert(process_mode == PROCESS_MODE_WHEN_PAUSED)
	_resume.pressed.connect(func(): resume_pressed.emit())
	_options.pressed.connect(func(): options_pressed.emit())
	_exit.pressed.connect(func(): get_tree().quit())
