class_name TestWave3Augments
extends NetSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func test_pulse_sight_reserves_and_expires() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var p: FPSController = runner.scene()
	var before := p.resonance.reserved
	press(p.input, &"pulse_sight")
	await await_ticks(6)
	assert_bool(p.is_pulse_sight_active()).is_true()
	assert_bool(p.pulse_sight_reserved).is_true()
	assert_float(p.resonance.reserved).is_greater(before)
	# Full duration (~5s at 60 tps = 300) + margin.
	await await_ticks(int(roundf(MatchConfig.get_value("pulse_sight.duration_s")
		* NetworkTime.tickrate)) + 10)
	assert_bool(p.is_pulse_sight_active()).is_false()
	assert_bool(p.pulse_sight_reserved).is_false()
	assert_float(p.resonance.reserved).is_equal(before)


func test_pulse_sight_reveals_nearby_enemy() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var p: FPSController = runner.scene()
	var enemy: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	p.get_parent().add_child(enemy)
	enemy.input.set_multiplayer_authority(2)
	enemy.global_position = p.global_position + Vector3(10, 0, 0)
	press(p.input, &"pulse_sight")
	await await_ticks(6)
	var peers := p.pulse_sight_revealed_peers()
	assert_int(peers.size()).is_greater_equal(1)
	assert_bool(peers.has(2)).is_true()


func test_smart_rig_toggles_and_tracks() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var p: FPSController = runner.scene()
	var enemy: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	p.get_parent().add_child(enemy)
	enemy.input.set_multiplayer_authority(2)
	enemy.global_position = p.global_position + Vector3(5, 0, -5)
	p.input.local_yaw = 0.0
	press(p.input, &"smart_rig")
	await await_ticks(8)
	assert_bool(p.smart_rig_active).is_true()
	assert_bool(p.smart_rig_reserved).is_true()
	var yaw0 := p.input.local_yaw
	# Drive several process frames so local view tracking applies.
	for _i in 30:
		await get_tree().process_frame
	assert_float(absf(wrapf(p.input.local_yaw - yaw0, -PI, PI))).is_greater(0.05)
	press(p.input, &"smart_rig")
	await await_ticks(6)
	assert_bool(p.smart_rig_active).is_false()


func test_overclock_active_drains_after_grace() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var p: FPSController = runner.scene()
	var hp0 := p.health
	press(p.input, &"overclock")
	await await_ticks(6)
	assert_bool(p.overclock_active).is_true()
	# During grace (~2s) health should hold.
	var grace := int(roundf(MatchConfig.get_value("overclock.grace_s") * NetworkTime.tickrate))
	await await_ticks(maxi(grace - 5, 1))
	assert_float(p.health).is_equal_approx(hp0, 1.0)
	# After grace, HP drains.
	await await_ticks(grace + 60)
	assert_float(p.health).is_less(hp0 - 1.0)


func test_overclock_boosts_move_mult() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var p: FPSController = runner.scene()
	assert_float(p._overclock_move_mult()).is_equal_approx(1.0, 0.01)
	press(p.input, &"overclock")
	await await_ticks(6)
	assert_float(p._overclock_move_mult()).is_equal_approx(
		MatchConfig.get_value("overclock.active_move_mult"), 0.01)
