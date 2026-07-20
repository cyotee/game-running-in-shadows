# Lifebloom — friend-or-foe heal aura. Heals every player in radius each
# tick, regardless of combat state (in-combat healing is a deliberately
# scarce category — decided). Shootable + withers via PlacedField base.
class_name Lifebloom
extends PlacedField


func _field_groups() -> Array[String]:
	return ["lifebloom_fields"]


func _field_tick(delta: float, tick: int, _is_fresh: bool) -> void:
	var heal := MatchConfig.get_value("ability.lifebloom_heal_per_s") * delta
	for player in _players_in_radius(MatchConfig.get_value("ability.lifebloom_radius_m")):
		player.heal(heal, tick)
