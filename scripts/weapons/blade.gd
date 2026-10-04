# Combat Blade (katana-style): arc sweep instead of rays, archetype-strength
# damage scaling, backstab bleed, blade-vs-blade blocking. Wielding it swaps
# to the third-person camera (view-only, see FPSController._process).
class_name BladeWeapon
extends WeaponBase


func initialize_ammo() -> void:
	mag = 1.0
	reserve = 0.0


func _can_fire(tick: int) -> bool:
	return _rig.active_weapon() == self \
		and not _controller().is_wraithed \
		and _controller().can_use_weapon(weapon_key) \
		and NetworkTime.seconds_between(last_fire_tick, tick) >= config("swing_interval_s")


func _fire(tick: int, is_fresh: bool = false) -> void:
	last_fire_tick = tick
	var me := _controller()
	var origin := me.global_position + Vector3(0, 1.2, 0)
	var forward := _aim_basis() * Vector3.FORWARD
	var arc := deg_to_rad(config("arc_deg")) * 0.5
	var range_m := config("range_m")
	var any_hit := false
	var last_hit_pos := Vector3.ZERO
	var last_damage := 0.0
	for node in me.get_tree().get_nodes_in_group("players"):
		var victim := node as FPSController
		if victim == null or victim == me:
			continue
		var to_victim := victim.global_position + Vector3(0, 1.2, 0) - origin
		if to_victim.length() > range_m:
			continue
		if forward.angle_to(to_victim.normalized()) > arc:
			continue
		var applied := _strike(victim, me, tick)
		any_hit = true
		last_hit_pos = victim.global_position + Vector3(0, 1.2, 0)
		last_damage = applied
	var tip := origin + forward * range_m
	# Local presentation only on fresh sim frames.
	_present_blade_fx(origin, tip, last_hit_pos, last_damage, any_hit, is_fresh)
	if is_fresh:
		# View-only stick slash (not rollback state).
		me.play_blade_swing_fx()


## Returns the confirmed damage float passed into take_damage (post mults).
func _strike(victim: FPSController, me: FPSController, tick: int) -> float:
	var damage := config("damage") * me._config("melee_mult")
	var victim_back := -(victim.transform.basis * Vector3.FORWARD)
	var from_victim := (me.global_position - victim.global_position).normalized()
	var is_backstab := victim_back.angle_to(from_victim) \
		<= deg_to_rad(config("backstab_cone_deg")) * 0.5
	if is_backstab:
		damage *= config("backstab_mult")
	if victim.is_blocking() and not is_backstab:
		damage *= config("block_mult")
	victim.take_damage(damage, me, tick)
	if is_backstab:
		victim.apply_bleed(config("bleed_hp_s"), config("bleed_duration_s"))
	NetworkRollback.mutate(victim)
	return damage


## Local blade swing FX. is_fresh=false skips draw (rollback resim safe).
## Returns true when presentation was attempted, false when skipped.
func _present_blade_fx(
		origin: Vector3, tip: Vector3, hit_pos: Vector3, damage: float,
		hit_player: bool, is_fresh: bool = true
) -> bool:
	if not is_fresh:
		return false
	if not PlaytestViz.enabled():
		return true
	var me := _controller_or_null()
	if me == null:
		return true
	var tree := me.get_tree()
	if tree == null:
		return true
	# Melee uses body palette for hits; miss uses the miss tracer color.
	var zone := "body" if hit_player else ""
	var col := PlaytestViz.zone_tracer_color(zone, hit_player)
	PlaytestViz.flash_line(tree, origin, tip, col)
	if hit_player and damage > 0.0:
		PlaytestViz.flash_hit_marker(tree, hit_pos, damage, "body")
	return true
