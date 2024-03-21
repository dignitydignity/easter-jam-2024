extends Node3D
class_name Main

# Error tolerance for floating point comparisons.
const ERR_TOL = 0.0001

@onready var _start_menu : StartMenu = %StartMenu
@onready var _pause_menu : PauseMenu = %PauseMenu
@onready var _options_menu : Control = %OptionsMenu
@onready var _music : AudioStreamPlayer = %Music

const song1 := preload("res://audio/music/roy_t1.mp3")
const song2 := preload("res://audio/music/nate_t1.mp3")
const song3 := preload("res://audio/music/nate_t2.mp3")

# When `_gamestate` mutates, important side effects occur.
enum Gamestate { DEFAULT, START_MENU, PAUSE, OPTIONS }
var _last_gamestate : Gamestate
var _gamestate : Gamestate:
	get: return _gamestate
	set(new_gamestate):
		match _gamestate: # On exit
			Gamestate.DEFAULT: pass
			Gamestate.START_MENU:
				_music.stream = song2
				_music.play()
			Gamestate.PAUSE: pass
			Gamestate.OPTIONS: pass
		
		_last_gamestate = _gamestate
		_gamestate = new_gamestate
		
		match new_gamestate: # On entry
			Gamestate.DEFAULT:
				get_tree().paused = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_start_menu.visible = false
				_pause_menu.visible = false
				_options_menu.visible = false
			Gamestate.START_MENU:	
				get_tree().paused = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_start_menu.visible = true
				_pause_menu.visible = false
				_options_menu.visible = false
			Gamestate.PAUSE:
				get_tree().paused = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_start_menu.visible = false
				_pause_menu.visible = true
				_options_menu.visible = false
			Gamestate.OPTIONS:
				get_tree().paused = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_start_menu.visible = false
				_pause_menu.visible = false
				_options_menu.visible = true


func _ready() -> void:
	randomize()
	_gamestate = Gamestate.START_MENU
	_music.stream = song1
	_music.play()
	_music.finished.connect(func(): _music.play())
	
	assert(process_mode == PROCESS_MODE_ALWAYS)
	assert(_options_menu.process_mode == PROCESS_MODE_ALWAYS)
	assert(_options_menu.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	
	_start_menu.play_pressed.connect(func(): _gamestate = Gamestate.DEFAULT)
	_pause_menu.resume_pressed.connect(func(): _gamestate = Gamestate.DEFAULT)
	_pause_menu.options_pressed.connect(func(): _gamestate = Gamestate.OPTIONS)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		match _gamestate:
			Gamestate.DEFAULT: _gamestate = Gamestate.PAUSE
			Gamestate.START_MENU: pass
			Gamestate.PAUSE: _gamestate = Gamestate.DEFAULT
			Gamestate.OPTIONS: _gamestate = _last_gamestate
