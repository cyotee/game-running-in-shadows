# MultiplayerSpawner for thrown projectiles (grenades). Reconstructs a
# grenade from replicated spawn data on every peer, then each peer simulates
# it deterministically via the grenade's own RollbackSynchronizer.
# Spawn data: [position: Vector3, velocity: Vector3, fuse_ticks: int, owner: int].
extends MultiplayerSpawner

const GRENADE_SCENE := preload("res://scenes/weapons/grenade.tscn")


func _ready() -> void:
	add_to_group("projectile_spawner")
	spawn_function = _spawn_grenade


func throw_grenade(spawn_position: Vector3, launch_velocity: Vector3,
		fuse_ticks: int, owner_peer: int) -> void:
	spawn([spawn_position, launch_velocity, fuse_ticks, owner_peer])


func _spawn_grenade(data: Array) -> Node:
	var grenade: Grenade = GRENADE_SCENE.instantiate()
	grenade.launch(data[0], data[1], data[2], data[3])
	return grenade
