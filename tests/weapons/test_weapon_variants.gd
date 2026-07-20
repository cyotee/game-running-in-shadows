class_name TestWeaponVariants
extends NetSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func _spawn_with(key: String) -> Array:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	controller.weapon_rig.grant(key, 1)
	controller.weapon_rig.active_slot = 1
	return [runner, controller]


func test_smg_full_auto_and_bloom() -> void:
	var pair := _spawn_with("smg")
	var runner: GdUnitSceneRunner = pair[0]
	var controller: FPSController = pair[1]
	var smg := controller.weapon_rig.weapon_by_key("smg")

	runner.simulate_action_press("fire_primary")
	await await_ticks(30)
	# Sample bloom mid-burst (it decays fast once firing stops).
	var bloom_mid: float = smg.bloom_deg
	await await_ticks(50)
	runner.simulate_action_release("fire_primary")

	assert_float(smg.mag).is_less(26.0)      # multiple shots from one hold
	assert_float(bloom_mid).is_greater(0.0)


func test_shotgun_multi_pellet_damage() -> void:
	var pair := _spawn_with("shotgun")
	var runner: GdUnitSceneRunner = pair[0]
	var controller: FPSController = pair[1]
	var victim: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	controller.get_parent().add_child(victim)
	victim.global_position = controller.global_position + Vector3(0, 0, -3)

	press(controller.input, &"fire")
	await await_ticks(10)

	var lost: float = victim._config("max_health") - victim.health
	assert_float(lost).is_greater(6.0)
	assert_float(controller.weapon_rig.weapon_by_key("shotgun").mag).is_equal(5.0)


func test_rifle_fires_three_round_burst_per_trigger() -> void:
	var pair := _spawn_with("rifle")
	var runner: GdUnitSceneRunner = pair[0]
	var controller: FPSController = pair[1]
	var rifle := controller.weapon_rig.weapon_by_key("rifle")

	press(controller.input, &"fire")
	await await_ticks(60)  # let the burst play out

	assert_float(rifle.mag).is_equal(21.0)  # exactly 3 rounds


func test_ads_zoom_applies_to_camera() -> void:
	var pair := _spawn_with("rifle")
	var runner: GdUnitSceneRunner = pair[0]
	var controller: FPSController = pair[1]

	runner.simulate_action_press("ads")
	await await_ticks(30)

	assert_float(controller.camera.fov).is_less(60.0)  # zooming toward 75/1.6
	runner.simulate_action_release("ads")


func test_sniper_single_shot_and_bolt_cooldown() -> void:
	var pair := _spawn_with("sniper")
	var runner: GdUnitSceneRunner = pair[0]
	var controller: FPSController = pair[1]
	var victim: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	controller.get_parent().add_child(victim)
	victim.global_position = controller.global_position + Vector3(0, 0, -5)
	# Aim below the victim's head sphere (both eye lines are at +1.6) so the
	# shot lands on the body zone.
	controller.input.local_pitch = -0.1

	press(controller.input, &"fire")
	await await_ticks(3)
	press(controller.input, &"fire")
	await await_ticks(10)   # second trigger within bolt time

	assert_float(victim._config("max_health") - victim.health).is_equal(55.0)
	assert_float(controller.weapon_rig.weapon_by_key("sniper").mag).is_equal(4.0)
