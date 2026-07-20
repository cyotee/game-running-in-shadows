# Base for placed, persistent field abilities (Lifebloom, Tangle, Null
# Charge). Rollback-simulated like the grenade: hp / ticks_left are rollback
# state, the field withers each tick and dies with its caster (effects die
# with their caster — decided). Shootable via take_field_damage. Subclasses
# override _field_tick (per-tick effect) and _field_groups (group tags).
class_name PlacedField
extends Node3D

# --- Rollback state ---
var hp: float = 100.0
var ticks_left: int = 0

var caster_peer: int = 0
var _freed: bool = false

@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer


func _ready() -> void:
	add_to_group("placed_fields")
	for g in _field_groups():
		add_to_group(g)
	rollback_synchronizer.process_settings()


func setup(field_position: Vector3, caster: int, hp_value: float, lifetime_ticks: int) -> void:
	position = field_position
	caster_peer = caster
	hp = hp_value
	ticks_left = lifetime_ticks


func _process(_delta: float) -> void:
	# Free in idle time once the field is spent — never during the rollback
	# loop (same rule as the grenade projectile).
	if _is_dead() and not _freed:
		_freed = true
		queue_free()


func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if _is_dead():
		return
	ticks_left -= 1
	_field_tick(delta, tick, is_fresh)


func take_field_damage(amount: float) -> void:
	hp = maxf(hp - amount, 0.0)
	NetworkRollback.mutate(self)


func destroy() -> void:
	# External destruction (Null Charge / Dwarf). Zero HP -> dies next check.
	hp = 0.0
	NetworkRollback.mutate(self)


func _is_dead() -> bool:
	return hp <= 0.0 or ticks_left <= 0 or _caster_gone()


func _caster_gone() -> bool:
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as FPSController
		if player != null and player.input.get_multiplayer_authority() == caster_peer:
			return player.is_dead  # effects die with their caster
	return true  # caster left the match entirely


func _players_in_radius(radius: float) -> Array[FPSController]:
	var result: Array[FPSController] = []
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as FPSController
		if player != null and player.global_position.distance_to(global_position) <= radius:
			result.append(player)
	return result


# --- Overridable ---
func _field_groups() -> Array[String]:
	return []


func _field_tick(_delta: float, _tick: int, _is_fresh: bool) -> void:
	pass
