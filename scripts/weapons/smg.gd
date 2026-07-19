# Full-auto with bloom: spread grows per shot and decays over time.
class_name SmgWeapon
extends WeaponBase

# --- Rollback state ---
var bloom_deg: float = 0.0


func _wants_fire(_tick: int) -> bool:
	return _controller().input.fire_held


func _weapon_tick(delta: float, tick: int) -> void:
	# Decay only once sustained fire stops — otherwise decay (3 deg/s)
	# outpaces growth (0.15 deg x 12.5 shots/s) and bloom never accumulates.
	if NetworkTime.seconds_between(last_fire_tick, tick) > config("fire_interval_s"):
		bloom_deg = maxf(bloom_deg - config("bloom_decay_deg_s") * delta, 0.0)


func _on_fire_tick(_tick: int) -> void:
	bloom_deg = minf(bloom_deg + config("bloom_per_shot_deg"), config("bloom_max_deg"))


func _shot_directions(tick: int) -> Array[Vector3]:
	var seed_val := hash([tick, _controller().multiplayer.get_unique_id(), weapon_key])
	var rng := rand_from_seed(seed_val)
	var angle := deg_to_rad(bloom_deg) * (float(rng[0] % 1000) / 1000.0)
	var roll := TAU * (float(rand_from_seed(rng[1])[0] % 1000) / 1000.0)
	var dir := _aim_basis() * Vector3.FORWARD
	return [dir.rotated(_aim_basis() * Vector3.UP, angle * cos(roll))
		.rotated(_aim_basis() * Vector3.RIGHT, angle * sin(roll))]
