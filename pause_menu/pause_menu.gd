extends Control
class_name PauseMenu

@onready var _resume : Button = %Resume
@onready var _options : Button = %Options
@onready var _exit : Button = %Exit

signal resume_pressed
signal options_pressed
	
func _ready() -> void:
	assert(mouse_filter == MOUSE_FILTER_IGNORE)
	assert(process_mode == PROCESS_MODE_WHEN_PAUSED)
	_resume.pressed.connect(func(): resume_pressed.emit())
	_options.pressed.connect(func(): options_pressed.emit())
	_exit.pressed.connect(func(): get_tree().quit())

#func _process(delta) -> void:
	#print("pause is processing")
