# Null Charge — anti-awakening field. Drains enemy Resonance in radius,
# destroys other Manifestation fields inside, and (via
# FPSController._in_null_field) suppresses Manifestation casting within.
# Placed instantly at an aimed point; shootable + short lifetime (PlacedField).
class_name NullCharge
extends PlacedField


func _field_groups() -> Array[String]:
	return ["null_fields"]


func _field_tick(delta: float, _tick: int, is_fresh: bool) -> void:
	var radius := MatchConfig.get_value("ability.null_radius_m")
	var drain := MatchConfig.get_value("ability.null_drain_per_s") * delta
	for player in _players_in_radius(radius):
		if player.input.get_multiplayer_authority() != caster_peer:
			player.resonance.drain(drain)
			NetworkRollback.mutate(player)
	# Destroy other Manifestation fields inside — world side-effect, fresh only.
	if is_fresh:
		for node in get_tree().get_nodes_in_group("placed_fields"):
			var field := node as PlacedField
			if field == null or field == self or field.is_in_group("null_fields"):
				continue
			if field.global_position.distance_to(global_position) <= radius:
				field.destroy()
