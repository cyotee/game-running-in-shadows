# Settings shell: Display + Controls tabs (main menu and pause).
extends Control

signal closed()

const CONTROLS_SCENE := preload("res://scenes/ui/controls_menu.tscn")
const DISPLAY_SCENE := preload("res://scenes/ui/display_menu.tscn")

@onready var _host: Control = %ContentHost
@onready var _title: Label = %TitleLabel

var _controls: Control = null
var _display: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%BackButton.pressed.connect(_on_back)
	%ControlsTab.pressed.connect(func() -> void: _show_tab("controls"))
	%DisplayTab.pressed.connect(func() -> void: _show_tab("display"))
	visible = false


func open_settings(tab: String = "display") -> void:
	visible = true
	_show_tab(tab)


func _show_tab(tab: String) -> void:
	if tab == "controls":
		_title.text = "Settings — Controls"
		_ensure_controls()
		if _display != null:
			_display.visible = false
		_controls.visible = true
		if _controls.has_method("open_panel"):
			_controls.open_panel()
	else:
		_title.text = "Settings — Display"
		_ensure_display()
		if _controls != null:
			_controls.visible = false
		_display.visible = true
		if _display.has_method("open_panel"):
			_display.open_panel()


func _ensure_controls() -> void:
	if _controls != null:
		return
	_controls = CONTROLS_SCENE.instantiate()
	_host.add_child(_controls)
	if _controls.has_signal("closed"):
		_controls.closed.connect(_on_back)


func _ensure_display() -> void:
	if _display != null:
		return
	_display = DISPLAY_SCENE.instantiate()
	_host.add_child(_display)
	if _display.has_signal("closed"):
		_display.closed.connect(_on_back)


func _on_back() -> void:
	if _controls != null and InputBindings.listen_mode == InputBindings.ListenMode.LISTENING:
		InputBindings.cancel_listen()
	visible = false
	closed.emit()
