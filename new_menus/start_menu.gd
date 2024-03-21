extends Control
class_name StartMenu

@onready var title_card : TextureRect = %TitleCard
@onready var button_holder : TextureRect = %ButtonHolder

@onready var play : TextureButton = %Play
@onready var options : TextureButton = %Options
@onready var exit : TextureButton = %Exit

signal play_pressed
signal options_pressed
	
func _ready() -> void:
	assert(mouse_filter == MOUSE_FILTER_IGNORE)
	assert(process_mode == PROCESS_MODE_ALWAYS)
	play.pressed.connect(func(): play_pressed.emit())
	options.pressed.connect(func(): options_pressed.emit())
	exit.pressed.connect(func(): get_tree().quit())
