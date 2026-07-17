# GdUnit4 test suite for FPSController (netfox rollback tick version).
# NetworkTime runs during each test; effects land on network ticks, so tests
# await real frames after injecting input.
class_name TestFPSController
extends GdUnitTestSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"

const PITCH_DOWN := -0.8
const PITCH_LEVEL := 0.0


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()


func _spawn_controller() -> GdUnitSceneRunner:
	var runner := scene_runner(CONTROLLER_SCENE)
	return runner


func test_spawns_with_defaults() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	assert_bool(controller.is_gliding).is_false()
	assert_float(controller.walk_speed).is_greater(0.0)
	assert_float(controller.combo_launch_velocity).is_greater(controller.jump_velocity)


func test_moves_forward_on_input() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	var start_z := controller.global_position.z

	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(30)
	runner.simulate_action_release("move_forward")

	assert_float(controller.global_position.z).is_less(start_z - 0.2)


func test_sprint_is_faster_than_walk() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(30)
	var walk_dz := absf(controller.global_position.z)

	controller.global_position = Vector3.ZERO
	controller.velocity = Vector3.ZERO
	runner.simulate_action_press("sprint")
	await runner.simulate_frames(30)
	runner.simulate_action_release("sprint")
	runner.simulate_action_release("move_forward")

	assert_float(absf(controller.global_position.z)).is_greater(walk_dz)


func test_yaw_input_rotates_body() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	controller.input.local_yaw = 0.9
	await runner.simulate_frames(5)

	assert_float(controller.rotation.y).is_equal_approx(0.9, 0.05)
