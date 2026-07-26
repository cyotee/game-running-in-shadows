class_name TestInputBindings
extends GdUnitTestSuite

const SAVE_PATH := "user://input_bindings.json"
const BACKUP_PATH := "user://input_bindings.backup_test.json"

var _snapshot: Dictionary = {}


func before_test() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var src := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var dst := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		DirAccess.remove_absolute(SAVE_PATH)
	_snapshot = InputBindings.capture_from_input_map()
	InputBindings.cancel_listen()
	InputBindings.mouse_sensitivity = 0.0025
	InputBindings.invert_y = false


func after_test() -> void:
	InputBindings.cancel_listen()
	InputBindings.apply_actions(_snapshot)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		var src := FileAccess.open(BACKUP_PATH, FileAccess.READ)
		var dst := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		DirAccess.remove_absolute(BACKUP_PATH)


func test_catalog_hides_dev_actions() -> void:
	var cat: Dictionary = InputBindings.catalog()
	var all: Array[String] = InputBindings.all_catalog_actions()
	assert_int(all.size()).is_greater(10)
	assert_bool(InputBindings.is_catalog_action("repulse")).is_true()
	assert_bool(InputBindings.is_catalog_action("dev_promote")).is_false()
	assert_bool(InputBindings.is_hidden_action("dev_promote")).is_true()
	for action in all:
		assert_bool(str(action).begins_with("dev_")).is_false()
	assert_that(cat.has("movement")).is_true()
	assert_that(cat.has("abilities")).is_true()


func test_event_encode_decode_key_roundtrip() -> void:
	var k := InputEventKey.new()
	k.keycode = KEY_E
	k.physical_keycode = KEY_E
	var d := InputBindings.event_to_dict(k)
	assert_str(str(d.get("type"))).is_equal("key")
	var back := InputBindings.dict_to_event(d)
	assert_that(back).is_not_null()
	assert_bool(InputBindings.events_equivalent(k, back)).is_true()


func test_event_encode_decode_mouse_and_joy() -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	var mb2 := InputBindings.dict_to_event(InputBindings.event_to_dict(mb))
	assert_bool(InputBindings.events_equivalent(mb, mb2)).is_true()

	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	var jb2 := InputBindings.dict_to_event(InputBindings.event_to_dict(jb))
	assert_bool(InputBindings.events_equivalent(jb, jb2)).is_true()

	var jm := InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_TRIGGER_RIGHT
	jm.axis_value = 1.0
	var jm2 := InputBindings.dict_to_event(InputBindings.event_to_dict(jm))
	assert_bool(InputBindings.events_equivalent(jm, jm2)).is_true()


func test_apply_and_capture_roundtrip() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.physical_keycode = KEY_F
	InputBindings.set_bindings(&"repulse", [key])
	var cap: Dictionary = InputBindings.capture_from_input_map()
	assert_that(cap.has("repulse")).is_true()
	var events: Array = cap["repulse"]
	assert_int(events.size()).is_equal(1)
	var restored := InputBindings.dict_to_event(events[0])
	assert_bool(InputBindings.events_equivalent(key, restored)).is_true()


func test_multi_bind_kbm_and_pad_on_same_action() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_SHOULDER
	InputBindings.set_bindings(&"repulse", [])
	InputBindings.add_binding(&"repulse", key)
	InputBindings.add_binding(&"repulse", pad)
	var events := InputMap.action_get_events("repulse")
	assert_int(events.size()).is_equal(2)
	var has_key := false
	var has_pad := false
	for ev in events:
		if InputBindings.events_equivalent(ev, key):
			has_key = true
		if InputBindings.events_equivalent(ev, pad):
			has_pad = true
	assert_bool(has_key).is_true()
	assert_bool(has_pad).is_true()


func test_add_binding_steals_from_other_action() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_F9
	key.physical_keycode = KEY_F9
	InputBindings.set_bindings(&"repulse", [key])
	InputBindings.set_bindings(&"glide", [])
	InputBindings.add_binding(&"glide", key)
	# glide has it
	var on_glide := false
	for ev in InputMap.action_get_events("glide"):
		if InputBindings.events_equivalent(ev, key):
			on_glide = true
	assert_bool(on_glide).is_true()
	# repulse lost it
	for ev2 in InputMap.action_get_events("repulse"):
		assert_bool(InputBindings.events_equivalent(ev2, key)).is_false()


func test_duplicate_binding_is_noop() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_F8
	key.physical_keycode = KEY_F8
	InputBindings.set_bindings(&"ping", [key])
	InputBindings.add_binding(&"ping", key)
	assert_int(InputMap.action_get_events("ping").size()).is_equal(1)


func test_listen_accepts_key_and_cancel() -> void:
	InputBindings.set_bindings(&"repulse", [])
	InputBindings.begin_listen(&"repulse")
	assert_int(InputBindings.listen_mode).is_equal(InputBindings.ListenMode.LISTENING)
	# Force ignore window expired.
	InputBindings._listen_ignore_until_usec = 0

	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	assert_bool(InputBindings.handle_listen_event(cancel)).is_true()
	assert_int(InputBindings.listen_mode).is_equal(InputBindings.ListenMode.IDLE)
	assert_int(InputMap.action_get_events("repulse").size()).is_equal(0)

	InputBindings.begin_listen(&"repulse")
	InputBindings._listen_ignore_until_usec = 0
	var key := InputEventKey.new()
	key.keycode = KEY_F7
	key.physical_keycode = KEY_F7
	key.pressed = true
	assert_bool(InputBindings.handle_listen_event(key)).is_true()
	assert_int(InputBindings.listen_mode).is_equal(InputBindings.ListenMode.IDLE)
	var found := false
	for ev in InputMap.action_get_events("repulse"):
		if InputBindings.events_equivalent(ev, key):
			found = true
	assert_bool(found).is_true()


func test_listen_ignores_low_axis() -> void:
	InputBindings.begin_listen(&"fire_primary")
	InputBindings._listen_ignore_until_usec = 0
	var jm := InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_TRIGGER_RIGHT
	jm.axis_value = 0.2
	assert_bool(InputBindings.handle_listen_event(jm)).is_false()
	assert_int(InputBindings.listen_mode).is_equal(InputBindings.ListenMode.LISTENING)
	InputBindings.cancel_listen()


func test_listen_accepts_trigger_axis() -> void:
	InputBindings.set_bindings(&"ads", [])
	InputBindings.begin_listen(&"ads")
	InputBindings._listen_ignore_until_usec = 0
	InputBindings._axis_armed = true
	var jm := InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_TRIGGER_LEFT
	jm.axis_value = 1.0
	assert_bool(InputBindings.handle_listen_event(jm)).is_true()
	assert_int(InputMap.action_get_events("ads").size()).is_equal(1)


func test_save_load_roundtrip() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_F6
	key.physical_keycode = KEY_F6
	InputBindings.set_bindings(&"tangle", [key])
	InputBindings.mouse_sensitivity = 0.0033
	InputBindings.invert_y = true
	InputBindings.save()

	# Mutate runtime state without writing (would clobber the save).
	InputMap.action_erase_events("tangle")
	InputBindings.mouse_sensitivity = 0.0025
	InputBindings.invert_y = false
	InputBindings.load_or_seed()

	assert_float(InputBindings.mouse_sensitivity).is_equal_approx(0.0033, 0.00001)
	assert_bool(InputBindings.invert_y).is_true()
	var found := false
	for ev in InputMap.action_get_events("tangle"):
		if InputBindings.events_equivalent(ev, key):
			found = true
	assert_bool(found).is_true()


func test_reset_restores_factory_snapshot() -> void:
	var factory_repulse: Array = InputBindings._factory_actions.get("repulse", [])
	var key := InputEventKey.new()
	key.keycode = KEY_F5
	key.physical_keycode = KEY_F5
	InputBindings.set_bindings(&"repulse", [key])
	InputBindings.mouse_sensitivity = 0.009
	InputBindings.reset_to_project_defaults()
	var captured: Dictionary = InputBindings.capture_from_input_map()
	assert_that(captured.get("repulse")).is_equal(factory_repulse)
	assert_float(InputBindings.mouse_sensitivity).is_equal_approx(
		float(InputBindings._factory_feel.get("mouse_sensitivity", 0.0025)), 0.00001)


func test_event_and_action_labels() -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	assert_str(InputBindings.event_label(mb)).is_equal("LMB")
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	assert_str(InputBindings.event_label(jb)).is_equal("A")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	InputBindings.set_bindings(&"repulse", [key])
	var label := InputBindings.action_label(&"repulse")
	assert_str(label).is_not_empty()


func test_remove_binding() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_F4
	key.physical_keycode = KEY_F4
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	InputBindings.set_bindings(&"reload", [key, pad])
	InputBindings.remove_binding(&"reload", key)
	assert_int(InputMap.action_get_events("reload").size()).is_equal(1)
	assert_bool(InputBindings.events_equivalent(
		InputMap.action_get_events("reload")[0], pad)).is_true()
