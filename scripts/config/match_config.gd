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
