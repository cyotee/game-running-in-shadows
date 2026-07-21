class_name TestReclaim
extends NetSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"
const CORPSE_SCENE := "res://scenes/abilities/corpse.tscn"

# In these offline tests only the runner's authority-1 controller is simulated
# (netfox gives `is_fresh` ticks to the local-authority node only — verified).
# So each test makes the entity-under-test the runner scene, and any other
# controller a STATIC prop whose forced state persists (it is never simulated).


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()
	for node in get_tree().get_nodes_in_group("corpses"):
		node.free()


func _static_dead_ally(host: FPSController, offset: Vector3, peer: int) -> FPSController:
	var ally: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	host.get_parent().add_child(ally)
	ally.input.set_multiplayer_authority(peer)
	ally.global_position = host.global_position + offset
	ally.is_dead = true  # static prop: not simulated, so the forced write persists
	return ally


func _corpse_at(host: FPSController, offset: Vector3, owner_peer: int) -> Corpse:
	var corpse: Corpse = (load(CORPSE_SCENE) as PackedScene).instantiate()
	host.get_parent().add_child(corpse)
	corpse.init(host.global_position + offset, owner_peer, 0,
		["smg", 10.0, 30.0, "", 0.0, 0.0, 1])
	return corpse


# --- Caster side (deny) ---

func test_reclaim_denied_with_no_corpse() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var before := caster.resonance.reserved
	press(caster.input, &"reclaim")
	await await_ticks(6)
	assert_bool(caster.reclaim_reserved).is_false()
	assert_float(caster.resonance.reserved).is_equal(before)


# --- Ally side (revive applied in the revived player's own tick) ---

func test_reclaim_revives_ally_at_half_health_with_gear() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var ally: FPSController = runner.scene()
	# An alive reviver (authority 2) so the revived ally does not bleed out.
	var reviver: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	ally.get_parent().add_child(reviver)
	reviver.input.set_multiplayer_authority(2)
	ally.queue_damage(9999.0)
	await await_ticks(6)
	assert_bool(ally.is_dead).is_true()

	ally.queue_reclaim_revive(ally.global_position, 2,
		["smg", 10.0, 30.0, "", 0.0, 0.0, 1])
	await await_ticks(6)

	assert_bool(ally.is_dead).is_false()
	assert_float(ally.health).is_equal_approx(ally._config("max_health") * 0.5, 1.0)
	assert_str(ally.weapon_rig.slot1).is_equal("smg")  # restored from snapshot
	assert_int(ally.revived_by_peer).is_equal(2)


# --- Corpse side (consumed by the corpse's own tick) ---

func test_corpse_consumed_by_reclaim_destroy() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var host: FPSController = runner.scene()
	var corpse := _corpse_at(host, Vector3(1.0, 0, 0), 2)
	await await_ticks(2)
	assert_bool(corpse.removed).is_false()

	corpse.queue_reclaim_destroy()
	await await_ticks(4)

	assert_bool(corpse.removed).is_true()


# --- Caster side (reservation) ---

func test_reclaim_cast_reserves_and_consumes_corpse() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var _ally := _static_dead_ally(caster, Vector3(1.5, 0, 0), 2)
	var corpse := _corpse_at(caster, Vector3(1.5, 0, 0), 2)
	await await_ticks(2)
	var before := caster.resonance.reserved

	press(caster.input, &"reclaim")
	await await_ticks(6)

	assert_bool(caster.reclaim_reserved).is_true()
	assert_float(caster.resonance.reserved).is_greater(before)
	assert_bool(corpse.removed).is_true()


func test_out_of_range_corpse_not_reserved() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var _ally := _static_dead_ally(caster, Vector3(50, 0, 0), 2)
	var corpse := _corpse_at(caster, Vector3(50, 0, 0), 2)
	await await_ticks(2)

	press(caster.input, &"reclaim")
	await await_ticks(6)

	assert_bool(caster.reclaim_reserved).is_false()
	assert_bool(corpse.removed).is_false()


# A static, non-simulated prop that is alive and marked as revived by `reviver`
# from spawn (pre-tick rollback-state writes persist; mid-test writes do not).
func _static_revived_ally(host: FPSController, peer: int, reviver: int) -> FPSController:
	var ally: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	host.get_parent().add_child(ally)
	ally.input.set_multiplayer_authority(peer)
	ally.revived_by_peer = reviver
	return ally


func test_reclaim_reservation_held_while_revived_ally_alive() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var caster_peer := caster.input.get_multiplayer_authority()
	var _dead := _static_dead_ally(caster, Vector3(1.5, 0, 0), 2)
	var _corpse := _corpse_at(caster, Vector3(1.5, 0, 0), 2)
	var _revived := _static_revived_ally(caster, 3, caster_peer)  # alive, revived by caster
	await await_ticks(2)

	press(caster.input, &"reclaim")
	await await_ticks(50)  # past the 30-tick grace window

	# Held: a live ally revived by the caster still exists.
	assert_bool(caster.reclaim_reserved).is_true()


func test_reclaim_reservation_released_when_no_revived_ally() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var _dead := _static_dead_ally(caster, Vector3(1.5, 0, 0), 2)
	var _corpse := _corpse_at(caster, Vector3(1.5, 0, 0), 2)
	await await_ticks(2)

	press(caster.input, &"reclaim")
	await await_ticks(4)
	assert_bool(caster.reclaim_reserved).is_true()

	# No live revived ally -> released after the grace window.
	await await_ticks(50)
	assert_bool(caster.reclaim_reserved).is_false()


# --- Bleed-out (revived ally bleeds when its reviver is dead) ---

func test_caster_death_bleeds_revived_ally() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var ally: FPSController = runner.scene()
	# The reviver is a static, already-dead prop (authority 2).
	var reviver: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	ally.get_parent().add_child(reviver)
	reviver.input.set_multiplayer_authority(2)
	reviver.is_dead = true  # pre-tick -> persists

	ally.queue_damage(9999.0)
	await await_ticks(6)
	ally.queue_reclaim_revive(ally.global_position, 2,
		["smg", 10.0, 30.0, "", 0.0, 0.0, 1])
	await await_ticks(8)

	assert_bool(ally.is_dead).is_false()          # revived
	assert_int(ally.bleed_ticks_remaining).is_greater(0)  # bleeding (reviver dead)
	assert_int(ally.revived_by_peer).is_equal(0)  # link consumed (one-shot)
