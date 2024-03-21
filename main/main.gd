extends Node3D
class_name Main

# Error tolerance for floating point comparisons.
const ERR_TOL = 0.0001

@onready var _start_menu : StartMenu = %StartMenu
@onready var _pause_menu : PauseMenu = %PauseMenu
@onready var _options_menu : Control = %OptionsMenu
@onready var _music : AudioStreamPlayer = %Music
@onready var _tutorial : Control = %Tutorial
@onready var _tutorial_start_button : TextureButton = %TutorialStartButton
@onready var fullscreen_button : TextureButton = %FullscreenButton

@onready var _music_slider : HSlider = %MusicSlider
@onready var _volume_slider : HSlider = %VolumeSlider
@onready var _mouse_sens_slider : VSlider = %MouseSensSlider

const song1 := preload("res://audio/music/roy_t1.mp3")
const song2 := preload("res://audio/music/nate_t1.mp3")
const song3 := preload("res://audio/music/nate_t2.mp3")
# vol = -25?

# When `_gamestate` mutates, important side effects occur.
enum Gamestate { DEFAULT, START_MENU, TUTORIAL, PAUSE, OPTIONS }
var _last_gamestate : Gamestate
var _gamestate : Gamestate:
	get: return _gamestate
	set(new_gamestate):
		match _gamestate: # On exit
			Gamestate.DEFAULT: pass
			Gamestate.TUTORIAL:
				_music.stream = song2
				_music.play()
			Gamestate.START_MENU: pass
			Gamestate.PAUSE: pass
			Gamestate.OPTIONS: pass
		
		_last_gamestate = _gamestate
		_gamestate = new_gamestate
		
		match new_gamestate: # On entry
			Gamestate.DEFAULT:
				get_tree().paused = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				_tutorial.visible = false
				_start_menu.visible = false
				_pause_menu.visible = false
				_options_menu.visible = false
			Gamestate.START_MENU:	
				get_tree().paused = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_tutorial.visible = false
				_start_menu.visible = true
				_pause_menu.visible = false
				_options_menu.visible = false
				_start_menu.button_holder.visible = true
				_start_menu.title_card.visible = true
			Gamestate.TUTORIAL:
				get_tree().paused = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_tutorial.visible = true
				_start_menu.visible = false
				_pause_menu.visible = false
				_options_menu.visible = false
			Gamestate.PAUSE:
				get_tree().paused = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_tutorial.visible = false
				_start_menu.visible = false
				_pause_menu.visible = true
				_options_menu.visible = false
			Gamestate.OPTIONS:
				get_tree().paused = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_start_menu.button_holder.visible = false
				_start_menu.title_card.visible = false
				#_tutorial.visible = false
				#_start_menu.visible = false
				#_pause_menu.visible = false
				_options_menu.visible = true

var _music_bus_id : int
var _sfx_bus_id : int
static var mouse_sens : float = 1.0

func _ready() -> void:
	randomize()
	
	_music_bus_id = AudioServer.get_bus_index("Music")
	_sfx_bus_id = AudioServer.get_bus_index("Sfx")
	
	_gamestate = Gamestate.START_MENU
	_music.stream = song1
	_music.play()
	_music.finished.connect(func(): _music.play())
	
	assert(process_mode == PROCESS_MODE_ALWAYS)
	assert(_options_menu.process_mode == PROCESS_MODE_ALWAYS)
	assert(_options_menu.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	
	_start_menu.play_pressed.connect(func(): _gamestate = Gamestate.TUTORIAL)
	_start_menu.options_pressed.connect(func(): _gamestate = Gamestate.OPTIONS)
	_pause_menu.resume_pressed.connect(func(): _gamestate = Gamestate.DEFAULT)
	_pause_menu.options_pressed.connect(func(): _gamestate = Gamestate.OPTIONS)
	
	fullscreen_button.pressed.connect(
		func(): 
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)
	
	_music_slider.value_changed.connect(
		func(new_value: float) -> void:
			AudioServer.set_bus_volume_db(_music_bus_id, linear_to_db(new_value))
	)
	
	_volume_slider.value_changed.connect(
		func(new_value: float) -> void:
			AudioServer.set_bus_volume_db(_sfx_bus_id, linear_to_db(new_value))
	)
	
	_mouse_sens_slider.value_changed.connect(_cache_mouse_sens)
	
	# TODO: Fade in/out
	_tutorial_start_button.pressed.connect(func(): _gamestate = Gamestate.DEFAULT)
	
func _cache_mouse_sens(new_value: float) -> void:
	mouse_sens = new_value

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		match _gamestate:
			Gamestate.DEFAULT: _gamestate = Gamestate.PAUSE
			Gamestate.START_MENU: pass
			Gamestate.TUTORIAL: pass
			Gamestate.PAUSE: _gamestate = Gamestate.DEFAULT
			Gamestate.OPTIONS: _gamestate = _last_gamestate
