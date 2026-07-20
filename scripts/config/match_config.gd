# Match-wide gameplay tunables, injected at game start.
# DESIGN RULE (2026-07-16): no gameplay number is hard-coded anywhere else —
# systems read from here so private hosts can tune the game to their taste.
# Override sources (later wins): --match-config=<path> cmdline user arg,
# then user://match_config.json. Host -> client sync arrives with lobbies.
extends Node

const DEFAULTS: Dictionary = {
	"resonance.combat_timeout_s": 4.0,
	"resonance.repulse_cost": 2.0,
	"resonance.glide_harness_reservation": 2.0,
	"weapon.hitscan_damage": 10.0,
	"archetype.human.max_resonance": 10.0,
	"archetype.human.regen_per_s": 0.35,
	"archetype.human.tech_mult": 1.0,
	"archetype.human.max_health": 100.0,
	"archetype.elf.max_resonance": 12.0,
	"archetype.elf.regen_per_s": 0.8,
	"archetype.elf.tech_mult": 1.5,
	"archetype.elf.max_health": 78.0,
	"archetype.elf.heal_convert_per_s": 0.5,
	"archetype.elf.heal_hp_per_resonance": 8.0,
	"archetype.elf.heal_resonance_floor": 2.0,
	"archetype.dwarf.max_resonance": 14.0,
	"archetype.dwarf.regen_per_s": 0.15,
	"archetype.dwarf.tech_mult": 2.0,
	"archetype.dwarf.max_health": 95.0,
	"archetype.dwarf.drain_radius_m": 6.0,
	"archetype.dwarf.drain_per_enemy_per_s": 0.5,
	"archetype.troll.max_resonance": 8.0,
	"archetype.troll.regen_per_s": 0.0,
	"archetype.troll.tech_mult": 1.25,
	"archetype.troll.max_health": 135.0,
	# --- Weapons (slow/arena TTK; see ABILITY_TUNING_SHEET §11) ---
	"zones.head_mult_default": 2.0,
	"zones.limb_mult": 0.75,
	"weapon.pistol.damage": 12.0, "weapon.pistol.head_mult": 2.0,
	"weapon.pistol.fire_interval_s": 0.35, "weapon.pistol.mag": 12.0,
	"weapon.pistol.reserve": 36.0, "weapon.pistol.reload_s": 1.4,
	"weapon.pistol.falloff_start_m": 15.0, "weapon.pistol.falloff_end_m": 35.0,
	"weapon.pistol.falloff_min_mult": 0.5, "weapon.pistol.weight": 0.0,
	"weapon.smg.damage": 7.0, "weapon.smg.head_mult": 1.5,
	"weapon.smg.fire_interval_s": 0.08, "weapon.smg.mag": 30.0,
	"weapon.smg.reserve": 90.0, "weapon.smg.reload_s": 1.8,
	"weapon.smg.falloff_start_m": 12.0, "weapon.smg.falloff_end_m": 30.0,
	"weapon.smg.falloff_min_mult": 0.4, "weapon.smg.weight": 0.0,
	"weapon.smg.bloom_per_shot_deg": 0.15, "weapon.smg.bloom_max_deg": 3.0,
	"weapon.smg.bloom_decay_deg_s": 3.0,
	"weapon.shotgun.damage": 6.0, "weapon.shotgun.head_mult": 1.5,
	"weapon.shotgun.pellets": 8.0, "weapon.shotgun.cone_deg": 5.0,
	"weapon.shotgun.fire_interval_s": 0.9, "weapon.shotgun.mag": 6.0,
	"weapon.shotgun.reserve": 24.0, "weapon.shotgun.reload_s": 2.4,
	"weapon.shotgun.falloff_start_m": 6.0, "weapon.shotgun.falloff_end_m": 18.0,
	"weapon.shotgun.falloff_min_mult": 0.2, "weapon.shotgun.weight": 1.0,
	"weapon.rifle.damage": 11.0, "weapon.rifle.head_mult": 2.0,
	"weapon.rifle.burst_count": 3.0, "weapon.rifle.burst_intra_s": 0.1,
	"weapon.rifle.fire_interval_s": 0.5, "weapon.rifle.mag": 24.0,
	"weapon.rifle.reserve": 72.0, "weapon.rifle.reload_s": 2.0,
	"weapon.rifle.falloff_start_m": 30.0, "weapon.rifle.falloff_end_m": 70.0,
	"weapon.rifle.falloff_min_mult": 0.6, "weapon.rifle.weight": 1.0,
	"weapon.rifle.ads_zoom": 1.6,
	"weapon.sniper.damage": 55.0, "weapon.sniper.head_mult": 2.0,
	"weapon.sniper.fire_interval_s": 1.4, "weapon.sniper.mag": 5.0,
	"weapon.sniper.reserve": 15.0, "weapon.sniper.reload_s": 2.8,
	"weapon.sniper.falloff_start_m": 999.0, "weapon.sniper.falloff_end_m": 999.0,
	"weapon.sniper.falloff_min_mult": 1.0, "weapon.sniper.weight": 2.0,
	"weapon.sniper.ads_zoom": 4.0,
	"weapon.recoil_scale": 1.0,
	"weapon.blade.damage": 25.0, "weapon.blade.backstab_mult": 1.6,
	"weapon.blade.swing_interval_s": 0.6, "weapon.blade.range_m": 2.2,
	"weapon.blade.arc_deg": 70.0, "weapon.blade.weight": 0.0,
	# Base-pipeline keys the shared WeaponBase code reads before BladeWeapon
	# overrides them away (prevents unknown-key push_errors): sentinel values.
	"weapon.blade.mag": 1.0, "weapon.blade.reserve": 0.0,
	"weapon.blade.reload_s": 0.1, "weapon.blade.fire_interval_s": 0.6,
	"weapon.blade.head_mult": 1.0, "weapon.blade.falloff_start_m": 999.0,
	"weapon.blade.falloff_end_m": 999.0, "weapon.blade.falloff_min_mult": 1.0,
	"weapon.blade.bleed_hp_s": 4.0, "weapon.blade.bleed_duration_s": 8.0,
	"weapon.blade.block_mult": 0.3, "weapon.blade.backstab_cone_deg": 100.0,
	"archetype.human.melee_mult": 1.0,
	"archetype.elf.melee_mult": 0.8,
	"archetype.dwarf.melee_mult": 1.0,
	"archetype.troll.melee_mult": 1.4,
	# Movement weight speed multipliers: weight class 0=light 1=medium 2=heavy
	"weight.medium.human": 0.95, "weight.medium.elf": 0.85,
	"weight.medium.dwarf": 0.95, "weight.medium.troll": 1.0,
	"weight.heavy.human": 0.85, "weight.heavy.elf": 0.65,
	"weight.heavy.dwarf": 0.85, "weight.heavy.troll": 0.93,
	# --- Session ---
	"session.max_players": 16.0,
	# --- Movement ---
	"movement.crouch_speed_mult": 0.55,
	# --- Abilities Wave 1 ---
	"resonance.slip_cost": 3.0,
	"ability.slip_distance_m": 8.0,
	"resonance.wraith_cost": 1.0,
	"resonance.wraith_drain_per_s": 1.5,
	"ability.grenade_stock": 2.0,
	"ability.grenade_fuse_s": 3.0,
	"ability.grenade_cook_max_s": 2.5,
	"ability.grenade_damage": 70.0,
	"ability.grenade_radius_m": 5.0,
	"ability.grenade_inner_radius_m": 1.5,
	"ability.grenade_throw_speed": 18.0,
	"price.slip": 2000.0,
	"price.wraith": 1700.0,
	"price.grenades": 0.0,
	# --- Abilities Wave 2 (placed fields) ---
	"ability.field_cast_range_m": 30.0,
	"resonance.lifebloom_cost": 3.0,
	"ability.lifebloom_heal_per_s": 6.0,
	"ability.lifebloom_radius_m": 7.0,
	"ability.lifebloom_hp": 100.0,
	"ability.lifebloom_lifetime_s": 180.0,
	"resonance.tangle_cost": 2.0,
	"ability.tangle_radius_m": 4.0,
	"ability.tangle_pull_accel": 12.0,
	"ability.tangle_hp": 120.0,
	"ability.tangle_lifetime_s": 75.0,
	"ability.null_stock": 4.0,
	"ability.null_radius_m": 5.0,
	"ability.null_lifetime_s": 10.0,
	"ability.null_drain_per_s": 1.0,
	"ability.null_hp": 60.0,
	"price.lifebloom": 1800.0,
	"price.tangle": 1800.0,
	"price.null_charge": 1400.0,
	# --- Economy ---
	"economy.start_money": 800.0,
	"economy.wage_base": 1000.0,
	"economy.wage_win_bonus": 600.0,
	"economy.kill_bonus": 200.0,
	"price.pistol": 0.0, "price.smg": 600.0, "price.shotgun": 1200.0,
	"price.rifle": 1600.0, "price.sniper": 2800.0, "price.blade": 1200.0,
	# --- Match flow ---
	"match.buy_phase_s": 15.0,
	"match.round_time_s": 180.0,
	"match.round_end_s": 5.0,
	"match.rounds_to_win": 6.0,
	"match.team_count": 2.0,
	# --- Controller input ---
	"input.stick_deadzone_inner": 0.15,
	"input.stick_deadzone_outer": 0.98,
	"input.look_curve_exponent": 2.0,
	"input.look_max_yaw_deg_s": 240.0,
	"input.look_max_pitch_deg_s": 180.0,
	"input.slowdown_mult": 0.6,
	"input.slowdown_range_m": 40.0,
}

var _values: Dictionary = {}


func _ready() -> void:
	reset_to_defaults()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--match-config="):
			load_overrides(arg.trim_prefix("--match-config="))
	if FileAccess.file_exists("user://match_config.json"):
		load_overrides("user://match_config.json")


func get_value(key: String) -> float:
	if not _values.has(key):
		push_error("MatchConfig: unknown key '%s'" % key)
		return 0.0
	return _values[key]


func set_value(key: String, value: float) -> void:
	_values[key] = value


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate()


func load_overrides(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("MatchConfig: cannot read overrides at %s" % path)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is not Dictionary:
		push_warning("MatchConfig: %s is not a JSON object; ignoring" % path)
		return
	for key in parsed:
		if _values.has(key) and (parsed[key] is float or parsed[key] is int):
			_values[key] = float(parsed[key])
		else:
			push_warning("MatchConfig: ignoring unknown/non-numeric key '%s'" % key)
	print("MatchConfig: loaded overrides from %s" % path)
