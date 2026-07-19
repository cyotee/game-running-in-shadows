# Round/match flow state machine. HOST-AUTHORITATIVE plain state (not
# rollback state): only the host mutates it, and every change is replicated
# to clients as an RPC snapshot — match flow is not per-tick predicted
# gameplay. Timers count NetworkTime ticks.
#
# Anti-cheat Layer 1: clients send nothing; death derives from
# server-simulated health; scoring/respawn are host-only paths.
class_name MatchState
extends Node

signal phase_changed(phase: int)
signal scores_changed(team_scores: Array, round_wins: Array)
signal match_ended(winning_team: int)

enum { BUY_PHASE, ROUND_LIVE, ROUND_END, MATCH_END }

var phase: int = BUY_PHASE
var phase_end_tick: int = 0
var round_number: int = 1
var team_of_peer: Dictionary = {}
var team_kills: Array[int] = [0, 0]
var round_wins: Array[int] = [0, 0]
var winning_team: int = -1

var _session: Node


func setup(session: Node) -> void:
	_session = session


func is_authority() -> bool:
	return multiplayer.multiplayer_peer == null \
		or multiplayer.multiplayer_peer is OfflineMultiplayerPeer \
		or multiplayer.is_server()


func start_match() -> void:
	if not is_authority():
		return
	round_number = 1
	team_kills = [0, 0]
	round_wins = [0, 0]
	winning_team = -1
	_enter_phase(BUY_PHASE)


func assign_team(peer_id: int) -> int:
	# Round-robin by join order; host-only.
	var team := team_of_peer.size() % int(MatchConfig.get_value("match.team_count"))
	team_of_peer[peer_id] = team
	return team


func team_of(peer_id: int) -> int:
	return team_of_peer.get(peer_id, -1)


func record_kill(victim_peer: int, attacker_peer: int) -> void:
	if not is_authority() or phase != ROUND_LIVE:
		return
	var attacker_team := team_of(attacker_peer)
	var victim_team := team_of(victim_peer)
	# No points for suicides/unknowns or team kills.
	if attacker_team >= 0 and attacker_team != victim_team:
		team_kills[attacker_team] += 1
		_broadcast()
	_check_elimination()


func process_tick(tick: int) -> void:
	if not is_authority() or phase == MATCH_END:
		return
	if tick < phase_end_tick:
		return
	match phase:
		BUY_PHASE:
			_enter_phase(ROUND_LIVE)
		ROUND_LIVE:
			_end_round(_leading_team())
		ROUND_END:
			round_number += 1
			_enter_phase(BUY_PHASE)


func _enter_phase(new_phase: int) -> void:
	phase = new_phase
	var duration_key: String
	match new_phase:
		BUY_PHASE:
			duration_key = "match.buy_phase_s"
			_reset_round()
		ROUND_LIVE:
			duration_key = "match.round_time_s"
		ROUND_END:
			duration_key = "match.round_end_s"
		_:
			duration_key = ""
	if duration_key != "":
		phase_end_tick = NetworkTime.tick + int(roundf(
			MatchConfig.get_value(duration_key) * NetworkTime.tickrate))
	phase_changed.emit(phase)
	_broadcast()


func _reset_round() -> void:
	if _session != null:
		_session.promote_all_spectators()
		_session.reset_players_for_round()


func _leading_team() -> int:
	# Timer expiry: more kills wins the round; tie -> no point (-1).
	if team_kills[0] == team_kills[1]:
		return -1
	return 0 if team_kills[0] > team_kills[1] else 1


func _check_elimination() -> void:
	if _session == null or phase != ROUND_LIVE:
		return
	var alive: Array[int] = [0, 0]
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_dead:
			continue
		var team := team_of(player.input.get_multiplayer_authority())
		if team >= 0:
			alive[team] += 1
	# Only meaningful with both teams populated.
	var populated := 0
	for team in team_of_peer.values():
		populated |= (1 << team)
	if populated != 0b11:
		return
	if alive[0] == 0 or alive[1] == 0:
		_end_round(0 if alive[1] == 0 else 1)


func _end_round(round_winner: int) -> void:
	if round_winner >= 0:
		round_wins[round_winner] += 1
		scores_changed.emit(team_kills, round_wins)
	if round_winner >= 0 \
			and round_wins[round_winner] >= int(MatchConfig.get_value("match.rounds_to_win")):
		winning_team = round_winner
		phase = MATCH_END
		phase_changed.emit(phase)
		match_ended.emit(winning_team)
		_broadcast()
		return
	_enter_phase(ROUND_END)


func _broadcast() -> void:
	if multiplayer.multiplayer_peer == null \
			or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	_sync_state.rpc(phase, phase_end_tick, round_number, team_of_peer,
		team_kills, round_wins, winning_team)


@rpc("authority", "call_remote", "reliable")
func _sync_state(p_phase: int, p_end: int, p_round: int, p_teams: Dictionary,
		p_kills: Array, p_wins: Array, p_winner: int) -> void:
	phase = p_phase
	phase_end_tick = p_end
	round_number = p_round
	team_of_peer = p_teams
	team_kills.assign(p_kills)
	round_wins.assign(p_wins)
	winning_team = p_winner
	phase_changed.emit(phase)
	scores_changed.emit(team_kills, round_wins)
