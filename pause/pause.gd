extends Control
class_name Pause

@onready var resume : Button = $Resume
@onready var exit : Button = $Exit

func resume_game():
	visible = false
	
func exit_game():
	get_tree().quit()
	
func toggle_mouse_visible():
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _ready():
	resume.pressed.connect(resume_game)
	exit.pressed.connect(exit_game)
	visibility_changed.connect(toggle_mouse_visible)
