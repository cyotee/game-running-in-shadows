# GdUnit4 test suite for PlayerInput (netfox BaseNetInput).
class_name TestPlayerInput
extends GdUnitTestSuite

var _input: PlayerInput


func before_test() -> void:
	_input = auto_free(PlayerInput.new())
	add_child(_input)
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()


func test_gathers_movement_and_sprint() -> void:
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await await_millis(100)

	assert_float(_input.movement.y).is_less(0.0)
	assert_bool(_input.sprint).is_true()

	Input.action_release("move_forward")
	Input.action_release("sprint")


func test_press_stamps_a_single_tick_and_clears_latch() -> void:
	assert_int(_input.glide_press_tick).is_equal(-1)

	Input.action_press("glide")
	await await_millis(100)
	Input.action_release("glide")

	# The press was stamped with one tick and the pending latch cleared;
	# the stamp stays put (it only matches its own tick in simulation).
	var stamped := _input.glide_press_tick
	assert_int(stamped).is_greater(-1)
	assert_bool(_input._pending_glide).is_false()

	await await_millis(100)
	assert_int(_input.glide_press_tick).is_equal(stamped)


func test_gather_snapshots_local_aim() -> void:
	_input.local_yaw = 1.5
	_input.local_pitch = -0.8
	await await_millis(100)

	assert_float(_input.aim_yaw).is_equal_approx(1.5, 0.001)
	assert_float(_input.aim_pitch).is_equal_approx(-0.8, 0.001)


func test_stick_look_turns_view() -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 1.0
	Input.parse_input_event(motion)
	var start_yaw := _input.local_yaw
	await await_millis(200)

	assert_float(_input.local_yaw).is_not_equal(start_yaw)

	motion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 0.0
	Input.parse_input_event(motion)


func test_stick_deadzone_ignores_drift() -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 0.1  # below 0.15 inner deadzone
	Input.parse_input_event(motion)
	var start_yaw := _input.local_yaw
	await await_millis(200)

	assert_float(_input.local_yaw).is_equal(start_yaw)


func test_swap_weapon_is_edge_latched() -> void:
	Input.action_press("weapon_swap")
	Input.action_release("weapon_swap")
	await await_millis(100)
	assert_bool(_input._pending_swap).is_false()


func test_gathers_weapon_inputs() -> void:
	Input.action_press("fire_primary")
	Input.action_press("ads")
	Input.action_press("weapon_slot_2")
	await await_millis(100)

	assert_bool(_input.fire_held).is_true()
	assert_bool(_input.ads).is_true()

	Input.action_release("fire_primary")
	Input.action_release("ads")
	Input.action_release("weapon_slot_2")
	await await_millis(100)
	assert_bool(_input.fire_held).is_false()
	assert_int(_input.slot_select).is_equal(0)


func test_reload_is_edge_latched() -> void:
	Input.action_press("reload")
	await await_millis(100)
	Input.action_release("reload")
	await await_millis(50)
	assert_bool(_input._pending_reload).is_false()
	assert_int(_input.reload_press_tick).is_greater(-1)
