extends Control
class_name Pause

@onready var resume : Button = $Resume
@onready var exit : Button = $Exit

func resume_game():
	visible = false
	
func _ready():
	resume.pressed.connect(resume_game)
