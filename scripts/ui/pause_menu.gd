# In-match pause: Resume / Settings (Controls) / Quit to main menu.
# Toggled by `menu` action. process_mode ALWAYS so it receives input while paused.
extends CanvasLayer

const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"

@onready var _root: Control = %Root
@onready var _panel: Control = %Panel

var _settings: Control = null
var _was_mouse_captured: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	%ResumeButton.pressed.connect(_resume)
	%SettingsButton.pressed.connect(_open_settings)
	%QuitButton.pressed.connect(_quit_to_menu)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("menu"):
		return
	if _settings != null and _settings.visible:
		return
	if _root.visible:
		_resume()
	else:
		_open_pause()
	get_viewport().set_input_as_handled()


func _open_pause() -> void:
	_was_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.visible = true
	_panel.visible = true
	get_tree().paused = true


func _resume() -> void:
	if _settings != null:
		_settings.visible = false
	_root.visible = false
	get_tree().paused = false
	if _was_mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_settings() -> void:
	if _settings == null:
		_settings = SETTINGS_SCENE.instantiate()
		_root.add_child(_settings)
		if _settings.has_signal("closed"):
			_settings.closed.connect(func() -> void:
				_panel.visible = true)
	_panel.visible = false
	if _settings.has_method("open_settings"):
		_settings.open_settings("display")
	else:
		_settings.visible = true


func _quit_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
