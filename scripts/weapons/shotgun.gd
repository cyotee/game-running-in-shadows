# Pellet cone: total damage emerges from pellets that connect.
class_name ShotgunWeapon
extends WeaponBase


func _shot_directions(tick: int) -> Array[Vector3]:
	var dirs: Array[Vector3] = []
	var forward := _aim_basis() * Vector3.FORWARD
	var up := _aim_basis() * Vector3.UP
	var right := _aim_basis() * Vector3.RIGHT
	var cone := deg_to_rad(config("cone_deg"))
	for i in range(int(config("pellets"))):
		var s := rand_from_seed(hash([tick, _controller().multiplayer.get_unique_id(), weapon_key, i]))
		var angle := cone * (float(s[0] % 1000) / 1000.0)
		var roll := TAU * (float(rand_from_seed(s[1])[0] % 1000) / 1000.0)
		dirs.append(forward.rotated(up, angle * cos(roll)).rotated(right, angle * sin(roll)))
	return dirs
