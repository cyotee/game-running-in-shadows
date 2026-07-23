# Per-player money, wages, purchases, loadouts, and cybernetic slots.
# HOST-AUTHORITATIVE plain state (like MatchState): only the host mutates;
# money is synced to clients by RPC. Clients send exactly one RPC
# (request_buy / request_loadout); the host validates everything
# (anti-cheat Layer 1: phase, funds, slots — nothing client-reported).
class_name Economy
extends Node

signal money_changed(peer_id: int, amount: int)

# Body-slot map for cybernetic Augments (MECHANICS_REFERENCE §4: shared slots
# are mutually exclusive; cybernetics are permanent in real matches).
# Dev arsenal can refund to free slots for kit swapping in the test arena.
const CYBER_SLOTS: Dictionary = {
	"pulse_sight": ["eye"],
	"smart_rig": ["eye", "full_body"],
	"overclock": ["full_body"],
}

const DEFAULT_LOADOUT: Array[String] = ["rifle", "smg"]

# Catalog keys the buy menu / tests know about (weapons + priced abilities).
const CATALOG: Array[String] = [
	"pistol", "smg", "shotgun", "rifle", "sniper", "blade",
	"slip", "wraith", "grenades", "lifebloom", "tangle", "null_charge",
	"reclaim", "familiar", "pulse_sight", "smart_rig", "overclock",
]

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


func try_buy(peer_id: int, item: String, ignore_phase: bool = false) -> bool:
	if not is_authority():
		return false
	if not ignore_phase and _match_state != null \
			and _match_state.phase != MatchState.BUY_PHASE:
		return false
	if not money.has(peer_id) or owns(peer_id, item):
		return false
	# Unknown catalog keys are not for sale (avoids free buy on typos).
	var price_key := "price.%s" % item
	if not MatchConfig.DEFAULTS.has(price_key):
		return false
	var price := int(MatchConfig.get_value(price_key))
	if money[peer_id] < price:
		return false
	# Cybernetic slot exclusivity + permanence (dev refund can free slots).
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


## Dev / test: grant funds without a wage event.
func give_money(peer_id: int, amount: int) -> void:
	if not is_authority() or amount == 0:
		return
	if not money.has(peer_id):
		register_player(peer_id)
	money[peer_id] = maxi(0, money[peer_id] + amount)
	_sync_money(peer_id)


## Dev / test: refund a purchase so a replacement can be bought.
## Refunds list price, frees cyber slots, and clears weapon slots that hold the item.
func refund(peer_id: int, item: String, refund_cash: bool = true) -> bool:
	if not is_authority() or not owns(peer_id, item):
		return false
	if item == "pistol":
		return false  # free sidearm is always owned in MVP
	if refund_cash and MatchConfig.DEFAULTS.has("price.%s" % item):
		money[peer_id] = money.get(peer_id, 0) + int(MatchConfig.get_value("price.%s" % item))
	owned[peer_id].erase(item)
	if cyber_slots_used.has(peer_id):
		var used: Dictionary = cyber_slots_used[peer_id]
		var to_erase: Array = []
		for slot in used.keys():
			if used[slot] == item:
				to_erase.append(slot)
		for slot in to_erase:
			used.erase(slot)
	_undeliver(peer_id, item)
	_sync_money(peer_id)
	return true


func apply_loadout(peer_id: int, items: Array) -> void:
	# Shopping list (decided 2026-07-15): walk in priority order; skip owned;
	# skip unaffordable and CONTINUE down the list.
	if not is_authority():
		return
	for item in items:
		try_buy(peer_id, item)


func _player_for(peer_id: int) -> FPSController:
	if _session != null:
		var from_session: FPSController = _session.get_node_or_null(
			"Players/%d" % peer_id) as FPSController
		if from_session != null:
			return from_session
	# Arena / offline: first matching authority player.
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as FPSController
		if p != null and p.input.get_multiplayer_authority() == peer_id:
			return p
	return null


func _deliver(peer_id: int, item: String) -> void:
	var player := _player_for(peer_id)
	if player == null:
		return
	# Weapons: pistol -> slot 2, everything else -> slot 1. Abilities/augments
	# are currently always-castable; ownership is tracked for buy/refund UX.
	if MatchConfig.DEFAULTS.has("weapon.%s.damage" % item):
		player.queue_grant(item, 2 if item == "pistol" else 1)
	elif item == "grenades":
		player.queue_set_grenade_stock(int(MatchConfig.get_value("ability.grenade_stock")))
	elif item == "null_charge":
		player.queue_set_null_stock(int(MatchConfig.get_value("ability.null_stock")))


func _undeliver(peer_id: int, item: String) -> void:
	var player := _player_for(peer_id)
	if player == null:
		return
	if MatchConfig.DEFAULTS.has("weapon.%s.damage" % item):
		player.queue_clear_weapon(item)
	elif item == "grenades":
		player.queue_set_grenade_stock(0)
	elif item == "null_charge":
		player.queue_set_null_stock(0)


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
