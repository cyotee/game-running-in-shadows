class_name TestGrenade
extends NetSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"
const GRENADE_SCENE := "res://scenes/weapons/grenade.tscn"
const ARENA_SCENE := "res://scenes/levels/test_arena.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func test_grenade_detonates_after_fuse_and_damages_nearby() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var victim: FPSController = runner.scene()
	var grenade: Grenade = (load(GRENADE_SCENE) as PackedScene).instantiate()
	victim.get_parent().add_child(grenade)
	grenade.launch(victim.global_position + Vector3(0.5, 0.0, 0.0), Vector3.ZERO, 3, 0)

	var hp := victim.health
	await await_ticks(8)

	assert_float(victim.health).is_less(hp)  # took AoE
	assert_bool(grenade.detonated).is_true()
	# Deferred free flushes in idle frames.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(is_instance_valid(grenade)).is_false()


func test_grenade_falloff_reduces_edge_damage() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var inner_victim: FPSController = runner.scene()
	var edge_victim: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	inner_victim.get_parent().add_child(edge_victim)
	edge_victim.global_position = inner_victim.global_position + Vector3(4.5, 0.0, 0.0)

	var grenade: Grenade = (load(GRENADE_SCENE) as PackedScene).instantiate()
	inner_victim.get_parent().add_child(grenade)
	grenade.launch(inner_victim.global_position, Vector3.ZERO, 3, 0)

	var inner_hp := inner_victim.health
	var edge_hp := edge_victim.health
	await await_ticks(8)

	var inner_loss := inner_hp - inner_victim.health
	var edge_loss := edge_hp - edge_victim.health
	assert_float(inner_loss).is_greater(edge_loss)
	assert_float(edge_loss).is_greater(0.0)


func test_throw_consumes_stock_and_spawns_grenade() -> void:
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var controller: FPSController = runner.scene().get_node("FPSController")
	var stock0 := controller.grenade_stock

	press(controller.input, &"grenade")
	await await_ticks(8)

	assert_int(controller.grenade_stock).is_equal(stock0 - 1)
	assert_int(controller.get_tree().get_nodes_in_group("grenades").size()).is_greater_equal(1)


func test_cook_shortens_time_to_detonation() -> void:
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var controller: FPSController = runner.scene().get_node("FPSController")

	# Hold the grenade to cook the fuse, then release to throw.
	Input.action_press("grenade")
	await await_ticks(60)  # ~1s of cook
	assert_int(controller.grenade_cook_ticks).is_greater(30)
	Input.action_release("grenade")
	await await_ticks(8)

	var grenades := controller.get_tree().get_nodes_in_group("grenades")
	assert_int(grenades.size()).is_greater_equal(1)
	var grenade: Grenade = grenades[0]
	# Full fuse is 180 ticks; a ~1 s cook plus flight time leaves clearly less.
	assert_int(grenade.fuse_ticks_left).is_less(150)
