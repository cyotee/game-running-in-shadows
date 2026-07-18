# Base for all weapons. Fire pipeline lands in the next task; this task is
# identity + ammo + reload bookkeeping. All numeric config via MatchConfig
# under "weapon.<weapon_key>.*". Mutable vars are rollback state.
class_name WeaponBase
extends Node3D

@export var weapon_key: String = ""
@export var weight_class: int = 0  # 0 light, 1 medium, 2 heavy

# --- Rollback state ---
var mag: float = 0.0
var reserve: float = 0.0
var last_fire_tick: int = -(1 << 30)
var reload_until_tick: int = -(1 << 30)


func config(suffix: String) -> float:
	return MatchConfig.get_value("weapon.%s.%s" % [weapon_key, suffix])


func initialize_ammo() -> void:
	mag = config("mag")
	reserve = config("reserve")


func is_reloading(tick: int) -> bool:
	return tick < reload_until_tick


func start_reload(tick: int) -> void:
	if mag >= config("mag") or reserve <= 0.0 or is_reloading(tick):
		return
	reload_until_tick = tick + int(roundf(config("reload_s") * NetworkTime.tickrate))


func finish_reload_if_due(tick: int) -> void:
	# Called each tick; completes a pending reload exactly once.
	if reload_until_tick != -(1 << 30) and tick >= reload_until_tick:
		var need := config("mag") - mag
		var moved := minf(need, reserve)
		mag += moved
		reserve -= moved
		reload_until_tick = -(1 << 30)
