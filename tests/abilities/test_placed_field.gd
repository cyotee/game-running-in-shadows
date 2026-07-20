class_name TestPlacedField
extends NetSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"
const LIFEBLOOM_SCENE := "res://scenes/abilities/lifebloom.tscn"
const TANGLE_SCENE := "res://scenes/abilities/tangle.tscn"
const NULL_SCENE := "res://scenes/abilities/null_charge.tscn"
const ARENA_SCENE := "res://scenes/levels/test_arena.tscn"


func _add_enemy_caster(near: FPSController, peer: int) -> FPSController:
	# A living player under a distinct peer, so PlacedField._caster_gone is
	# false and the field is an "enemy" field for `near`.
	var caster: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	near.get_parent().add_child(caster)
	caster.input.set_multiplayer_authority(peer)
	caster.global_position = near.global_position + Vector3(30.0, 0.0, 0.0)
	return caster


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


func test_tangle_drags_enemy_toward_center() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var victim: FPSController = runner.scene()
	_add_enemy_caster(victim, 2)
	var field: Tangle = (load(TANGLE_SCENE) as PackedScene).instantiate()
	victim.get_parent().add_child(field)
	field.setup(victim.global_position + Vector3(3.0, 0.0, 0.0), 2, 200.0, 6000)

	var x0 := victim.global_position.x
	await await_ticks(20)

	# Pulled toward the field at +X.
	assert_float(victim.global_position.x).is_greater(x0 + 0.5)


func test_tangle_does_not_pull_its_own_caster() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()  # peer 1
	var field: Tangle = (load(TANGLE_SCENE) as PackedScene).instantiate()
	caster.get_parent().add_child(field)
	field.setup(caster.global_position + Vector3(3.0, 0.0, 0.0), 1, 200.0, 6000)

	var x0 := caster.global_position.x
	await await_ticks(20)

	# Caster is exempt from their own Tangle: no inward drift.
	assert_float(absf(caster.global_position.x - x0)).is_less(0.5)


func test_tangle_blocks_direct_fire() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var shooter: FPSController = runner.scene()
	shooter.weapon_rig.active_slot = 2  # pistol
	var victim: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	shooter.get_parent().add_child(victim)
	victim.global_position = shooter.global_position + Vector3(0.0, 0.0, -8.0)
	# Tangle vortex between shooter and victim, far enough that the shooter's
	# camera is outside the block sphere (a ray from inside reports no hit).
	var field: Tangle = (load(TANGLE_SCENE) as PackedScene).instantiate()
	shooter.get_parent().add_child(field)
	field.setup(shooter.global_position + Vector3(0.0, 0.0, -4.5), 1, 200.0, 6000)
	await await_ticks(3)  # let the block collider settle

	var hp := victim.health
	press(shooter.input, &"fire")
	await await_ticks(8)

	assert_float(victim.health).is_equal(hp)  # ray blocked by the vortex


func test_null_drains_nearby_enemy_resonance() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var victim: FPSController = runner.scene()
	_add_enemy_caster(victim, 2)
	var field: NullCharge = (load(NULL_SCENE) as PackedScene).instantiate()
	victim.get_parent().add_child(field)
	field.setup(victim.global_position, 2, 200.0, 6000)  # enemy null on the victim

	var res0 := victim.resonance.current
	await await_ticks(30)

	assert_float(victim.resonance.current).is_less(res0)


func test_null_field_suppresses_casting() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	_add_enemy_caster(controller, 2)
	var field: NullCharge = (load(NULL_SCENE) as PackedScene).instantiate()
	controller.get_parent().add_child(field)
	field.setup(controller.global_position, 2, 200.0, 6000)
	await await_ticks(3)

	var denials: Array = []
	controller.cast_denied.connect(func() -> void: denials.append(true))
	var res_before := controller.resonance.current
	press(controller.input, &"repulse")
	await await_ticks(6)

	# Cast suppressed inside the Null field: denial, and no 2-Resonance spend
	# (only the ~1/s Null drain reduces the pool).
	assert_array(denials).has_size(1)
	assert_float(res_before - controller.resonance.current).is_less(1.0)


func test_null_destroys_lifebloom_inside() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var peer := caster.input.get_multiplayer_authority()
	var life: Lifebloom = (load(LIFEBLOOM_SCENE) as PackedScene).instantiate()
	caster.get_parent().add_child(life)
	life.setup(caster.global_position + Vector3(0.0, 0.0, -2.0), peer, 200.0, 6000)
	var nullf: NullCharge = (load(NULL_SCENE) as PackedScene).instantiate()
	caster.get_parent().add_child(nullf)
	nullf.setup(caster.global_position + Vector3(0.0, 0.0, -2.0), peer, 200.0, 6000)

	await await_ticks(4)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(is_instance_valid(life)).is_false()


func test_null_cast_consumes_stock() -> void:
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var controller: FPSController = runner.scene().get_node("FPSController")
	var stock0 := controller.null_stock

	press(controller.input, &"null_charge")
	await await_ticks(8)

	assert_int(controller.null_stock).is_equal(stock0 - 1)
	assert_int(controller.get_tree().get_nodes_in_group("null_fields").size()).is_greater_equal(1)


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
