extends Node3D
class_name Main

# Error tolerance for floating point comparisons.
const ERR_TOL = 0.0001

@onready var _pause_menu : PauseMenu = %PauseMenu
@onready var _options_menu : Control = %OptionsMenu
@onready var _music : AudioStreamPlayer = %Music

const song1 := preload("res://audio/music/roy_t1.mp3")
const song2 := preload("res://audio/music/nate_t1.mp3")
const song3 := preload("res://audio/music/nate_t2.mp3")

# When `_gamestate` mutates, important side effects occur.
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
	_music.stream = song2
	_music.play()
	_music.finished.connect(
		func():
			_music.play()
	)
	#seed(12345) # Fixed seed for debugging.
	#randomize() # Randomize initial seed for global RNG.
	
	assert(process_mode == PROCESS_MODE_ALWAYS)
	assert(_options_menu.process_mode == PROCESS_MODE_ALWAYS)
	assert(_options_menu.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	_pause_menu.resume_pressed.connect(func(): _gamestate = Gamestate.DEFAULT)
	_pause_menu.options_pressed.connect(func(): _gamestate = Gamestate.OPTIONS)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		match _gamestate:
			Gamestate.DEFAULT: _gamestate = Gamestate.PAUSE
			Gamestate.PAUSE: _gamestate = Gamestate.DEFAULT
			Gamestate.OPTIONS: _gamestate = Gamestate.PAUSE
