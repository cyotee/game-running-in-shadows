# GdUnit4 test suite for FPSController (netfox rollback tick version).
# NetworkTime runs during each test; effects land on network ticks, so tests
# await real frames after injecting input.
class_name TestFPSController
extends NetSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"

const PITCH_DOWN := -0.8
const PITCH_LEVEL := 0.0


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func _spawn_controller() -> GdUnitSceneRunner:
	var runner := scene_runner(CONTROLLER_SCENE)
	return runner


func test_spawns_with_defaults() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	assert_bool(controller.is_gliding).is_false()
	assert_float(controller.walk_speed).is_greater(0.0)
	assert_float(controller.combo_launch_velocity).is_greater(controller.jump_velocity)


func test_moves_forward_on_input() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	var start_z := controller.global_position.z

	runner.simulate_action_press("move_forward")
	await await_ticks(30)
	runner.simulate_action_release("move_forward")

	assert_float(controller.global_position.z).is_less(start_z - 0.2)


func test_sprint_is_faster_than_walk() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	runner.simulate_action_press("move_forward")
	await await_ticks(30)
	var walk_dz := absf(controller.global_position.z)

	controller.global_position = Vector3.ZERO
	controller.velocity = Vector3.ZERO
	runner.simulate_action_press("sprint")
	await await_ticks(30)
	runner.simulate_action_release("sprint")
	runner.simulate_action_release("move_forward")

	assert_float(absf(controller.global_position.z)).is_greater(walk_dz)


func test_yaw_input_rotates_body() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	controller.input.local_yaw = 0.9
	# TickInterpolator blends the displayed transform between ticks, so give
	# the rotation a few extra frames to converge on the target yaw.
	await await_ticks(15)

	assert_float(controller.rotation.y).is_equal_approx(0.9, 0.05)


func test_glide_without_combo_gives_no_launch() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await grant_movement_kit(controller)
	controller.input.local_pitch = PITCH_DOWN

	press(controller.input, &"glide")
	await await_ticks(3)
	await await_ticks(5)

	assert_bool(controller.is_gliding).is_true()
	assert_float(controller.velocity.y).is_less(controller.combo_launch_velocity * 0.5)


func test_down_repulse_then_glide_triggers_combo_launch() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await grant_movement_kit(controller)
	controller.input.local_pitch = PITCH_DOWN

	press(controller.input, &"repulse")
	await await_ticks(3)
	await await_ticks(3)
	press(controller.input, &"glide")
	await await_ticks(3)
	await await_ticks(2)

	assert_bool(controller.is_gliding).is_true()
	# A few ticks of reduced glide gravity may have shaved a little off.
	assert_float(controller.velocity.y).is_greater(controller.combo_launch_velocity * 0.7)


func test_combo_launch_keeps_glide_active_while_rising() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await grant_movement_kit(controller)
	controller.input.local_pitch = PITCH_DOWN

	press(controller.input, &"repulse")
	await await_ticks(3)
	press(controller.input, &"glide")
	await await_ticks(20)

	# Still rising or floating mid-launch: glide must not self-cancel.
	assert_bool(controller.is_gliding).is_true()


func test_level_repulse_does_not_arm_combo() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await grant_movement_kit(controller)
	controller.input.local_pitch = PITCH_LEVEL

	press(controller.input, &"repulse")
	await await_ticks(3)
	await await_ticks(3)
	controller.input.local_pitch = PITCH_DOWN
	press(controller.input, &"glide")
	await await_ticks(3)
	await await_ticks(2)

	assert_bool(controller.is_gliding).is_true()
	assert_float(controller.velocity.y).is_less(controller.combo_launch_velocity * 0.5)


func test_spawns_with_archetype_stats_and_reservation() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	# Free kit: pistol + grenades only — no Glide Harness reserve yet.
	assert_float(controller.resonance.max_resonance).is_equal(10.0)
	assert_float(controller.resonance.reserved).is_equal(0.0)
	assert_float(controller.resonance.current).is_equal(10.0)
	assert_float(controller.health).is_equal(100.0)
	assert_bool(controller.owns_kit("grenades")).is_true()
	assert_bool(controller.owns_kit("repulse")).is_false()
	assert_bool(controller.owns_kit("glide")).is_false()
	# Purchasing Glide Harness locks reservation (2 x tech 1.0) -> 8/10.
	await grant_movement_kit(controller)
	assert_float(controller.resonance.reserved).is_equal(2.0)
	assert_float(controller.resonance.current).is_equal(8.0)


func test_repulse_requires_purchase() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	var denials: Array = []
	controller.cast_denied.connect(func() -> void: denials.append(true))
	var res_before := controller.resonance.current
	press(controller.input, &"repulse")
	await await_ticks(5)
	assert_array(denials).has_size(1)
	assert_float(controller.resonance.current).is_greater_equal(res_before - 0.5)


func test_repulse_spends_resonance() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await grant_movement_kit(controller)
	controller.input.local_pitch = PITCH_LEVEL

	press(controller.input, &"repulse")
	await await_ticks(5)

	# One cast (cost 2) from 8 after harness reserve, plus regen drift.
	assert_float(controller.resonance.current).is_between(5.9, 6.6)


func test_repulse_hard_blocked_when_insufficient() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await equip_kit(controller, ["repulse"])
	# Out-of-band writes to Resonance rollback state are restored — raise cost
	# via MatchConfig so the cast path hard-blocks for real.
	MatchConfig.set_value("resonance.repulse_cost", 999.0)
	var res_before := controller.resonance.current
	var vel_before := controller.velocity

	press(controller.input, &"repulse")
	await await_ticks(5)

	# No spend (hard block); allow regen drift only.
	assert_float(controller.resonance.current).is_greater_equal(res_before - 0.5)
	assert_float(controller.resonance.current).is_less(res_before + 1.0)
	# No self-push happened (horizontal only: gravity owns the y axis while
	# the controller free-falls in the scene-runner void).
	var delta_v := controller.velocity - vel_before
	delta_v.y = 0.0
	assert_float(delta_v.length()).is_less(2.0)


func test_slip_blinks_in_open_space() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	# Immediate equip (kit flag is not rollback) before freefall builds velocity.
	controller.grant_kit("slip")
	assert_bool(controller.has_equipped("slip")).is_true()
	var start := controller.global_position
	var res_before := controller.resonance.current

	press(controller.input, &"slip")
	await await_ticks(5)

	# Stationary -> blinks along aim (default forward, ~8 m).
	assert_float(controller.global_position.distance_to(start)).is_greater(6.0)
	assert_float(controller.resonance.current).is_equal_approx(res_before - 3.0, 0.5)


func test_slip_blocked_destination_refunds_and_fizzles() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await equip_kit(controller, ["slip"])
	# Solid block filling the destination (8 m along -Z at body height).
	var wall: StaticBody3D = auto_free(StaticBody3D.new())
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 4)
	shape.shape = box
	wall.add_child(shape)
	controller.get_parent().add_child(wall)
	wall.global_position = controller.global_position + Vector3(0, 0.9, -8)

	var start := controller.global_position
	var res_before := controller.resonance.current
	var denials: Array = []
	controller.cast_denied.connect(func() -> void: denials.append(true))

	press(controller.input, &"slip")
	await await_ticks(5)

	# Blocked: no horizontal blink, cost refunded (never spent), fizzle emitted.
	var horiz := Vector2(controller.global_position.x - start.x,
		controller.global_position.z - start.z).length()
	assert_float(horiz).is_less(1.0)
	assert_array(denials).has_size(1)
	assert_float(controller.resonance.current).is_equal_approx(res_before, 0.3)


func test_wraith_toggles_and_drains() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await equip_kit(controller, ["wraith"])

	press(controller.input, &"wraith")
	await await_ticks(3)
	assert_bool(controller.is_wraithed).is_true()
	var after_toggle := controller.resonance.current  # ~9 (10 free pool - 1 cost)

	await await_ticks(30)  # ~0.5s of drain
	assert_bool(controller.is_wraithed).is_true()
	assert_float(controller.resonance.current).is_less(after_toggle)


func test_wraith_forced_out_when_pool_empties() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await equip_kit(controller, ["wraith"])
	# Out-of-band Resonance.current writes are restored — accelerate drain instead.
	MatchConfig.set_value("resonance.wraith_drain_per_s", 40.0)

	press(controller.input, &"wraith")
	await await_ticks(3)
	assert_bool(controller.is_wraithed).is_true()

	await await_ticks(30)  # ~0.5s at 40/s empties a full pool
	assert_bool(controller.is_wraithed).is_false()


func test_wraith_immune_to_bullets() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await equip_kit(controller, ["wraith"])

	press(controller.input, &"wraith")
	await await_ticks(3)
	assert_bool(controller.is_wraithed).is_true()

	var hp := controller.health
	controller.take_damage(50.0, null, NetworkTime.tick)
	assert_float(controller.health).is_equal(hp)


func test_wraith_blocks_weapon_fire() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await equip_kit(controller, ["wraith"])
	controller.weapon_rig.active_slot = 2  # pistol (semi-auto)

	press(controller.input, &"wraith")
	await await_ticks(3)
	var pistol := controller.weapon_rig.weapon_by_key("pistol")
	var mag0 := pistol.mag

	press(controller.input, &"fire")
	await await_ticks(6)

	assert_float(pistol.mag).is_equal(mag0)


func test_elf_archetype_reservation_scaled() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	controller.archetype = &"elf"
	await equip_kit(controller, ["glide"])
	controller._apply_archetype_config()

	# Elf: max 12, harness 2 x 1.5 = 3 reserved -> cap 9.
	assert_float(controller.resonance.reserved).is_equal(3.0)
	assert_float(controller.resonance.cap()).is_equal(9.0)
	assert_float(controller.health).is_equal(78.0)


func test_zone_damage_multipliers() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()

	victim.take_zone_damage(10.0, "pistol", "head", null, NetworkTime.tick)
	assert_float(victim.health).is_equal(80.0)   # 10 x 2.0
	victim.take_zone_damage(10.0, "pistol", "limbs", null, NetworkTime.tick)
	assert_float(victim.health).is_equal(72.5)   # 10 x 0.75


func test_dwarf_headshot_immunity() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()
	victim.archetype = &"dwarf"
	victim._apply_archetype_config()

	victim.take_zone_damage(10.0, "pistol", "head", null, NetworkTime.tick)
	assert_float(victim.health).is_equal(85.0)   # 95 - 10, no multiplier


func test_hit_zone_areas_exist_with_meta() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	for zone in ["Head", "Body", "Limbs"]:
		var area: Area3D = controller.get_node("HitZones/%s" % zone)
		assert_object(area).is_not_null()
		assert_str(str(area.get_meta("zone"))).is_equal(zone.to_lower())
		assert_int(area.collision_layer).is_equal(2)


func test_take_damage_marks_both_combatants_and_gates_regen() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()
	var attacker_runner := _spawn_controller()
	var attacker: FPSController = attacker_runner.scene()

	victim.resonance.drain(4.0)
	attacker.resonance.drain(4.0)
	var tick := NetworkTime.tick
	victim.take_damage(10.0, attacker, tick)

	assert_float(victim.health).is_equal(90.0)
	assert_bool(victim.resonance.is_in_combat(tick + 60)).is_true()
	assert_bool(attacker.resonance.is_in_combat(tick + 60)).is_true()
	# Both regen pools frozen while in combat.
	var v := victim.resonance.current
	victim.resonance.process_tick(1.0, tick + 60)
	assert_float(victim.resonance.current).is_equal(v)


func test_health_floors_at_zero() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	controller.take_damage(9999.0, controller, NetworkTime.tick)
	assert_float(controller.health).is_equal(0.0)


func test_elf_converts_resonance_to_health_out_of_combat() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.archetype = &"elf"
	controller._apply_archetype_config()
	controller.health = 50.0

	await await_ticks(60)  # ~1s out of combat at 60 tps

	assert_float(controller.health).is_greater(50.0)
	assert_float(controller.resonance.current).is_less(controller.resonance.cap())


func test_elf_heal_respects_resonance_floor() -> void:
	# Zero out regen so the pool cannot climb back above the floor mid-test
	# (out of combat, regen + conversion legitimately cooperate otherwise).
	MatchConfig.set_value("archetype.elf.regen_per_s", 0.0)
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.archetype = &"elf"
	controller._apply_archetype_config()
	controller.health = 1.0
	controller.resonance.current = 2.0  # exactly at the floor

	await await_ticks(30)

	assert_float(controller.resonance.current).is_equal(2.0)
	assert_float(controller.health).is_equal(1.0)


func test_elf_does_not_heal_in_combat() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.archetype = &"elf"
	controller._apply_archetype_config()
	controller.health = 50.0
	controller.resonance.mark_combat(NetworkTime.tick)

	await await_ticks(30)

	assert_float(controller.health).is_equal(50.0)


func test_human_does_not_convert() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.health = 50.0

	await await_ticks(30)

	assert_float(controller.health).is_equal(50.0)


func test_dwarf_aura_drains_nearby_enemy() -> void:
	var runner := _spawn_controller()
	var dwarf: FPSController = runner.scene()
	dwarf.archetype = &"dwarf"
	dwarf._apply_archetype_config()

	var victim_runner := _spawn_controller()
	var victim: FPSController = victim_runner.scene()
	victim.global_position = dwarf.global_position + Vector3(2, 0, 0)
	var start := victim.resonance.current

	await await_ticks(60)  # ~1s in aura

	assert_float(victim.resonance.current).is_less(start)
	# Destroy-only: the dwarf gains nothing beyond its own (slow) regen cap.
	assert_float(dwarf.resonance.current).is_less_equal(dwarf.resonance.cap())


func test_dwarf_aura_ignores_distant_players() -> void:
	var runner := _spawn_controller()
	var dwarf: FPSController = runner.scene()
	dwarf.archetype = &"dwarf"
	dwarf._apply_archetype_config()

	var victim_runner := _spawn_controller()
	var victim: FPSController = victim_runner.scene()
	victim.global_position = dwarf.global_position + Vector3(50, 0, 0)
	var start := victim.resonance.current

	await await_ticks(30)

	assert_float(victim.resonance.current).is_equal(start)


func test_crouch_slows_movement() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	# Compare steady-state speeds (robust to the acceleration ramp):
	# walk up to full speed, then crouch and let it settle.
	runner.simulate_action_press("move_forward")
	await await_ticks(40)
	var walk_speed := Vector2(controller.velocity.x, controller.velocity.z).length()

	runner.simulate_action_press("crouch")
	await await_ticks(40)
	# Collider swap follows the input while crouched.
	assert_bool(controller.crouch_shape.disabled).is_false()
	assert_bool(controller.standing_shape.disabled).is_true()
	var crouch_speed := Vector2(controller.velocity.x, controller.velocity.z).length()
	runner.simulate_action_release("crouch")
	runner.simulate_action_release("move_forward")

	assert_float(crouch_speed).is_less(walk_speed)


func test_lethal_damage_freezes_and_signals_once() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()
	var deaths: Array = []
	victim.died.connect(func(v: int, a: int) -> void: deaths.append([v, a]))

	victim.take_damage(9999.0, null, NetworkTime.tick)
	await await_ticks(10)

	assert_bool(victim.is_dead).is_true()
	assert_array(deaths).has_size(1)
	var frozen_at := victim.global_position
	await await_ticks(10)
	assert_float((victim.global_position - frozen_at).length()).is_less(0.01)


func test_reset_for_round_revives() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()
	victim.take_damage(9999.0, null, NetworkTime.tick)
	await await_ticks(5)
	assert_bool(victim.is_dead).is_true()

	victim.reset_for_round(Vector3(3, 1, 3))
	await await_ticks(5)

	assert_bool(victim.is_dead).is_false()
	assert_float(victim.health).is_equal(victim._config("max_health"))


func test_bleed_damages_without_marking_combat() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()
	var start_health := victim.health

	victim.apply_bleed(4.0, 8.0)
	await await_ticks(60)  # ~1s

	assert_float(victim.health).is_less(start_health)
	assert_float(victim.health).is_greater(start_health - 8.0)  # ~4 HP lost
	assert_bool(victim.resonance.is_in_combat(NetworkTime.tick)).is_false()


func test_bleed_refreshes_does_not_stack() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()

	victim.apply_bleed(4.0, 8.0)
	var first := victim.bleed_ticks_remaining
	await await_ticks(30)
	victim.apply_bleed(4.0, 8.0)

	assert_int(victim.bleed_ticks_remaining).is_between(first - 5, first + 5)
	assert_float(victim.bleed_hp_per_s).is_equal(4.0)


func test_bleeding_elf_holds_health_while_resonance_drains() -> void:
	# THE decided equilibrium: bleed 4 HP/s vs Elf heal 4 HP/s must cancel
	# emergently. Elf must be out of combat for the heal to run.
	var runner := _spawn_controller()
	var elf: FPSController = runner.scene()
	elf.archetype = &"elf"
	elf._apply_archetype_config()
	elf.health = 60.0
	var start_res := elf.resonance.current

	elf.apply_bleed(4.0, 8.0)
	await await_ticks(120)  # ~2s

	assert_float(elf.health).is_equal_approx(60.0, 1.5)
	assert_float(elf.resonance.current).is_less(start_res)


func test_slowdown_scale_set_when_enemy_under_reticle() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	var victim: FPSController = auto_free((load(CONTROLLER_SCENE) as PackedScene).instantiate())
	controller.get_parent().add_child(victim)
	victim.position = controller.position + Vector3(0, 0, -5)
	# Aim straight at the victim (spawned facing -Z).
	controller.input.local_pitch = 0.0
	# Aim assist is frame-driven view logic (_process), so await frames here.
	await runner.simulate_frames(10)

	assert_bool(controller.enemy_under_reticle(40.0)).is_true()
	assert_float(controller.input.look_rate_scale).is_equal(0.6)

	# Turn the view away (rollback owns the victim's transform, so move the
	# reticle rather than the victim).
	controller.input.local_yaw = 1.2
	await runner.simulate_frames(15)
	assert_float(controller.input.look_rate_scale).is_equal(1.0)


func test_airborne_jump_deploys_glide() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await grant_movement_kit(controller)
	# Spawned in empty space, the controller is airborne (falling) from tick 1.
	press(controller.input, &"jump")
	await await_ticks(10)

	assert_bool(controller.is_gliding).is_true()


# Multi-jump / climb-mash limits live in test_jump_limits.gd (isolated from
# load-flaky movement Input.action_press tests in this suite).


func test_combo_expires_after_window() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	await grant_movement_kit(controller)
	controller.input.local_pitch = PITCH_DOWN

	press(controller.input, &"repulse")
	await await_ticks(3)
	await await_ticks(3)
	await await_millis(int(controller.combo_window * 1000) + 300)
	press(controller.input, &"glide")
	await await_ticks(3)
	await await_ticks(2)

	assert_bool(controller.is_gliding).is_true()
	assert_float(controller.velocity.y).is_less(controller.combo_launch_velocity * 0.5)


func test_ping_aimed_at_open_space_makes_world_ping() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	PingService.setup(null)
	PingService.reset()
	# Aim level with no enemy in front -> world ping (wall or max-range point).
	controller.input.local_pitch = PITCH_LEVEL
	await await_ticks(2)

	controller.try_ping()

	var owner := controller.input.get_multiplayer_authority()
	assert_int(PingService.active_count()).is_equal(1)
	assert_int(PingService.visible_pings(owner)[0]["kind"]).is_equal(PingService.WORLD)
	PingService.reset()
