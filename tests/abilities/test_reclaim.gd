class_name TestReclaim
extends NetSuite

const ARENA_SCENE := "res://scenes/levels/test_arena.tscn"
const CORPSE_SCENE := "res://scenes/abilities/corpse.tscn"
const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()
	for node in get_tree().get_nodes_in_group("corpses"):
		node.free()


func _spawn_ally_corpse(host: FPSController, offset: Vector3, owner_peer: int) -> Corpse:
	var corpse: Corpse = (load(CORPSE_SCENE) as PackedScene).instantiate()
	host.get_parent().add_child(corpse)
	corpse.init(host.global_position + offset, owner_peer, 0,
		["smg", 10.0, 30.0, "", 0.0, 0.0, 1])
	return corpse


# Spawns a second controller, drives it dead, and drops a matching corpse in
# range of the caster. Returns [ally, corpse].
func _downed_ally_with_corpse(caster: FPSController, offset: Vector3, peer: int) -> Array:
	var ally: FPSController = (load(CONTROLLER_SCENE) as PackedScene).instantiate()
	caster.get_parent().add_child(ally)
	ally.input.set_multiplayer_authority(peer)
	await await_ticks(2)
	ally.global_position = caster.global_position + offset
	ally.queue_damage(9999.0)
	await await_ticks(6)
	var corpse := _spawn_ally_corpse(caster, offset, peer)
	await await_ticks(2)
	return [ally, corpse]


func test_reclaim_denied_with_no_corpse() -> void:
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var caster: FPSController = runner.scene().get_node("FPSController")
	var before := caster.resonance.reserved
	press(caster.input, &"reclaim")
	await await_ticks(6)
	assert_bool(caster.reclaim_reserved).is_false()
	assert_float(caster.resonance.reserved).is_equal(before)
