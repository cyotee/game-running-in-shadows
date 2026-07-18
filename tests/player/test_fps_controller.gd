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
	# TickInterpolator blends the displayed transform between ticks, so give
	# the rotation a few extra frames to converge on the target yaw.
	await runner.simulate_frames(15)

	assert_float(controller.rotation.y).is_equal_approx(0.9, 0.05)


func test_glide_without_combo_gives_no_launch() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.input.local_pitch = PITCH_DOWN

	Input.action_press("glide")
	await runner.simulate_frames(3)
	Input.action_release("glide")
	await runner.simulate_frames(5)

	assert_bool(controller.is_gliding).is_true()
	assert_float(controller.velocity.y).is_less(controller.combo_launch_velocity * 0.5)


func test_down_repulse_then_glide_triggers_combo_launch() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.input.local_pitch = PITCH_DOWN

	Input.action_press("repulse")
	await runner.simulate_frames(3)
	Input.action_release("repulse")
	await runner.simulate_frames(3)
	Input.action_press("glide")
	await runner.simulate_frames(3)
	Input.action_release("glide")
	await runner.simulate_frames(2)

	assert_bool(controller.is_gliding).is_true()
	# A few ticks of reduced glide gravity may have shaved a little off.
	assert_float(controller.velocity.y).is_greater(controller.combo_launch_velocity * 0.7)


func test_combo_launch_keeps_glide_active_while_rising() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.input.local_pitch = PITCH_DOWN

	Input.action_press("repulse")
	await runner.simulate_frames(3)
	Input.action_release("repulse")
	await runner.simulate_frames(3)
	Input.action_press("glide")
	await runner.simulate_frames(1)
	Input.action_release("glide")
	await runner.simulate_frames(20)

	# Still rising or floating mid-launch: glide must not self-cancel.
	assert_bool(controller.is_gliding).is_true()


func test_level_repulse_does_not_arm_combo() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.input.local_pitch = PITCH_LEVEL

	Input.action_press("repulse")
	await runner.simulate_frames(3)
	Input.action_release("repulse")
	await runner.simulate_frames(3)
	controller.input.local_pitch = PITCH_DOWN
	Input.action_press("glide")
	await runner.simulate_frames(3)
	Input.action_release("glide")
	await runner.simulate_frames(2)

	assert_bool(controller.is_gliding).is_true()
	assert_float(controller.velocity.y).is_less(controller.combo_launch_velocity * 0.5)


func test_spawns_with_archetype_stats_and_reservation() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	# Human defaults: max 10, harness reservation 2 x 1.0 -> spawn at 8/10.
	assert_float(controller.resonance.max_resonance).is_equal(10.0)
	assert_float(controller.resonance.reserved).is_equal(2.0)
	assert_float(controller.resonance.current).is_equal(8.0)
	assert_float(controller.health).is_equal(100.0)


func test_repulse_spends_resonance() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.input.local_pitch = PITCH_LEVEL

	runner.simulate_action_press("repulse")
	await runner.simulate_frames(5)

	# One cast (cost 2) plus a few ticks of out-of-combat regen drift.
	assert_float(controller.resonance.current).is_equal_approx(6.0, 0.1)


func test_repulse_hard_blocked_when_insufficient() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.resonance.current = 1.0
	var vel_before := controller.velocity

	runner.simulate_action_press("repulse")
	await runner.simulate_frames(5)

	# No spend (hard block); small out-of-combat regen drift allowed.
	assert_float(controller.resonance.current).is_equal_approx(1.0, 0.1)
	# No self-push happened (horizontal only: gravity owns the y axis while
	# the controller free-falls in the scene-runner void).
	var delta_v := controller.velocity - vel_before
	delta_v.y = 0.0
	assert_float(delta_v.length()).is_less(2.0)


func test_elf_archetype_reservation_scaled() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	controller.archetype = &"elf"
	controller._apply_archetype_config()

	# Elf: max 12, harness 2 x 1.5 = 3 reserved -> cap 9.
	assert_float(controller.resonance.reserved).is_equal(3.0)
	assert_float(controller.resonance.cap()).is_equal(9.0)
	assert_float(controller.health).is_equal(78.0)


func test_take_damage_marks_both_combatants_and_gates_regen() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()
	var attacker_runner := _spawn_controller()
	var attacker: FPSController = attacker_runner.scene()

	victim.resonance.drain(4.0)
	attacker.resonance.drain(4.0)
	var tick := NetworkTime.tick
	victim.take_damage(10.0, attacker, tick)

	assert_float(victim.health).is_equal(90.0)
	assert_bool(victim.resonance.is_in_combat(tick + 60)).is_true()
	assert_bool(attacker.resonance.is_in_combat(tick + 60)).is_true()
	# Both regen pools frozen while in combat.
	var v := victim.resonance.current
	victim.resonance.process_tick(1.0, tick + 60)
	assert_float(victim.resonance.current).is_equal(v)


func test_health_floors_at_zero() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	controller.take_damage(9999.0, controller, NetworkTime.tick)
	assert_float(controller.health).is_equal(0.0)


func test_slowdown_scale_set_when_enemy_under_reticle() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	var victim: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	controller.get_parent().add_child(victim)
	victim.position = controller.position + Vector3(0, 0, -5)
	# Aim straight at the victim (spawned facing -Z).
	controller.input.local_pitch = 0.0
	await runner.simulate_frames(5)

	assert_bool(controller.enemy_under_reticle(40.0)).is_true()
	assert_float(controller.input.look_rate_scale).is_equal(0.6)

	# Turn the view away (rollback owns the victim's transform, so move the
	# reticle rather than the victim).
	controller.input.local_yaw = 1.2
	await runner.simulate_frames(10)
	assert_float(controller.input.look_rate_scale).is_equal(1.0)


func test_airborne_jump_deploys_glide() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	# Spawned in empty space, the controller is airborne (falling) from tick 1.
	runner.simulate_action_press("jump")
	await runner.simulate_frames(5)

	assert_bool(controller.is_gliding).is_true()


func test_combo_expires_after_window() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.input.local_pitch = PITCH_DOWN

	Input.action_press("repulse")
	await runner.simulate_frames(3)
	Input.action_release("repulse")
	await runner.simulate_frames(3)
	await await_millis(int(controller.combo_window * 1000) + 300)
	Input.action_press("glide")
	await runner.simulate_frames(3)
	Input.action_release("glide")
	await runner.simulate_frames(2)

	assert_bool(controller.is_gliding).is_true()
	assert_float(controller.velocity.y).is_less(controller.combo_launch_velocity * 0.5)
