class_name TestWeaponRig
extends GdUnitTestSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func test_spawns_with_default_loadout() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	var rig: WeaponRig = controller.weapon_rig

	assert_str(rig.slot1).is_equal("rifle")
	assert_str(rig.slot2).is_equal("pistol")
	assert_int(rig.active_slot).is_equal(1)
	assert_float(rig.weapon_by_key("pistol").mag).is_equal(12.0)
	assert_float(rig.weapon_by_key("rifle").reserve).is_equal(72.0)


func test_slot_switch_via_input() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()

	runner.simulate_action_press("weapon_slot_2")
	await runner.simulate_frames(10)

	assert_int(controller.weapon_rig.active_slot).is_equal(2)
	assert_str(controller.weapon_rig.active_weapon().weapon_key).is_equal("pistol")


func test_carry_weight_slows_elf() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	controller.archetype = &"elf"
	controller._apply_archetype_config()
	controller.weapon_rig.grant("sniper", 1)  # heavy

	assert_float(controller.weapon_rig.carry_weight_mult()).is_equal(0.65)


func test_clear_key_frees_slot_for_replacement() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	var rig: WeaponRig = controller.weapon_rig
	assert_str(rig.slot1).is_equal("rifle")
	rig.clear_key("rifle")
	assert_str(rig.slot1).is_equal("")
	assert_int(rig.active_slot).is_equal(2)  # fell back to pistol
	rig.grant("smg", 1)
	assert_str(rig.slot1).is_equal("smg")
