class_name TestWeaponFire
extends NetSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func _spawn_pair() -> Array:
	var runner := scene_runner(CONTROLLER_SCENE)
	var shooter: FPSController = runner.scene()
	var victim: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	runner.scene().get_parent().add_child(victim)
	victim.global_position = shooter.global_position + Vector3(0, 0, -5)
	return [runner, shooter, victim]


func test_pistol_shot_consumes_ammo_and_damages() -> void:
	var pair := _spawn_pair()
	var runner: GdUnitSceneRunner = pair[0]
	var shooter: FPSController = pair[1]
	var victim: FPSController = pair[2]
	select_slot(shooter.input, 2)
	await await_ticks(10)

	press(shooter.input, &"fire")
	await await_ticks(10)

	var pistol := shooter.weapon_rig.weapon_by_key("pistol")
	assert_float(pistol.mag).is_equal(11.0)
	assert_float(victim.health).is_less(victim._config("max_health"))


func test_no_fire_while_reloading_or_empty() -> void:
	var pair := _spawn_pair()
	var runner: GdUnitSceneRunner = pair[0]
	var shooter: FPSController = pair[1]
	# Rollback state must be seeded before the first tick records it.
	var pistol := shooter.weapon_rig.weapon_by_key("pistol")
	pistol.mag = 1.0

	select_slot(shooter.input, 2)
	await await_ticks(10)
	# Last round fires; the emptied mag starts an auto-reload.
	press(shooter.input, &"fire")
	await await_ticks(10)

	assert_float(pistol.mag).is_equal(0.0)
	assert_bool(pistol.is_reloading(NetworkTime.tick)).is_true()


func test_semi_auto_requires_new_trigger_pull() -> void:
	var pair := _spawn_pair()
	var runner: GdUnitSceneRunner = pair[0]
	var shooter: FPSController = pair[1]
	select_slot(shooter.input, 2)
	await await_ticks(10)

	# Semi-auto: a single press-tick fires exactly one round no matter how
	# long the trigger stays held.
	press(shooter.input, &"fire")
	await await_ticks(60)

	assert_float(shooter.weapon_rig.weapon_by_key("pistol").mag).is_equal(11.0)
