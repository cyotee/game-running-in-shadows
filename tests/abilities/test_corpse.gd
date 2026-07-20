class_name TestCorpse
extends NetSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"
const CORPSE_SCENE := "res://scenes/abilities/corpse.tscn"
const ARENA_SCENE := "res://scenes/levels/test_arena.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func _spawn_corpse_near(host: FPSController, offset: Vector3, snap: Array) -> Corpse:
	var corpse: Corpse = (load(CORPSE_SCENE) as PackedScene).instantiate()
	host.get_parent().add_child(corpse)
	corpse.init(host.global_position + offset, 2, 0, snap)
	return corpse


func _weapon_snapshot(w1: String, w2: String, grenades: int) -> Array:
	return [w1, 10.0, 30.0, w2, 12.0, 36.0, grenades]


# --- Task 1: spawn on death, inventory, persistence, limit ---

func test_death_spawns_corpse_with_inventory() -> void:
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var controller: FPSController = runner.scene().get_node("FPSController")

	controller.queue_damage(9999.0)
	await await_ticks(6)

	var corpses := controller.get_tree().get_nodes_in_group("corpses")
	assert_int(corpses.size()).is_greater_equal(1)
	var corpse: Corpse = corpses[0]
	assert_str(corpse.w1_key).is_equal("rifle")
	assert_str(corpse.w2_key).is_equal("pistol")
	assert_int(corpse.grenades).is_equal(2)


func test_corpse_persists_after_respawn() -> void:
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var controller: FPSController = runner.scene().get_node("FPSController")
	controller.queue_damage(9999.0)
	await await_ticks(6)
	var corpse: Corpse = controller.get_tree().get_nodes_in_group("corpses")[0]

	controller.reset_for_round(controller.global_position + Vector3(0.0, 0.0, -10.0))
	await await_ticks(6)

	assert_bool(controller.is_dead).is_false()          # respawned
	assert_bool(is_instance_valid(corpse)).is_true()    # corpse remains


func test_per_owner_limit_frees_oldest() -> void:
	MatchConfig.set_value("corpse.max_per_owner", 2.0)
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var controller: FPSController = runner.scene().get_node("FPSController")

	for i in range(3):
		controller.queue_damage(9999.0)
		await await_ticks(6)
		controller.reset_for_round(controller.global_position + Vector3(float(i + 1) * 3.0, 0.0, 0.0))
		await await_ticks(6)

	var live := 0
	for node in controller.get_tree().get_nodes_in_group("corpses"):
		var corpse := node as Corpse
		if corpse != null and not corpse.removed:
			live += 1
	assert_int(live).is_equal(2)


# --- Task 2: looting ---

func test_loot_grants_weapon_and_empties_slot() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var looter: FPSController = runner.scene()
	var corpse := _spawn_corpse_near(looter, Vector3(1.0, 0.0, 0.0), _weapon_snapshot("smg", "", 0))
	await await_ticks(2)

	press(looter.input, &"interact")
	await await_ticks(6)

	assert_str(looter.weapon_rig.slot1).is_equal("smg")
	assert_str(corpse.w1_key).is_equal("")


func test_loot_out_of_range_does_nothing() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var looter: FPSController = runner.scene()
	var corpse := _spawn_corpse_near(looter, Vector3(10.0, 0.0, 0.0), _weapon_snapshot("smg", "", 0))
	await await_ticks(2)

	press(looter.input, &"interact")
	await await_ticks(6)

	assert_str(corpse.w1_key).is_equal("smg")  # untouched


# --- Task 3: dragging ---

func test_drag_moves_corpse_toward_dragger() -> void:
	# Arena scene: the dragger stands on a floor (no fall-out-of-range).
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var dragger: FPSController = runner.scene().get_node("FPSController")
	var corpse := _spawn_corpse_near(dragger, Vector3(1.5, 0.0, 0.0), _weapon_snapshot("smg", "", 0))
	await await_ticks(2)
	var x0 := corpse.global_position.x

	Input.action_press("interact")
	await await_ticks(20)
	Input.action_release("interact")

	assert_int(corpse.dragged_by).is_not_equal(0)
	assert_float(corpse.global_position.x).is_less(x0)  # pulled toward dragger (-X)


func test_weapon_restricted_to_pistol_smg_while_dragging() -> void:
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var controller: FPSController = runner.scene().get_node("FPSController")  # rifle slot1, pistol slot2
	var _corpse := _spawn_corpse_near(controller, Vector3(1.0, 0.0, 0.0), _weapon_snapshot("smg", "", 0))
	await await_ticks(2)

	Input.action_press("interact")  # start dragging
	await await_ticks(4)
	assert_bool(controller.is_dragging).is_true()

	# Rifle blocked while dragging.
	var rifle := controller.weapon_rig.weapon_by_key("rifle")
	var rmag := rifle.mag
	press(controller.input, &"fire")
	await await_ticks(6)
	assert_float(rifle.mag).is_equal(rmag)

	# Pistol allowed while dragging. Switch via input (a mid-test active_slot
	# write would be discarded by the rollback state restore).
	select_slot(controller.input, 2)
	await await_ticks(4)
	var pistol := controller.weapon_rig.weapon_by_key("pistol")
	var pmag := pistol.mag
	press(controller.input, &"fire")
	await await_ticks(6)
	Input.action_release("interact")
	assert_float(pistol.mag).is_less(pmag)
