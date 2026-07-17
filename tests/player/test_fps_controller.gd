# GdUnit4 test suite for FPSController.
# Uses SceneRunner to drive the controller with simulated input actions.
# Run headless: see docs/TESTING.md
class_name TestFPSController
extends GdUnitTestSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"

# Pitch angles (radians). Combo requires repulse aimed below -0.65
# and glide deployed while still aimed below -0.4.
const PITCH_DOWN := -0.8
const PITCH_LEVEL := 0.0


func _spawn_controller() -> GdUnitSceneRunner:
	var runner := scene_runner(CONTROLLER_SCENE)
	return runner


func test_spawns_with_defaults() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	assert_bool(controller.is_gliding).is_false()
	assert_float(controller.walk_speed).is_greater(0.0)
	assert_float(controller.combo_launch_velocity).is_greater(controller.jump_velocity)


func test_glide_without_combo_gives_no_launch() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.camera.rotation.x = PITCH_DOWN

	runner.simulate_action_press("glide")
	await runner.await_input_processed()

	assert_bool(controller.is_gliding).is_true()
	# Normal deploy caps lift well below the combo launch.
	assert_float(controller.velocity.y).is_less(controller.combo_launch_velocity * 0.5)


func test_down_repulse_then_glide_triggers_combo_launch() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.camera.rotation.x = PITCH_DOWN

	runner.simulate_action_press("repulse")
	await runner.await_input_processed()
	runner.simulate_action_press("glide")
	await runner.await_input_processed()

	assert_bool(controller.is_gliding).is_true()
	# Launch velocity is set on deploy; only input was processed (no physics
	# frames awaited), so gravity has not yet eroded it.
	assert_float(controller.velocity.y)\
		.is_equal_approx(controller.combo_launch_velocity, 1.0)


func test_level_repulse_does_not_arm_combo() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.camera.rotation.x = PITCH_LEVEL

	runner.simulate_action_press("repulse")
	await runner.await_input_processed()

	# Aim down for the glide so only the missing down-repulse breaks the combo.
	controller.camera.rotation.x = PITCH_DOWN
	runner.simulate_action_press("glide")
	await runner.await_input_processed()

	assert_bool(controller.is_gliding).is_true()
	assert_float(controller.velocity.y).is_less(controller.combo_launch_velocity * 0.5)


func test_combo_expires_after_window() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.camera.rotation.x = PITCH_DOWN

	runner.simulate_action_press("repulse")
	await runner.await_input_processed()

	# Wait past the combo window before deploying glide.
	await await_millis(int(controller.combo_window * 1000) + 200)

	runner.simulate_action_press("glide")
	await runner.await_input_processed()

	assert_bool(controller.is_gliding).is_true()
	assert_float(controller.velocity.y).is_less(controller.combo_launch_velocity * 0.5)
