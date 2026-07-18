# Resonance pool math (MECHANICS_REFERENCE §2, decided 2026-07-16).
# Reservations lock capacity at the top of the pool: cap = max - reserved.
# Releasing a reservation raises the cap but returns the pips EMPTY.
# All mutable vars are netfox rollback state, registered in
# fps_controller.tscn as "Resonance:<name>". process_tick is called from the
# owning controller's _rollback_tick — never from _process.
class_name ResonancePool
extends Node

# Configured by the owner from MatchConfig at spawn (not rollback state).
var max_resonance: float = 10.0
var regen_per_s: float = 0.0
var combat_timeout_ticks: int = 240

# --- Rollback state ---
var current: float = 0.0
var reserved: float = 0.0
var last_combat_tick: int = -(1 << 30)


func cap() -> float:
	return maxf(max_resonance - reserved, 0.0)


func fill_to_cap() -> void:
	current = cap()


func can_afford(cost: float) -> bool:
	return current >= cost


func try_spend(cost: float) -> bool:
	if current < cost:
		return false
	current -= cost
	return true


func reserve(amount: float) -> void:
	reserved += amount
	current = minf(current, cap())


func release(amount: float) -> void:
	# Capacity returns; pips come back EMPTY (must regen). Decided 2026-07-16.
	reserved = maxf(reserved - amount, 0.0)


func drain(amount: float) -> void:
	current = maxf(current - amount, 0.0)


func mark_combat(tick: int) -> void:
	last_combat_tick = maxi(last_combat_tick, tick)


func is_in_combat(tick: int) -> bool:
	return tick - last_combat_tick < combat_timeout_ticks


func process_tick(delta: float, tick: int) -> void:
	if not is_in_combat(tick):
		current = minf(current + regen_per_s * delta, cap())
