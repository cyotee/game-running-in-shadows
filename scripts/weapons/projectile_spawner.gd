# MultiplayerSpawner for thrown projectiles and placed fields. Reconstructs
# the entity from replicated spawn data on every peer, then each peer
# simulates it deterministically via the entity's own RollbackSynchronizer.
#
# Spawn data is [kind, ...args]:
#   ["grenade", position, velocity, fuse_ticks, owner]
#   ["<field>", position, caster]   (field = lifebloom / tangle / null_charge)
extends MultiplayerSpawner

const GRENADE_SCENE := preload("res://scenes/weapons/grenade.tscn")

const FIELD_SCENES := {
	"lifebloom": "res://scenes/abilities/lifebloom.tscn",
	"tangle": "res://scenes/abilities/tangle.tscn",
	"null_charge": "res://scenes/abilities/null_charge.tscn",
}

const FIELD_CONFIG := {
	"lifebloom": ["ability.lifebloom_hp", "ability.lifebloom_lifetime_s"],
	"tangle": ["ability.tangle_hp", "ability.tangle_lifetime_s"],
	"null_charge": ["ability.null_hp", "ability.null_lifetime_s"],
}


func _ready() -> void:
	add_to_group("projectile_spawner")
	spawn_function = _spawn


func throw_grenade(spawn_position: Vector3, launch_velocity: Vector3,
		fuse_ticks: int, owner_peer: int) -> void:
	spawn(["grenade", spawn_position, launch_velocity, fuse_ticks, owner_peer])


const CORPSE_SCENE := preload("res://scenes/abilities/corpse.tscn")


func place_field(kind: String, spawn_position: Vector3, caster_peer: int) -> void:
	spawn([kind, spawn_position, caster_peer])


func spawn_corpse(spawn_position: Vector3, owner_peer: int, tick: int, snapshot: Array) -> void:
	# Flat primitives only — MultiplayerSpawner serializes the spawn data.
	# snapshot = [w1_key, w1_mag, w1_reserve, w2_key, w2_mag, w2_reserve, grenades]
	spawn(["corpse", spawn_position, owner_peer, tick] + snapshot)


func _spawn(data: Array) -> Node:
	var kind: String = data[0]
	if kind == "grenade":
		var grenade: Grenade = GRENADE_SCENE.instantiate()
		grenade.launch(data[1], data[2], data[3], data[4])
		return grenade
	if kind == "corpse":
		var corpse: Corpse = CORPSE_SCENE.instantiate()
		corpse.init(data[1], data[2], data[3], data.slice(4))
		return corpse
	var field: PlacedField = (load(FIELD_SCENES[kind]) as PackedScene).instantiate()
	var cfg: Array = FIELD_CONFIG[kind]
	field.setup(data[1], data[2], MatchConfig.get_value(cfg[0]),
		int(roundf(MatchConfig.get_value(cfg[1]) * NetworkTime.tickrate)))
	return field
