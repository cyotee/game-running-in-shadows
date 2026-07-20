# Rollback-simulated thrown grenade. Position / velocity / fuse / detonation
# are rollback state (registered on its own RollbackSynchronizer), so the
# ballistic path is deterministic and rollback-safe. Detonation AoE is a
# cross-player world side-effect — applied on fresh ticks only, like Repulse.
# Repulse-able in flight (FPSController._push_nearby_bodies nudges the
# "grenades" group). Full friendly fire (decided): hits everyone in radius.
class_name Grenade
extends Node3D

# --- Rollback state ---
var velocity: Vector3 = Vector3.ZERO
var fuse_ticks_left: int = 180
var detonated: bool = false

var owner_peer: int = 0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _freed: bool = false

@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer


func _ready() -> void:
	add_to_group("grenades")
	rollback_synchronizer.process_settings()


func _process(_delta: float) -> void:
	# Free once detonation is confirmed, in idle time — never during the
	# rollback loop (freeing a rolled-back node mid-loop is unsafe).
	if detonated and not _freed:
		_freed = true
		queue_free()


func launch(spawn_position: Vector3, launch_velocity: Vector3, fuse_ticks: int,
		thrower_peer: int) -> void:
	position = spawn_position
	velocity = launch_velocity
	fuse_ticks_left = fuse_ticks
	owner_peer = thrower_peer


func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if detonated:
		return

	velocity.y -= gravity * delta

	# Ballistic step with a raycast bounce against world geometry (layer 1).
	var motion := velocity * delta
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + motion)
	query.collision_mask = 0b1
	var hit := space.intersect_ray(query)
	if hit:
		var normal: Vector3 = hit.normal
		global_position = hit.position + normal * 0.05
		velocity = velocity.bounce(normal) * 0.5  # dampen on bounce
	else:
		global_position += motion

	fuse_ticks_left -= 1
	if fuse_ticks_left <= 0:
		detonated = true
		if is_fresh:
			_apply_aoe(tick)  # freed in _process once detonated (see above)


func _apply_aoe(tick: int) -> void:
	var radius := MatchConfig.get_value("ability.grenade_radius_m")
	var inner := MatchConfig.get_value("ability.grenade_inner_radius_m")
	var dmg := MatchConfig.get_value("ability.grenade_damage")
	var attacker := _find_thrower()
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as FPSController
		if player == null:
			continue
		var dist := player.global_position.distance_to(global_position)
		if dist > radius:
			continue
		var falloff := 1.0 if dist <= inner else 1.0 - (dist - inner) / (radius - inner)
		player.take_damage(dmg * falloff, attacker, tick)
		NetworkRollback.mutate(player)


func _find_thrower() -> FPSController:
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as FPSController
		if player != null and player.input.get_multiplayer_authority() == owner_peer:
			return player
	return null
