class_name TestBlade
extends NetSuite

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


func _swing(attacker: FPSController) -> void:
	# Let per-test setup (victim orientation via input) propagate through a
	# tick before the strike, or the swing can land in the same batch.
	await await_ticks(2)
	press(attacker.input, &"fire")
	await await_ticks(10)


func test_blade_switches_to_third_person_camera() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	controller.weapon_rig.grant("blade", 1)
	controller.weapon_rig.active_slot = 1
	# Camera swap is frame-driven view logic (_process) — await frames.
	await runner.simulate_frames(10)

	assert_bool(controller.third_person_camera.current).is_true()
	assert_bool(controller.camera.current).is_false()

	select_slot(controller.input, 2)
	await await_ticks(5)
	await runner.simulate_frames(10)
	assert_bool(controller.camera.current).is_true()
	assert_bool(controller.third_person_camera.current).is_false()


func test_local_playtest_body_visible_in_blade_third_person() -> void:
	# Headless PlaytestViz.enabled() is false, so inject the same nodes the
	# runtime setup creates; _process still drives visibility with camera mode.
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	var body := MeshInstance3D.new()
	body.name = "PlaytestBody"
	body.visible = false
	controller.add_child(body)
	var pivot := Node3D.new()
	pivot.name = "PlaytestBladePivot"
	pivot.visible = false
	body.add_child(pivot)
	var stub := MeshInstance3D.new()
	stub.name = "PlaytestViewmodel"
	stub.visible = true
	controller.weapon_rig.add_child(stub)

	controller.weapon_rig.grant("blade", 1)
	controller.weapon_rig.active_slot = 1
	await runner.simulate_frames(10)

	assert_bool(controller.third_person_camera.current).is_true()
	assert_bool(body.visible).is_true()
	assert_bool(pivot.visible).is_true()
	assert_bool(stub.visible).is_false()

	select_slot(controller.input, 2)
	await await_ticks(5)
	await runner.simulate_frames(10)
	assert_bool(controller.camera.current).is_true()
	assert_bool(body.visible).is_false()
	assert_bool(pivot.visible).is_false()
	assert_bool(stub.visible).is_true()


func test_play_blade_swing_fx_moves_pivot_off_rest() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	var body := MeshInstance3D.new()
	body.name = "PlaytestBody"
	controller.add_child(body)
	var pivot := Node3D.new()
	pivot.name = "PlaytestBladePivot"
	pivot.rotation = controller._BLADE_REST_ROT
	body.add_child(pivot)

	controller.play_blade_swing_fx()
	# Immediate windup pose before the tween advances.
	assert_vector(pivot.rotation).is_equal_approx(controller._BLADE_WINDUP_ROT, Vector3(0.001, 0.001, 0.001))
	assert_that(controller._blade_swing_tween).is_not_null()
	assert_bool(controller._blade_swing_tween.is_valid()).is_true()

	# No-op when prop is missing (does not throw).
	var bare: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	add_child(bare)
	bare.play_blade_swing_fx()


func test_frontal_swing_damages_without_bleed() -> void:
	var trio := _blade_duel()
	var runner: GdUnitSceneRunner = trio[0]
	var victim: FPSController = trio[2]
	# Victim faces the attacker (attacker is at +Z of victim): front hit.
	# Orientation goes through input: the victim's own simulation re-derives
	# rotation from aim_yaw every tick.
	victim.input.local_yaw = PI - 0.01
	await _swing(trio[1])

	assert_float(victim._config("max_health") - victim.health).is_equal_approx(25.0, 0.1)
	assert_int(victim.bleed_ticks_remaining).is_equal(0)


func test_backstab_multiplies_and_bleeds() -> void:
	var trio := _blade_duel()
	var runner: GdUnitSceneRunner = trio[0]
	var victim: FPSController = trio[2]
	# Victim faces AWAY from the attacker: backstab (default yaw 0).
	await _swing(trio[1])

	# Bleed starts ticking immediately after the strike (4 HP/s); the awaited
	# frame count varies with load, so allow up to ~1s of bleed on top.
	assert_float(victim._config("max_health") - victim.health).is_between(39.9, 44.5)
	assert_int(victim.bleed_ticks_remaining).is_greater(0)


func test_troll_melee_hits_harder() -> void:
	var trio := _blade_duel()
	var runner: GdUnitSceneRunner = trio[0]
	var attacker: FPSController = trio[1]
	var victim: FPSController = trio[2]
	attacker.archetype = &"troll"
	attacker._apply_archetype_config()
	victim.input.local_yaw = PI - 0.01
	await _swing(attacker)

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
	await await_ticks(5)
	await _swing(trio[1])
	Input.action_release("ads")

	assert_float(victim._config("max_health") - victim.health).is_equal_approx(7.5, 0.1)
