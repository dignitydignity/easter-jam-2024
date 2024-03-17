extends Node3D
class_name Main

static var rng := RandomNumberGenerator.new()

@onready var pause_menu : PauseMenu = $Pause
@onready var options_menu : Control = $OptionsMenu

enum GameState { DEFAULT, PAUSE, OPTIONS }
var game_state := GameState.DEFAULT

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pause_menu.options_clicked.connect(
		func(): game_state = GameState.OPTIONS
	)
	pause_menu.resume_clicked.connect(
		func(): game_state = GameState.DEFAULT
	)
	
func _input(input: InputEvent) -> void:
	if input.is_action_pressed("pause"):
		match game_state:
			GameState.DEFAULT:
				game_state = GameState.PAUSE
			GameState.PAUSE:
				game_state = GameState.DEFAULT
			GameState.OPTIONS:
				game_state = GameState.PAUSE

func _process(_delta : float) -> void:
	match game_state:
		GameState.DEFAULT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			pause_menu.visible = false
			options_menu.visible = false
		GameState.PAUSE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			pause_menu.visible = true
			options_menu.visible = false
		GameState.OPTIONS:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			pause_menu.visible = false
			options_menu.visible = true
