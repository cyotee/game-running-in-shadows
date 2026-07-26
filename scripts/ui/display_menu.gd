# Display preferences panel (resolution, UI scale, fullscreen).
extends Control

signal closed()

var _syncing: bool = false

@onready var _res_option: OptionButton = %ResOption
@onready var _scale_option: OptionButton = %ScaleOption
@onready var _fullscreen: CheckBox = %FullscreenCheck
@onready var _info: Label = %DisplayInfo
@onready var _status: Label = %StatusLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%BackButton.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	%ApplyButton.pressed.connect(_on_apply_clicked)
	_res_option.item_selected.connect(_on_res_selected)
	_scale_option.item_selected.connect(_on_scale_selected)
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_populate()
	_sync_from_config()


func open_panel() -> void:
	visible = true
	_populate()
	_sync_from_config()
	DisplayConfig.apply()
	_refresh_info()


func _populate() -> void:
	_syncing = true
	_res_option.clear()
	for p in DisplayConfig.PRESETS:
		_res_option.add_item(str(p["label"]))
	_scale_option.clear()
	for s in DisplayConfig.UI_SCALE_STEPS:
		_scale_option.add_item("UI x%s" % str(s))
	_syncing = false


func _sync_from_config() -> void:
	_syncing = true
	var pi := DisplayConfig.preset_index_for_current()
	if pi >= 0:
		_res_option.select(pi)
	var scale_idx := 0
	var best := 999.0
	for i in DisplayConfig.UI_SCALE_STEPS.size():
		var d := absf(DisplayConfig.UI_SCALE_STEPS[i] - DisplayConfig.ui_scale)
		if d < best:
			best = d
			scale_idx = i
	_scale_option.select(scale_idx)
	_fullscreen.button_pressed = DisplayConfig.fullscreen
	_syncing = false
	_refresh_info()


func _refresh_info() -> void:
	var win := get_tree().root as Window
	var actual := Vector2i.ZERO
	var scale_size := Vector2i.ZERO
	var factor := 1.0
	if win != null:
		actual = win.size
		scale_size = win.content_scale_size
		factor = win.content_scale_factor
	_info.text = (
		"Saved: %dx%d · UI x%s · fullscreen=%s\n"
		+ "Actual window: %dx%d · stretch base: %dx%d · factor: %s\n"
		+ "Embedded in editor: %s"
	) % [
		DisplayConfig.width, DisplayConfig.height,
		str(DisplayConfig.ui_scale), str(DisplayConfig.fullscreen),
		actual.x, actual.y, scale_size.x, scale_size.y, str(factor),
		str(DisplayConfig.is_embedded()),
	]
	if DisplayConfig.last_apply_message != "":
		_status.text = DisplayConfig.last_apply_message
	if DisplayConfig.last_apply_window_locked or DisplayConfig.is_embedded():
		_status.modulate = Color(1.0, 0.7, 0.3)
	else:
		_status.modulate = Color(0.65, 1.0, 0.7)


func _on_res_selected(index: int) -> void:
	if _syncing:
		return
	if index < 0 or index >= DisplayConfig.PRESETS.size():
		return
	var p: Dictionary = DisplayConfig.PRESETS[index]
	DisplayConfig.set_resolution(int(p["w"]), int(p["h"]))
	# apply() awaits frames; refresh after a short delay.
	await get_tree().create_timer(0.1).timeout
	_refresh_info()


func _on_scale_selected(index: int) -> void:
	if _syncing:
		return
	if index < 0 or index >= DisplayConfig.UI_SCALE_STEPS.size():
		return
	DisplayConfig.set_ui_scale(float(DisplayConfig.UI_SCALE_STEPS[index]))
	await get_tree().create_timer(0.1).timeout
	_refresh_info()


func _on_fullscreen_toggled(pressed: bool) -> void:
	if _syncing:
		return
	DisplayConfig.set_fullscreen(pressed)
	await get_tree().create_timer(0.1).timeout
	_refresh_info()


func _on_apply_clicked() -> void:
	DisplayConfig.apply()
	await get_tree().create_timer(0.1).timeout
	_refresh_info()
