# Per-player money, wages, purchases, loadouts, and cybernetic slots.
# HOST-AUTHORITATIVE plain state (like MatchState): only the host mutates;
# money is synced to clients by RPC. Clients send exactly one RPC
# (request_buy / request_loadout); the host validates everything
# (anti-cheat Layer 1: phase, funds, slots — nothing client-reported).
class_name Economy
extends Node

signal money_changed(peer_id: int, amount: int)

# Body-slot map for cybernetic Augments (MECHANICS_REFERENCE §4: shared slots
# are mutually exclusive; cybernetics are PERMANENT once bought for the
# match). Weapons occupy no body slot. The G5 ability waves fill this in:
# e.g. "pulse_sight": ["eye"], "smart_rig": ["eye", "full_body"],
# "overclock_rig": ["full_body"].
const CYBER_SLOTS: Dictionary = {}

const DEFAULT_LOADOUT: Array[String] = ["rifle", "smg"]

var money: Dictionary = {}
var owned: Dictionary = {}  # peer_id -> {item: true}
var cyber_slots_used: Dictionary = {}  # peer_id -> {slot: item}
var round_kills: Dictionary = {}  # peer_id -> kills this round

var _match_state: MatchState
var _session: Node


func setup(session: Node, match_state: MatchState) -> void:
	_session = session
	_match_state = match_state


func is_authority() -> bool:
	return multiplayer.multiplayer_peer == null \
		or multiplayer.multiplayer_peer is OfflineMultiplayerPeer \
		or multiplayer.is_server()


func register_player(peer_id: int) -> void:
	if not is_authority() or money.has(peer_id):
		return
	money[peer_id] = int(MatchConfig.get_value("economy.start_money"))
	owned[peer_id] = {"pistol": true}
	cyber_slots_used[peer_id] = {}
	round_kills[peer_id] = 0
	_sync_money(peer_id)


func money_of(peer_id: int) -> int:
	return money.get(peer_id, 0)


func owns(peer_id: int, item: String) -> bool:
	return owned.get(peer_id, {}).has(item)


func note_kill(attacker_peer: int) -> void:
	if is_authority() and round_kills.has(attacker_peer):
		round_kills[attacker_peer] += 1


func award_round_wages(winning_team: int) -> void:
	if not is_authority():
		return
	var base := int(MatchConfig.get_value("economy.wage_base"))
	var win_bonus := int(MatchConfig.get_value("economy.wage_win_bonus"))
	var kill_bonus := int(MatchConfig.get_value("economy.kill_bonus"))
	for peer_id in money.keys():
		var wage: int = base + int(round_kills.get(peer_id, 0)) * kill_bonus
		if _match_state != null and winning_team >= 0 \
				and _match_state.team_of(peer_id) == winning_team:
			wage += win_bonus
		money[peer_id] += wage
		round_kills[peer_id] = 0
		_sync_money(peer_id)


func _cyber_slots_of(item: String) -> Array:
	# Overridable so tests (and future variants) can inject slot maps.
	return CYBER_SLOTS.get(item, [])


func try_buy(peer_id: int, item: String) -> bool:
	if not is_authority():
		return false
	if _match_state != null and _match_state.phase != MatchState.BUY_PHASE:
		return false
	if not money.has(peer_id) or owns(peer_id, item):
		return false
	var price := int(MatchConfig.get_value("price.%s" % item))
	if money[peer_id] < price:
		return false
	# Cybernetic slot exclusivity + permanence.
	var slots: Array = _cyber_slots_of(item)
	for slot in slots:
		if cyber_slots_used[peer_id].has(slot):
			return false
	for slot in slots:
		cyber_slots_used[peer_id][slot] = item
	money[peer_id] -= price
	owned[peer_id][item] = true
	_deliver(peer_id, item)
	_sync_money(peer_id)
	return true


func apply_loadout(peer_id: int, items: Array) -> void:
	# Shopping list (decided 2026-07-15): walk in priority order; skip owned;
	# skip unaffordable and CONTINUE down the list.
	if not is_authority():
		return
	for item in items:
		try_buy(peer_id, item)


func _deliver(peer_id: int, item: String) -> void:
	if _session == null:
		return
	var player: FPSController = _session.get_node_or_null("Players/%d" % peer_id)
	if player == null:
		return
	# Weapons: pistol -> slot 2, everything else -> slot 1. Non-weapon items
	# (cyber, abilities) deliver through their own systems in G5.
	if MatchConfig.DEFAULTS.has("weapon.%s.damage" % item):
		player.queue_grant(item, 2 if item == "pistol" else 1)


@rpc("any_peer", "call_remote", "reliable")
func request_buy(item: String) -> void:
	try_buy(multiplayer.get_remote_sender_id(), item)


@rpc("any_peer", "call_remote", "reliable")
func request_loadout(items: Array) -> void:
	apply_loadout(multiplayer.get_remote_sender_id(), items)


func _sync_money(peer_id: int) -> void:
	money_changed.emit(peer_id, money[peer_id])
	if multiplayer.multiplayer_peer != null \
			and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_sync_money_rpc.rpc(peer_id, money[peer_id])


@rpc("authority", "call_remote", "reliable")
func _sync_money_rpc(peer_id: int, amount: int) -> void:
	money[peer_id] = amount
	money_changed.emit(peer_id, amount)
