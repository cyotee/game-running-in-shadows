# Persistent corpse. Spawned on death carrying the dead player's inventory
# snapshot; remains in the world after the owner respawns (full body
# persistence — decided). Lootable (grants a carried weapon) and draggable
# (follows the dragger, whose weapon use is restricted while dragging).
# Rollback-simulated so drag movement and loot state stay deterministic.
class_name Corpse
extends Node3D

# --- Rollback state ---
var w1_key: String = ""
var w1_mag: float = 0.0
var w1_reserve: float = 0.0
var w2_key: String = ""
var w2_mag: float = 0.0
var w2_reserve: float = 0.0
var grenades: int = 0
var dragged_by: int = 0  # peer dragging this corpse; 0 = none
var removed: bool = false

var owner_peer: int = 0
var spawn_tick: int = 0
var _freed: bool = false
# Reclaim consumes the corpse: the caster requests via this plain var; the
# corpse applies removal in its OWN tick (cross-node rollback-write lesson).
var _pending_reclaim_destroy: bool = false

@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer


func _ready() -> void:
	add_to_group("corpses")
	rollback_synchronizer.process_settings()


func init(spawn_position: Vector3, owner_id: int, tick: int, snapshot: Array) -> void:
	# snapshot = [w1_key, w1_mag, w1_reserve, w2_key, w2_mag, w2_reserve, grenades]
	position = spawn_position
	owner_peer = owner_id
	spawn_tick = tick
	w1_key = snapshot[0]
	w1_mag = snapshot[1]
	w1_reserve = snapshot[2]
	w2_key = snapshot[3]
	w2_mag = snapshot[4]
	w2_reserve = snapshot[5]
	grenades = snapshot[6]


func _process(_delta: float) -> void:
	if removed and not _freed:
		_freed = true
		queue_free()


func _rollback_tick(delta: float, _tick: int, _is_fresh: bool) -> void:
	if removed:
		return
	if _pending_reclaim_destroy:
		removed = true
		return
	if dragged_by != 0:
		var dragger := _find_player(dragged_by)
		var drag_range := MatchConfig.get_value("corpse.drag_range_m")
		if dragger == null or dragger.is_dead or not dragger.is_dragging \
				or global_position.distance_to(dragger.global_position) > drag_range * 2.0:
			dragged_by = 0
		else:
			var target := dragger.global_position + Vector3(0.0, 0.2, 0.0)
			global_position = global_position.move_toward(
				target, MatchConfig.get_value("corpse.drag_speed") * delta)


func loot_weapon() -> Dictionary:
	# Removes and returns the first carried weapon, or {} if empty.
	if w1_key != "":
		var w := {"key": w1_key, "mag": w1_mag, "reserve": w1_reserve}
		w1_key = ""
		NetworkRollback.mutate(self)
		return w
	if w2_key != "":
		var w := {"key": w2_key, "mag": w2_mag, "reserve": w2_reserve}
		w2_key = ""
		NetworkRollback.mutate(self)
		return w
	return {}


func set_dragged_by(peer: int) -> void:
	dragged_by = peer
	NetworkRollback.mutate(self)


func destroy() -> void:
	removed = true
	NetworkRollback.mutate(self)


func queue_reclaim_destroy() -> void:
	# Consumed by the corpse's own _rollback_tick (plain var — out-of-band writes
	# to plain vars persist; the in-tick removal mutates rollback state safely).
	_pending_reclaim_destroy = true


func _find_player(peer: int) -> FPSController:
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as FPSController
		if player != null and player.input.get_multiplayer_authority() == peer:
			return player
	return null
