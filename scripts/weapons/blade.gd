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


func _fire(tick: int) -> void:
	last_fire_tick = tick
	var me := _controller()
	var origin := me.global_position + Vector3(0, 1.2, 0)
	var forward := _aim_basis() * Vector3.FORWARD
	var arc := deg_to_rad(config("arc_deg")) * 0.5
	for node in me.get_tree().get_nodes_in_group("players"):
		var victim := node as FPSController
		if victim == null or victim == me:
			continue
		var to_victim := victim.global_position + Vector3(0, 1.2, 0) - origin
		if to_victim.length() > config("range_m"):
			continue
		if forward.angle_to(to_victim.normalized()) > arc:
			continue
		_strike(victim, me, tick)


func _strike(victim: FPSController, me: FPSController, tick: int) -> void:
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
