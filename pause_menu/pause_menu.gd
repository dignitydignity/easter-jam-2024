extends Control
class_name PauseMenu

@onready var resume : Button = $Resume
@onready var exit : Button = $Exit
@onready var options : Button = $Options

signal resume_clicked
signal options_clicked
	
func _ready() -> void:
	resume.pressed.connect(
		func(): resume_clicked.emit()
	)
	options.pressed.connect(
		func(): options_clicked.emit()
	)
	exit.pressed.connect(
		func(): get_tree().quit()
	)
