# Local input rebinding + look-feel prefs.
# Autoload singleton name: InputBindings (no class_name — matches DisplayConfig).
# Mutates InputMap events only; never renames actions or touches netfox sim.
# Persists to user://input_bindings.json.
extends Node

const SAVE_PATH := "user://input_bindings.json"
const SCHEMA_VERSION := 1
const AXIS_LISTEN_THRESHOLD := 0.5
const AXIS_RELEASE_THRESHOLD := 0.3

const CATEGORY_ORDER: Array[String] = [
	"movement", "combat", "abilities", "system"
]

const CATALOG_ACTIONS: Dictionary = {
	"movement": [
		"move_forward", "move_backward", "move_left", "move_right",
		"jump", "sprint", "crouch",
	],
	"combat": [
		"fire_primary", "ads", "reload", "weapon_swap",
		"weapon_slot_1", "weapon_slot_2", "grenade", "interact",
	],
	"abilities": [
		"repulse", "glide", "slip", "wraith", "lifebloom", "tangle",
		"null_charge", "reclaim", "familiar", "pulse_sight", "smart_rig",
		"overclock", "ping",
	],
	"system": [
		"menu", "scoreboard", "toggle_mouse",
	],
}

signal listen_started(action: StringName)
signal listen_finished(action: StringName, accepted: bool)
signal binding_changed(action: StringName)
signal conflict_resolved(stolen_from: StringName, event_label: String)
signal feel_changed()

enum ListenMode { IDLE, LISTENING }

var listen_mode: int = ListenMode.IDLE
var listen_action: StringName = &""

var mouse_sensitivity: float = 0.0025
var invert_y: bool = false
var stick_deadzone_inner: float = 0.15
var stick_deadzone_outer: float = 0.98
var stick_look_curve_exponent: float = 2.0
var stick_look_max_yaw_deg_s: float = 240.0
var stick_look_max_pitch_deg_s: float = 180.0
var stick_slowdown_mult: float = 0.6
var stick_slowdown_range_m: float = 40.0

var _factory_actions: Dictionary = {}
var _factory_feel: Dictionary = {}
var _listen_ignore_until_usec: int = 0
var _axis_armed: bool = true


func _ready() -> void:
	_seed_feel_from_match_config()
	_factory_actions = capture_from_input_map()
	_factory_feel = _feel_to_dict()
	load_or_seed()


func catalog() -> Dictionary:
	return CATALOG_ACTIONS.duplicate(true)


func all_catalog_actions() -> Array[String]:
	var out: Array[String] = []
	for cat in CATEGORY_ORDER:
		if not CATALOG_ACTIONS.has(cat):
			continue
		for action in CATALOG_ACTIONS[cat]:
			out.append(str(action))
	return out


func is_catalog_action(action: String) -> bool:
	return action in all_catalog_actions()


func is_hidden_action(action: String) -> bool:
	return action.begins_with("dev_")


func capture_from_input_map() -> Dictionary:
	var actions := {}
	for action in all_catalog_actions():
		if not InputMap.has_action(action):
			continue
		var events: Array = []
		for ev in InputMap.action_get_events(action):
			var d := event_to_dict(ev)
			if not d.is_empty():
				events.append(d)
		actions[action] = events
	return actions


func apply_actions(actions: Dictionary) -> void:
	for action in all_catalog_actions():
		if not actions.has(action):
			continue
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var list: Variant = actions[action]
		if list is Array:
			for item in list:
				if item is Dictionary:
					var ev := dict_to_event(item)
					if ev != null:
						InputMap.action_add_event(action, ev)
	binding_changed.emit(&"")


func load_or_seed() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		_load_from_disk()
	else:
		# Keep project.godot InputMap as-is; only ensure feel defaults.
		pass
	# Always re-apply feel (InputMap already correct if no save).
	feel_changed.emit()


func save() -> void:
	var payload := {
		"version": SCHEMA_VERSION,
		"profile": "default",
		"mouse_sensitivity": mouse_sensitivity,
		"invert_y": invert_y,
		"stick": {
			"deadzone_inner": stick_deadzone_inner,
			"deadzone_outer": stick_deadzone_outer,
			"look_curve_exponent": stick_look_curve_exponent,
			"look_max_yaw_deg_s": stick_look_max_yaw_deg_s,
			"look_max_pitch_deg_s": stick_look_max_pitch_deg_s,
			"slowdown_mult": stick_slowdown_mult,
			"slowdown_range_m": stick_slowdown_range_m,
		},
		"actions": capture_from_input_map(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("InputBindings: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()


func reset_to_project_defaults() -> void:
	apply_actions(_factory_actions.duplicate(true))
	_apply_feel_dict(_factory_feel)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save()
	feel_changed.emit()


func event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var k := event as InputEventKey
		var d := {"type": "key"}
		if k.keycode != KEY_NONE:
			d["keycode"] = int(k.keycode)
		if k.physical_keycode != KEY_NONE:
			d["physical_keycode"] = int(k.physical_keycode)
		return d
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return {"type": "mouse_button", "button": int(mb.button_index)}
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		return {"type": "joy_button", "button": int(jb.button_index)}
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		return {
			"type": "joy_motion",
			"axis": int(jm.axis),
			"axis_value": jm.axis_value,
		}
	return {}


func dict_to_event(data: Dictionary) -> InputEvent:
	var t: String = str(data.get("type", ""))
	match t:
		"key":
			var k := InputEventKey.new()
			if data.has("keycode"):
				k.keycode = int(data["keycode"]) as Key
			if data.has("physical_keycode"):
				k.physical_keycode = int(data["physical_keycode"]) as Key
			return k
		"mouse_button":
			var mb := InputEventMouseButton.new()
			mb.button_index = int(data.get("button", 1)) as MouseButton
			return mb
		"joy_button":
			var jb := InputEventJoypadButton.new()
			jb.button_index = int(data.get("button", 0)) as JoyButton
			return jb
		"joy_motion":
			var jm := InputEventJoypadMotion.new()
			jm.axis = int(data.get("axis", 0)) as JoyAxis
			jm.axis_value = float(data.get("axis_value", 1.0))
			return jm
	return null


func events_equivalent(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	var da := event_to_dict(a)
	var db := event_to_dict(b)
	if da.is_empty() or db.is_empty():
		return false
	if da.get("type") != db.get("type"):
		return false
	match str(da["type"]):
		"key":
			# Match if either keycode or physical matches the other.
			var ka := int(da.get("keycode", 0))
			var kb := int(db.get("keycode", 0))
			var pa := int(da.get("physical_keycode", 0))
			var pb := int(db.get("physical_keycode", 0))
			if ka != 0 and kb != 0 and ka == kb:
				return true
			if pa != 0 and pb != 0 and pa == pb:
				return true
			if ka != 0 and pb != 0 and ka == pb:
				return true
			if pa != 0 and kb != 0 and pa == kb:
				return true
			return false
		"mouse_button":
			return int(da.get("button", -1)) == int(db.get("button", -2))
		"joy_button":
			return int(da.get("button", -1)) == int(db.get("button", -2))
		"joy_motion":
			return int(da.get("axis", -1)) == int(db.get("axis", -2)) \
				and signf(float(da.get("axis_value", 0.0))) \
					== signf(float(db.get("axis_value", 0.0)))
	return false


func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var k := event as InputEventKey
		var code: Key = k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		if code == KEY_NONE:
			return "Key?"
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel+"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel-"
			_:
				return "Mouse%d" % int(mb.button_index)
	if event is InputEventJoypadButton:
		return _joy_button_label(int((event as InputEventJoypadButton).button_index))
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		return _joy_axis_label(int(jm.axis), jm.axis_value)
	return "?"


func action_label(action: StringName) -> String:
	var name_str := String(action)
	if not InputMap.has_action(name_str):
		return ""
	var parts: PackedStringArray = []
	for ev in InputMap.action_get_events(name_str):
		parts.append(event_label(ev))
	return " · ".join(parts)


func begin_listen(action: StringName) -> void:
	var a := String(action)
	if not is_catalog_action(a):
		return
	listen_mode = ListenMode.LISTENING
	listen_action = action
	_axis_armed = true
	# Ignore the activating click for a short window.
	_listen_ignore_until_usec = Time.get_ticks_usec() + 150_000
	listen_started.emit(action)


func cancel_listen() -> void:
	if listen_mode != ListenMode.LISTENING:
		return
	var a := listen_action
	listen_mode = ListenMode.IDLE
	listen_action = &""
	listen_finished.emit(a, false)


## Process an input while listening. Returns true if consumed.
func handle_listen_event(event: InputEvent) -> bool:
	if listen_mode != ListenMode.LISTENING:
		return false
	if Time.get_ticks_usec() < _listen_ignore_until_usec:
		# Still swallow the activating mouse click.
		if event is InputEventMouseButton:
			return true
		return false

	# Cancel without binding.
	if event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and not event.echo \
				and (event as InputEventKey).keycode == KEY_ESCAPE):
		cancel_listen()
		return true

	if not _is_eligible_listen_event(event):
		return false

	var target := listen_action
	add_binding(target, event)
	listen_mode = ListenMode.IDLE
	listen_action = &""
	listen_finished.emit(target, true)
	return true


func add_binding(action: StringName, event: InputEvent) -> void:
	var a := String(action)
	if not is_catalog_action(a) or not InputMap.has_action(a) or event == null:
		return
	# Duplicate on same action → no-op.
	for existing in InputMap.action_get_events(a):
		if events_equivalent(existing, event):
			return
	# Steal from other catalog actions.
	for other in all_catalog_actions():
		if other == a or not InputMap.has_action(other):
			continue
		var to_remove: Array[InputEvent] = []
		for existing in InputMap.action_get_events(other):
			if events_equivalent(existing, event):
				to_remove.append(existing)
		for rem in to_remove:
			InputMap.action_erase_event(other, rem)
			conflict_resolved.emit(StringName(other), event_label(event))
			binding_changed.emit(StringName(other))
	InputMap.action_add_event(a, event.duplicate() if event.has_method("duplicate") else event)
	# duplicate() exists on Resource; InputEvent extends Resource.
	binding_changed.emit(action)
	save()


func remove_binding(action: StringName, event: InputEvent) -> void:
	var a := String(action)
	if not InputMap.has_action(a) or event == null:
		return
	for existing in InputMap.action_get_events(a):
		if events_equivalent(existing, event):
			InputMap.action_erase_event(a, existing)
			binding_changed.emit(action)
			save()
			return


func set_bindings(action: StringName, events: Array) -> void:
	var a := String(action)
	if not is_catalog_action(a) or not InputMap.has_action(a):
		return
	InputMap.action_erase_events(a)
	for item in events:
		var ev: InputEvent = null
		if item is InputEvent:
			ev = item
		elif item is Dictionary:
			ev = dict_to_event(item)
		if ev != null:
			InputMap.action_add_event(a, ev)
	binding_changed.emit(action)
	save()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0001, 0.05)
	feel_changed.emit()
	save()


func set_invert_y(value: bool) -> void:
	invert_y = value
	feel_changed.emit()
	save()


func set_stick_pref(key: String, value: float) -> void:
	match key:
		"deadzone_inner":
			stick_deadzone_inner = clampf(value, 0.0, 0.5)
		"deadzone_outer":
			stick_deadzone_outer = clampf(value, 0.5, 1.0)
		"look_curve_exponent":
			stick_look_curve_exponent = clampf(value, 0.5, 4.0)
		"look_max_yaw_deg_s":
			stick_look_max_yaw_deg_s = clampf(value, 30.0, 720.0)
		"look_max_pitch_deg_s":
			stick_look_max_pitch_deg_s = clampf(value, 30.0, 720.0)
		"slowdown_mult":
			stick_slowdown_mult = clampf(value, 0.1, 1.0)
		"slowdown_range_m":
			stick_slowdown_range_m = clampf(value, 5.0, 200.0)
		_:
			return
	feel_changed.emit()
	save()


func _seed_feel_from_match_config() -> void:
	if Engine.has_singleton("MatchConfig") or true:
		# MatchConfig is an autoload Node, not Engine singleton — read if available.
		pass
	var mc := get_node_or_null("/root/MatchConfig")
	if mc != null and mc.has_method("get_value"):
		stick_deadzone_inner = float(mc.get_value("input.stick_deadzone_inner"))
		stick_deadzone_outer = float(mc.get_value("input.stick_deadzone_outer"))
		stick_look_curve_exponent = float(mc.get_value("input.look_curve_exponent"))
		stick_look_max_yaw_deg_s = float(mc.get_value("input.look_max_yaw_deg_s"))
		stick_look_max_pitch_deg_s = float(mc.get_value("input.look_max_pitch_deg_s"))
		stick_slowdown_mult = float(mc.get_value("input.slowdown_mult"))
		stick_slowdown_range_m = float(mc.get_value("input.slowdown_range_m"))


func _feel_to_dict() -> Dictionary:
	return {
		"mouse_sensitivity": mouse_sensitivity,
		"invert_y": invert_y,
		"stick_deadzone_inner": stick_deadzone_inner,
		"stick_deadzone_outer": stick_deadzone_outer,
		"stick_look_curve_exponent": stick_look_curve_exponent,
		"stick_look_max_yaw_deg_s": stick_look_max_yaw_deg_s,
		"stick_look_max_pitch_deg_s": stick_look_max_pitch_deg_s,
		"stick_slowdown_mult": stick_slowdown_mult,
		"stick_slowdown_range_m": stick_slowdown_range_m,
	}


func _apply_feel_dict(d: Dictionary) -> void:
	mouse_sensitivity = float(d.get("mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(d.get("invert_y", invert_y))
	stick_deadzone_inner = float(d.get("stick_deadzone_inner", stick_deadzone_inner))
	stick_deadzone_outer = float(d.get("stick_deadzone_outer", stick_deadzone_outer))
	stick_look_curve_exponent = float(d.get("stick_look_curve_exponent", stick_look_curve_exponent))
	stick_look_max_yaw_deg_s = float(d.get("stick_look_max_yaw_deg_s", stick_look_max_yaw_deg_s))
	stick_look_max_pitch_deg_s = float(d.get("stick_look_max_pitch_deg_s", stick_look_max_pitch_deg_s))
	stick_slowdown_mult = float(d.get("stick_slowdown_mult", stick_slowdown_mult))
	stick_slowdown_range_m = float(d.get("stick_slowdown_range_m", stick_slowdown_range_m))


func _load_from_disk() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("InputBindings: cannot read %s" % SAVE_PATH)
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("InputBindings: invalid JSON at %s" % SAVE_PATH)
		return
	var data: Dictionary = parsed
	mouse_sensitivity = float(data.get("mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(data.get("invert_y", invert_y))
	var stick: Variant = data.get("stick", {})
	if stick is Dictionary:
		var s: Dictionary = stick
		stick_deadzone_inner = float(s.get("deadzone_inner", stick_deadzone_inner))
		stick_deadzone_outer = float(s.get("deadzone_outer", stick_deadzone_outer))
		stick_look_curve_exponent = float(s.get("look_curve_exponent", stick_look_curve_exponent))
		stick_look_max_yaw_deg_s = float(s.get("look_max_yaw_deg_s", stick_look_max_yaw_deg_s))
		stick_look_max_pitch_deg_s = float(s.get("look_max_pitch_deg_s", stick_look_max_pitch_deg_s))
		stick_slowdown_mult = float(s.get("slowdown_mult", stick_slowdown_mult))
		stick_slowdown_range_m = float(s.get("slowdown_range_m", stick_slowdown_range_m))
	var actions: Variant = data.get("actions", {})
	if actions is Dictionary:
		var filtered := {}
		for key in actions.keys():
			var k := str(key)
			if is_catalog_action(k):
				filtered[k] = actions[key]
			elif is_hidden_action(k):
				pass
			else:
				push_warning("InputBindings: ignoring unknown action '%s'" % k)
		if not filtered.is_empty():
			# Merge: only override actions present in file; keep factory for missing.
			var merged := _factory_actions.duplicate(true)
			for k2 in filtered.keys():
				merged[k2] = filtered[k2]
			apply_actions(merged)


func _is_eligible_listen_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var k := event as InputEventKey
		return k.pressed and not k.echo
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		return jb.pressed
	if event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		var mag := absf(jm.axis_value)
		if mag < AXIS_LISTEN_THRESHOLD:
			if mag < AXIS_RELEASE_THRESHOLD:
				_axis_armed = true
			return false
		if not _axis_armed:
			return false
		_axis_armed = false
		return true
	return false


func _joy_button_label(button: int) -> String:
	match button:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_BACK:
			return "Select"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_DPAD_UP:
			return "D-Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-Right"
		_:
			return "Btn%d" % button


func _joy_axis_label(axis: int, value: float) -> String:
	var sign_s := "+" if value >= 0.0 else "-"
	match axis:
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
		JOY_AXIS_LEFT_X:
			return "LS X%s" % sign_s
		JOY_AXIS_LEFT_Y:
			return "LS Y%s" % sign_s
		JOY_AXIS_RIGHT_X:
			return "RS X%s" % sign_s
		JOY_AXIS_RIGHT_Y:
			return "RS Y%s" % sign_s
		_:
			return "Axis%d%s" % [axis, sign_s]
