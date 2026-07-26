# Controls rebind panel: catalog list, multi-bind chips, listen-to-rebind, feel.
# Functional/debug-grade UI. process_mode WHEN_PAUSED so pause menus work.
extends Control

signal closed()

const CATEGORY_LABELS := {
	"movement": "Movement",
	"combat": "Combat",
	"abilities": "Abilities",
	"system": "System",
}

var _category: String = "movement"
var _device_filter: String = "all"  # all | kbm | pad
var _status: String = ""

@onready var _category_bar: HBoxContainer = %CategoryBar
@onready var _device_bar: HBoxContainer = %DeviceBar
@onready var _list: VBoxContainer = %ActionList
@onready var _status_label: Label = %StatusLabel
@onready var _mouse_sens: HSlider = %MouseSensSlider
@onready var _invert_y: CheckBox = %InvertYCheck
@onready var _yaw_slider: HSlider = %YawRateSlider
@onready var _pitch_slider: HSlider = %PitchRateSlider
@onready var _assist_slider: HSlider = %AssistSlider


func _ready() -> void:
	# ALWAYS: works on main menu (unpaused) and under pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_category_buttons()
	_build_device_buttons()
	%ResetButton.pressed.connect(_on_reset)
	%BackButton.pressed.connect(_on_back)
	_mouse_sens.min_value = 0.0005
	_mouse_sens.max_value = 0.01
	_mouse_sens.step = 0.0001
	_yaw_slider.min_value = 60.0
	_yaw_slider.max_value = 480.0
	_yaw_slider.step = 10.0
	_pitch_slider.min_value = 60.0
	_pitch_slider.max_value = 360.0
	_pitch_slider.step = 10.0
	_assist_slider.min_value = 0.2
	_assist_slider.max_value = 1.0
	_assist_slider.step = 0.05
	_sync_feel_controls()
	_mouse_sens.value_changed.connect(func(v: float) -> void:
		InputBindings.set_mouse_sensitivity(v)
		_set_status("Mouse sensitivity %.4f" % v))
	_invert_y.toggled.connect(func(on: bool) -> void:
		InputBindings.set_invert_y(on)
		_set_status("Invert Y: %s" % ("on" if on else "off")))
	_yaw_slider.value_changed.connect(func(v: float) -> void:
		InputBindings.set_stick_pref("look_max_yaw_deg_s", v))
	_pitch_slider.value_changed.connect(func(v: float) -> void:
		InputBindings.set_stick_pref("look_max_pitch_deg_s", v))
	_assist_slider.value_changed.connect(func(v: float) -> void:
		InputBindings.set_stick_pref("slowdown_mult", v))
	InputBindings.binding_changed.connect(func(_a: StringName) -> void:
		_rebuild_list())
	InputBindings.conflict_resolved.connect(func(from_action: StringName, label: String) -> void:
		_set_status("%s unbound from %s" % [label, String(from_action)]))
	InputBindings.listen_started.connect(func(action: StringName) -> void:
		_set_status("Press key, mouse, or controller for %s…" % String(action))
		_rebuild_list())
	InputBindings.listen_finished.connect(func(action: StringName, accepted: bool) -> void:
		if accepted:
			_set_status("Bound %s" % String(action))
		else:
			_set_status("Listen cancelled")
		_rebuild_list())
	_rebuild_list()


func _input(event: InputEvent) -> void:
	if InputBindings.listen_mode == InputBindings.ListenMode.LISTENING:
		if InputBindings.handle_listen_event(event):
			get_viewport().set_input_as_handled()


func open_panel() -> void:
	visible = true
	_sync_feel_controls()
	_rebuild_list()
	_set_status("Select + Add, then press a control to bind")


func _build_category_buttons() -> void:
	for child in _category_bar.get_children():
		child.queue_free()
	for cat in InputBindings.CATEGORY_ORDER:
		var b := Button.new()
		b.text = str(CATEGORY_LABELS.get(cat, cat))
		b.toggle_mode = true
		b.button_pressed = cat == _category
		var c := cat
		b.pressed.connect(func() -> void:
			_category = c
			_rebuild_list()
			_refresh_category_toggles())
		_category_bar.add_child(b)


func _refresh_category_toggles() -> void:
	var i := 0
	for cat in InputBindings.CATEGORY_ORDER:
		if i < _category_bar.get_child_count():
			var b: Button = _category_bar.get_child(i) as Button
			if b:
				b.button_pressed = cat == _category
		i += 1


func _build_device_buttons() -> void:
	for child in _device_bar.get_children():
		child.queue_free()
	var filters: Array[Array] = [
		["all", "All"], ["kbm", "KBM"], ["pad", "Controller"],
	]
	for pair in filters:
		var b := Button.new()
		b.text = str(pair[1])
		b.toggle_mode = true
		b.button_pressed = str(pair[0]) == _device_filter
		var filter_id: String = str(pair[0])
		b.pressed.connect(func() -> void:
			_device_filter = filter_id
			_rebuild_list()
			_refresh_device_toggles())
		_device_bar.add_child(b)


func _refresh_device_toggles() -> void:
	var filters := ["all", "kbm", "pad"]
	for i in filters.size():
		if i < _device_bar.get_child_count():
			var b: Button = _device_bar.get_child(i) as Button
			if b:
				b.button_pressed = filters[i] == _device_filter


func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	var actions: Array = InputBindings.catalog().get(_category, [])
	for action in actions:
		var action_name := str(action)
		if not InputMap.has_action(action_name):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_l := Label.new()
		name_l.text = action_name.replace("_", " ").capitalize()
		name_l.custom_minimum_size = Vector2(160, 0)
		row.add_child(name_l)

		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 4)
		var events := InputMap.action_get_events(action_name)
		for ev in events:
			if not _event_matches_filter(ev):
				continue
			var chip := Button.new()
			chip.text = InputBindings.event_label(ev)
			chip.tooltip_text = "Click to remove"
			var ev_ref: InputEvent = ev
			var act_ref := action_name
			chip.pressed.connect(func() -> void:
				InputBindings.remove_binding(StringName(act_ref), ev_ref)
				_set_status("Removed %s from %s" % [InputBindings.event_label(ev_ref), act_ref])
				_rebuild_list())
			chips.add_child(chip)
		row.add_child(chips)

		var add_btn := Button.new()
		if InputBindings.listen_mode == InputBindings.ListenMode.LISTENING \
				and String(InputBindings.listen_action) == action_name:
			add_btn.text = "…"
			add_btn.disabled = true
		else:
			add_btn.text = "+ Add"
			var act2 := action_name
			add_btn.pressed.connect(func() -> void:
				InputBindings.begin_listen(StringName(act2)))
		row.add_child(add_btn)
		_list.add_child(row)


func _event_matches_filter(ev: InputEvent) -> bool:
	if _device_filter == "all":
		return true
	if _device_filter == "kbm":
		return ev is InputEventKey or ev is InputEventMouseButton
	if _device_filter == "pad":
		return ev is InputEventJoypadButton or ev is InputEventJoypadMotion
	return true


func _sync_feel_controls() -> void:
	_mouse_sens.set_value_no_signal(InputBindings.mouse_sensitivity)
	_invert_y.set_pressed_no_signal(InputBindings.invert_y)
	_yaw_slider.set_value_no_signal(InputBindings.stick_look_max_yaw_deg_s)
	_pitch_slider.set_value_no_signal(InputBindings.stick_look_max_pitch_deg_s)
	_assist_slider.set_value_no_signal(InputBindings.stick_slowdown_mult)


func _set_status(msg: String) -> void:
	_status = msg
	if _status_label:
		_status_label.text = msg


func _on_reset() -> void:
	InputBindings.reset_to_project_defaults()
	_sync_feel_controls()
	_rebuild_list()
	_set_status("Reset to defaults")


func _on_back() -> void:
	InputBindings.cancel_listen()
	visible = false
	closed.emit()
