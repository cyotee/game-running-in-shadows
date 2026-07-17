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


func test_latches_edge_actions_until_next_tick() -> void:
	Input.action_press("glide")
	Input.action_release("glide")
	await await_millis(100)
	# The press happened between ticks; the latch must have delivered it
	# on exactly one subsequent tick, then cleared.
	assert_bool(_input.glide).is_false()

	Input.action_press("repulse")
	await await_millis(100)
	Input.action_release("repulse")
	assert_bool(_input._pending_repulse).is_false()


func test_gather_snapshots_local_aim() -> void:
	_input.local_yaw = 1.5
	_input.local_pitch = -0.8
	await await_millis(100)

	assert_float(_input.aim_yaw).is_equal_approx(1.5, 0.001)
	assert_float(_input.aim_pitch).is_equal_approx(-0.8, 0.001)
