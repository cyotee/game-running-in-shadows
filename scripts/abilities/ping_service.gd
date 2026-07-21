# Aimed-ping intel service. Pings are comms/intel, NOT rollback-simulated
# gameplay: no press-ticks, no RollbackSynchronizer state. Host-authoritative
# via the economy.gd/match_state.gd RPC pattern; NetworkTime.tick is used only
# as a monotonic clock for expiry. Familiar (G5 W3) reads latest_enemy_tag().
extends Node

const WORLD: int = 0
const ENEMY: int = 1

var _pings: Array[Dictionary] = []
var _next_id: int = 1
var _match_state: MatchState = null


func setup(match_state: MatchState) -> void:
	_match_state = match_state


func reset() -> void:
	_pings.clear()
	_next_id = 1


func is_authority() -> bool:
	return multiplayer.multiplayer_peer == null \
		or multiplayer.multiplayer_peer is OfflineMultiplayerPeer \
		or multiplayer.is_server()


func _process(_delta: float) -> void:
	_cull(NetworkTime.tick)


# --- Request entry point (client -> host) ---

func request_ping(kind: int, world_pos: Vector3, target_peer: int) -> void:
	if is_authority():
		var owner := 1 if multiplayer.multiplayer_peer == null \
			else multiplayer.get_unique_id()
		_apply_ping(owner, kind, world_pos, target_peer)
	else:
		_request_ping_rpc.rpc_id(1, kind, world_pos, target_peer)


@rpc("any_peer", "call_remote", "reliable")
func _request_ping_rpc(kind: int, world_pos: Vector3, target_peer: int) -> void:
	_apply_ping(multiplayer.get_remote_sender_id(), kind, world_pos, target_peer)


# --- Host logic (also the test seam) ---

func _apply_ping(owner_peer: int, kind: int, world_pos: Vector3, target_peer: int) -> void:
	# Per-player limit (1): drop the owner's previous ping first.
	_remove_owned_by(owner_peer)
	var team := _match_state.team_of(owner_peer) if _match_state != null else -1
	var duration_ticks := int(roundf(
		MatchConfig.get_value("ping.duration_s") * NetworkTime.tickrate))
	var record := {
		"id": _next_id,
		"kind": kind,
		"owner_peer": owner_peer,
		"team": team,
		"world_pos": world_pos,
		"target_peer": target_peer,
		"expire_tick": NetworkTime.tick + duration_ticks,
	}
	_next_id += 1
	_pings.append(record)
	if not is_authority():
		return
	# Broadcast to remote peers when networked; local store already updated.
	if multiplayer.multiplayer_peer != null \
			and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_add_ping_rpc.rpc(record["id"], kind, owner_peer, team,
			world_pos, target_peer, record["expire_tick"])


@rpc("authority", "call_remote", "reliable")
func _add_ping_rpc(id: int, kind: int, owner_peer: int, team: int,
		world_pos: Vector3, target_peer: int, expire_tick: int) -> void:
	_remove_owned_by(owner_peer)
	_pings.append({
		"id": id, "kind": kind, "owner_peer": owner_peer, "team": team,
		"world_pos": world_pos, "target_peer": target_peer,
		"expire_tick": expire_tick,
	})


# --- Queries ---

func visible_pings(viewer_peer: int) -> Array:
	var viewer_team := _match_state.team_of(viewer_peer) if _match_state != null else -1
	var out: Array = []
	for record in _pings:
		if record["owner_peer"] == viewer_peer:
			out.append(record)
		elif record["team"] != -1 and record["team"] == viewer_team:
			out.append(record)
	return out


func latest_enemy_tag(owner_peer: int) -> int:
	for record in _pings:
		if record["owner_peer"] == owner_peer and record["kind"] == ENEMY:
			return record["target_peer"]
	return 0


func active_count() -> int:
	return _pings.size()


# --- Internals ---

func _remove_owned_by(owner_peer: int) -> void:
	for i in range(_pings.size() - 1, -1, -1):
		if _pings[i]["owner_peer"] == owner_peer:
			_pings.remove_at(i)


func _cull(now_tick: int) -> void:
	for i in range(_pings.size() - 1, -1, -1):
		if _pings[i]["expire_tick"] <= now_tick:
			_pings.remove_at(i)
