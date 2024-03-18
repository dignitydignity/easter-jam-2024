extends Node3D
class_name Main

static var rng := RandomNumberGenerator.new()

@onready var _pause_menu : PauseMenu = %Pause
@onready var _options_menu : Control = %OptionsMenu

enum Gamestate { DEFAULT, PAUSE, OPTIONS }
var _gamestate := Gamestate.DEFAULT:
	get: return _gamestate
	set(new_gamestate):
		_gamestate = new_gamestate
		match new_gamestate:
			Gamestate.DEFAULT:
				get_tree().paused = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_pause_menu.visible = false
				_options_menu.visible = false
			Gamestate.PAUSE:
				get_tree().paused = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_pause_menu.visible = true
				_options_menu.visible = false
			Gamestate.OPTIONS:
				get_tree().paused = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_pause_menu.visible = false
				_options_menu.visible = true

func _ready() -> void:
	assert(process_mode == PROCESS_MODE_ALWAYS)
	assert(_options_menu.process_mode == PROCESS_MODE_ALWAYS)
	assert(_options_menu.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pause_menu.resume_pressed.connect(func(): _gamestate = Gamestate.DEFAULT)
	_pause_menu.options_pressed.connect(func(): _gamestate = Gamestate.OPTIONS)
	
func _input(input: InputEvent) -> void:
	if input.is_action_pressed("pause"):
		match _gamestate:
			Gamestate.DEFAULT: _gamestate = Gamestate.PAUSE
			Gamestate.PAUSE: _gamestate = Gamestate.DEFAULT
			Gamestate.OPTIONS: _gamestate = Gamestate.PAUSE
