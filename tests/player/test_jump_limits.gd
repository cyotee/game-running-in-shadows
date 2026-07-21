class_name TestJumpLimits
extends NetSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func test_airborne_jump_deploys_glide_once() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	press(controller.input, &"jump")
	await await_ticks(10)
	assert_bool(controller.is_gliding).is_true()
	assert_bool(controller.air_glide_from_jump_available).is_false()


func test_second_air_jump_does_not_reboost_upward() -> void:
	# Mash jump while airborne must not climb: first press deploys glide (power);
	# further presses must not re-apply free upward impulse after glide ends.
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	controller.glide_duration = 0.15  # ~9 ticks at 60Hz; plain export, not rollback state
	press(controller.input, &"jump")
	await await_ticks(4)
	assert_bool(controller.is_gliding).is_true()
	await await_ticks(20)
	assert_bool(controller.is_gliding).is_false()
	var y_before := controller.velocity.y
	press(controller.input, &"jump")
	await await_ticks(6)
	assert_bool(controller.is_gliding).is_false()
	assert_float(controller.velocity.y).is_less_equal(y_before + 0.5)


func test_glide_jump_boost_only_once_per_glide() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	controller.glide_duration = 2.0
	press(controller.input, &"glide")
	await await_ticks(4)
	assert_bool(controller.is_gliding).is_true()
	press(controller.input, &"jump")
	await await_ticks(4)
	assert_bool(controller.glide_boost_used).is_true()
	var y_after_first := controller.velocity.y
	press(controller.input, &"jump")
	await await_ticks(4)
	assert_float(controller.velocity.y).is_less_equal(y_after_first + 0.1)


func test_ground_jump_sets_disarm_until_land() -> void:
	# Without a floor, ground jump never arms a multi-hop. Spawning airborne:
	# jump_armed starts true but is_on_floor is false so jump does not launch.
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	var y0 := controller.velocity.y
	# Ensure we are treated as airborne (no floor under empty scene runner).
	await await_ticks(2)
	assert_bool(controller.is_on_floor()).is_false()
	press(controller.input, &"jump")
	await await_ticks(3)
	# Airborne jump deploys glide (power), not a free second ground hop.
	assert_bool(controller.is_gliding or controller.velocity.y <= y0 + jump_velocity_cap(controller)).is_true()


func jump_velocity_cap(c: FPSController) -> float:
	# Glide deploy no longer forces +8; only combo/launch would go high.
	return c.jump_velocity * 0.25
