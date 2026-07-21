class_name TestFamiliar
extends NetSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"
const FAMILIAR_SCENE := "res://scenes/abilities/familiar.tscn"
const NULL_SCENE := "res://scenes/abilities/null_charge.tscn"
const ARENA_SCENE := "res://scenes/levels/test_arena.tscn"

# Offline netfox only simulates the runner's authority-1 controller. Make the
# entity-under-test the runner scene; other controllers are STATIC props set
# before the first tick (same harness as test_reclaim.gd).


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)
	PingService.setup(null)
	PingService.reset()


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()
	PingService.reset()
	for node in get_tree().get_nodes_in_group("familiars"):
		if is_instance_valid(node):
			node.free()
	for node in get_tree().get_nodes_in_group("null_fields"):
		if is_instance_valid(node):
			node.free()


func _spawn_familiar(host: Node3D, pos: Vector3, caster_peer: int, mode: int = Familiar.FOLLOW,
		guard: Vector3 = Vector3.ZERO) -> Familiar:
	var fam: Familiar = (load(FAMILIAR_SCENE) as PackedScene).instantiate()
	host.get_parent().add_child(fam)
	fam.setup(pos, caster_peer, mode, guard)
	return fam


func _static_peer(host: FPSController, offset: Vector3, peer: int,
		archetype: StringName = &"human") -> FPSController:
	var other: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	host.get_parent().add_child(other)
	other.input.set_multiplayer_authority(peer)
	other.global_position = host.global_position + offset
	other.archetype = archetype
	other._apply_archetype_config()
	return other


# --- Summon / reservation (arena has ProjectileSpawner) ---

func test_cast_summons_familiar_and_reserves() -> void:
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var caster: FPSController = runner.scene().get_node("FPSController")
	var before := caster.resonance.reserved

	press(caster.input, &"familiar")
	await await_ticks(8)

	assert_bool(caster.familiar_reserved).is_true()
	assert_float(caster.resonance.reserved).is_greater(before)
	assert_int(caster.get_tree().get_nodes_in_group("familiars").size()).is_greater_equal(1)
	var fam: Familiar = caster.get_tree().get_nodes_in_group("familiars")[0]
	assert_int(fam.caster_peer).is_equal(caster.input.get_multiplayer_authority())
	assert_bool(fam._is_dead()).is_false()


func test_cast_denied_with_insufficient_resonance() -> void:
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var caster: FPSController = runner.scene().get_node("FPSController")
	# Mid-tick writes to Resonance rollback state are restored — raise the cost
	# via MatchConfig instead so the cast path is denied for real.
	MatchConfig.set_value("resonance.familiar_cost", 999.0)
	var denials: Array = []
	caster.cast_denied.connect(func() -> void: denials.append(true))

	press(caster.input, &"familiar")
	await await_ticks(6)

	assert_array(denials).has_size(1)
	assert_bool(caster.familiar_reserved).is_false()
	assert_int(caster.get_tree().get_nodes_in_group("familiars").size()).is_equal(0)


func test_re_mode_does_not_double_reserve() -> void:
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var caster: FPSController = runner.scene().get_node("FPSController")
	press(caster.input, &"familiar")
	await await_ticks(8)
	assert_bool(caster.familiar_reserved).is_true()
	var reserved_after := caster.resonance.reserved
	var count0 := caster.get_tree().get_nodes_in_group("familiars").size()

	press(caster.input, &"familiar")
	await await_ticks(8)

	assert_float(caster.resonance.reserved).is_equal(reserved_after)
	assert_int(caster.get_tree().get_nodes_in_group("familiars").size()).is_equal(count0)


func test_reservation_releases_when_familiar_dies() -> void:
	var runner := scene_runner(ARENA_SCENE)
	await await_ticks(5)
	var caster: FPSController = runner.scene().get_node("FPSController")
	var reserved_before := caster.resonance.reserved
	press(caster.input, &"familiar")
	await await_ticks(8)
	assert_bool(caster.familiar_reserved).is_true()

	var fam: Familiar = caster.get_tree().get_nodes_in_group("familiars")[0]
	fam.destroy()
	await await_ticks(45)

	assert_bool(caster.familiar_reserved).is_false()
	assert_float(caster.resonance.reserved).is_equal(reserved_before)


# --- Lifecycle ---

func test_dies_with_caster() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var peer := caster.input.get_multiplayer_authority()
	var fam := _spawn_familiar(caster, caster.global_position + Vector3(1, 0, 0), peer)
	await await_ticks(2)
	assert_bool(fam._is_dead()).is_false()

	caster.queue_damage(9999.0)
	await await_ticks(6)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(caster.is_dead).is_true()
	# Familiar frees itself in _process once dead — assert node is gone.
	assert_bool(is_instance_valid(fam)).is_false()


func test_shootable_take_familiar_damage() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var peer := caster.input.get_multiplayer_authority()
	var fam := _spawn_familiar(caster, caster.global_position + Vector3(1, 0, 0), peer)
	await await_ticks(2)

	fam.take_familiar_damage(MatchConfig.get_value("familiar.hp") + 10.0)
	await await_ticks(4)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(is_instance_valid(fam)).is_false()


# --- Movement ---

func test_follow_stays_near_caster() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var peer := caster.input.get_multiplayer_authority()
	# Spawn moderately far; move_speed 7 m/s * ~2 s of ticks closes ~14 m.
	var start := caster.global_position + Vector3(12, 0, 0)
	var fam := _spawn_familiar(caster, start, peer, Familiar.FOLLOW)
	var d0 := fam.global_position.distance_to(caster.global_position)
	await await_ticks(150)

	var offset := MatchConfig.get_value("familiar.follow_offset_m")
	var melee := MatchConfig.get_value("familiar.melee_range_m")
	assert_float(fam.global_position.distance_to(caster.global_position)).is_less(d0)
	assert_float(fam.global_position.distance_to(caster.global_position)).is_less(
		offset + melee + 2.0)


func test_guard_holds_near_guard_pos() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var peer := caster.input.get_multiplayer_authority()
	var guard := caster.global_position + Vector3(8, 0, 0)
	var fam := _spawn_familiar(caster, caster.global_position, peer, Familiar.GUARD, guard)
	await await_ticks(150)

	assert_int(fam.mode).is_equal(Familiar.GUARD)
	assert_float(fam.global_position.distance_to(guard)).is_less(
		MatchConfig.get_value("familiar.melee_range_m") + 2.0)


func test_hunt_moves_toward_ping_tagged_enemy() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var peer := caster.input.get_multiplayer_authority()
	var enemy := _static_peer(caster, Vector3(18, 0, 0), 2)
	var fam := _spawn_familiar(caster, caster.global_position, peer, Familiar.FOLLOW)
	# Tag enemy for the caster (test seam).
	PingService._apply_ping(peer, PingService.ENEMY, Vector3.ZERO, 2)
	assert_int(PingService.latest_enemy_tag(peer)).is_equal(2)

	var x0 := fam.global_position.x
	await await_ticks(120)

	assert_float(fam.global_position.x).is_greater(x0 + 3.0)
	assert_float(fam.global_position.distance_to(enemy.global_position)).is_less(
		fam.global_position.distance_to(caster.global_position))


# --- Melee ---

func test_melee_damages_enemy_player() -> void:
	# Enemy is the simulated runner; Familiar (static caster peer 2) ticks...
	# Wait: only the runner scene is simulated. Familiars have their own
	# RollbackSynchronizer, so they DO get ticks if registered. Spawn adjacent.
	var runner := scene_runner(CONTROLLER_SCENE)
	var enemy: FPSController = runner.scene()
	var caster := _static_peer(enemy, Vector3(-30, 0, 0), 2)
	var hp0 := enemy.health
	var fam := _spawn_familiar(enemy, enemy.global_position + Vector3(0.5, 0, 0), 2,
		Familiar.FOLLOW)
	await await_ticks(30)

	assert_float(enemy.health).is_less(hp0)
	assert_float(fam.hp).is_greater(0.0)


func test_minion_vs_minion_damage() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var host: FPSController = runner.scene()
	var peer := host.input.get_multiplayer_authority()
	var _caster2 := _static_peer(host, Vector3(40, 0, 0), 2)
	var mine := _spawn_familiar(host, host.global_position, peer, Familiar.FOLLOW)
	var theirs := _spawn_familiar(host, host.global_position + Vector3(1.0, 0, 0), 2,
		Familiar.FOLLOW)
	var hp0 := theirs.hp
	await await_ticks(40)

	assert_float(theirs.hp).is_less(hp0)


# --- Counters ---

func test_null_field_destroys_familiar() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var peer := caster.input.get_multiplayer_authority()
	var fam := _spawn_familiar(caster, caster.global_position + Vector3(0, 0, -1), peer)
	var nullf: NullCharge = (load(NULL_SCENE) as PackedScene).instantiate()
	caster.get_parent().add_child(nullf)
	nullf.setup(fam.global_position, peer, 200.0, 6000)

	await await_ticks(6)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(is_instance_valid(fam)).is_false()


func test_dwarf_proximity_destroys_familiar() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var caster: FPSController = runner.scene()
	var peer := caster.input.get_multiplayer_authority()
	var fam := _spawn_familiar(caster, caster.global_position + Vector3(2, 0, 0), peer)
	var _dwarf := _static_peer(caster, Vector3(2.2, 0, 0), 2, &"dwarf")

	await await_ticks(6)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(is_instance_valid(fam)).is_false()
