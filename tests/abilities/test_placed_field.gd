class_name TestPlacedField
extends NetSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"
const LIFEBLOOM_SCENE := "res://scenes/abilities/lifebloom.tscn"
const ARENA_SCENE := "res://scenes/levels/test_arena.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func _place(caster: FPSController, caster_peer: int, hp: float, lifetime_ticks: int) -> Lifebloom:
	var field: Lifebloom = (load(LIFEBLOOM_SCENE) as PackedScene).instantiate()
	caster.get_parent().add_child(field)
	field.setup(caster.global_position + Vector3(0.0, 0.0, -1.0), caster_peer, hp, lifetime_ticks)
	return field


func test_field_withers_and_frees_at_lifetime_end() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var field := _place(caster, caster.input.get_multiplayer_authority(), 100.0, 5)

	await await_ticks(10)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(is_instance_valid(field)).is_false()


func test_field_dies_when_caster_absent() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var field := _place(caster, 999999, 100.0, 6000)  # no such caster peer

	await await_ticks(4)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(is_instance_valid(field)).is_false()


func test_lifebloom_heals_player_in_radius() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var victim: FPSController = runner.scene()
	victim.health = 50.0
	var _field := _place(victim, victim.input.get_multiplayer_authority(), 100.0, 6000)

	await await_ticks(30)

	assert_float(victim.health).is_greater(50.0)


func test_take_field_damage_kills_field() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var field := _place(caster, caster.input.get_multiplayer_authority(), 40.0, 6000)

	field.take_field_damage(50.0)
	await await_ticks(4)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(is_instance_valid(field)).is_false()


func test_cast_lifebloom_places_field_and_holds_reservation() -> void:
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var controller: FPSController = runner.scene().get_node("FPSController")
	var reserved_before := controller.resonance.reserved

	press(controller.input, &"lifebloom")
	await await_ticks(8)

	assert_int(controller.get_tree().get_nodes_in_group("lifebloom_fields").size()).is_greater_equal(1)
	assert_bool(controller.lifebloom_reserved).is_true()
	assert_float(controller.resonance.reserved).is_greater(reserved_before)

	# Destroying the field releases the held reservation (empty) after grace.
	var field: PlacedField = controller.get_tree().get_nodes_in_group("lifebloom_fields")[0]
	field.destroy()
	await await_ticks(45)

	assert_bool(controller.lifebloom_reserved).is_false()
	assert_float(controller.resonance.reserved).is_equal(reserved_before)
