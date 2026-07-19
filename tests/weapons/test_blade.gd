class_name TestBlade
extends GdUnitTestSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func _blade_duel() -> Array:
	var runner := scene_runner(CONTROLLER_SCENE)
	var attacker: FPSController = runner.scene()
	attacker.weapon_rig.grant("blade", 1)
	attacker.weapon_rig.active_slot = 1
	var victim: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	attacker.get_parent().add_child(victim)
	victim.global_position = attacker.global_position + Vector3(0, 0, -1.5)
	return [runner, attacker, victim]


func _swing(runner: GdUnitSceneRunner) -> void:
	runner.simulate_action_press("fire_primary")
	await runner.simulate_frames(10)
	runner.simulate_action_release("fire_primary")


func test_blade_switches_to_third_person_camera() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	controller.weapon_rig.grant("blade", 1)
	controller.weapon_rig.active_slot = 1
	await runner.simulate_frames(5)

	assert_bool(controller.third_person_camera.current).is_true()
	assert_bool(controller.camera.current).is_false()

	runner.simulate_action_press("weapon_slot_2")
	await runner.simulate_frames(10)
	assert_bool(controller.camera.current).is_true()
	assert_bool(controller.third_person_camera.current).is_false()


func test_frontal_swing_damages_without_bleed() -> void:
	var trio := _blade_duel()
	var runner: GdUnitSceneRunner = trio[0]
	var victim: FPSController = trio[2]
	# Victim faces the attacker (attacker is at +Z of victim): front hit.
	# Orientation goes through input: the victim's own simulation re-derives
	# rotation from aim_yaw every tick.
	victim.input.local_yaw = PI - 0.01
	await _swing(runner)

	assert_float(victim._config("max_health") - victim.health).is_equal_approx(25.0, 0.1)
	assert_int(victim.bleed_ticks_remaining).is_equal(0)


func test_backstab_multiplies_and_bleeds() -> void:
	var trio := _blade_duel()
	var runner: GdUnitSceneRunner = trio[0]
	var victim: FPSController = trio[2]
	# Victim faces AWAY from the attacker: backstab (default yaw 0).
	await _swing(runner)

	# Bleed starts ticking immediately after the strike; allow a few ticks.
	assert_float(victim._config("max_health") - victim.health).is_equal_approx(40.0, 1.5)
	assert_int(victim.bleed_ticks_remaining).is_greater(0)


func test_troll_melee_hits_harder() -> void:
	var trio := _blade_duel()
	var runner: GdUnitSceneRunner = trio[0]
	var attacker: FPSController = trio[1]
	var victim: FPSController = trio[2]
	attacker.archetype = &"troll"
	attacker._apply_archetype_config()
	victim.input.local_yaw = PI - 0.01
	await _swing(runner)

	assert_float(victim._config("max_health") - victim.health).is_equal_approx(35.0, 0.1)


func test_frontal_block_reduces_blade_damage() -> void:
	var trio := _blade_duel()
	var runner: GdUnitSceneRunner = trio[0]
	var victim: FPSController = trio[2]
	victim.input.local_yaw = PI - 0.01
	victim.weapon_rig.grant("blade", 1)
	victim.weapon_rig.active_slot = 1
	# Block via the real input path: both players gather the global ads
	# action; only the victim's matters here.
	Input.action_press("ads")
	await runner.simulate_frames(5)
	await _swing(runner)
	Input.action_release("ads")

	assert_float(victim._config("max_health") - victim.health).is_equal_approx(7.5, 0.1)
