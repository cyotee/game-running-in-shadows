# CTF variable objective item (G8). Host-authoritative plain state: the flag
# is a world object peers simulate positionally via host RPC snapshots, not
# rollback state. Ticks via NetworkTime.on_tick (wired in _ready) so follow,
# drop-on-death, return timer, and capture run in shipped scenes — not only tests.
class_name CtfObjective
extends Node3D

signal captured(team: int)
signal picked_up(peer: int)
signal dropped(peer: int)

var home_pos: Vector3 = Vector3.ZERO
var carrier_peer: int = 0
var at_home: bool = true
var drop_ticks_left: int = 0
var team_scores: Array[int] = [0, 0]

var _match_state: MatchState
var _tick_connected: bool = false


func _ready() -> void:
	add_to_group("ctf_objective")
	home_pos = global_position
	_ensure_tick_connection()
	call_deferred("_try_auto_setup")


func _ensure_tick_connection() -> void:
	if _tick_connected:
		return
	if not NetworkTime.on_tick.is_connected(_on_network_tick):
		NetworkTime.on_tick.connect(_on_network_tick)
	_tick_connected = true


func _on_network_tick(_delta: float, tick: int) -> void:
	process_tick(tick)


func _try_auto_setup() -> void:
	if _match_state != null:
		return
	var ms := get_tree().get_first_node_in_group("match_state") as MatchState
	if ms == null:
		# Offline CTF maps may ship without a MatchSession — create one.
		ms = MatchState.new()
		ms.name = "MatchState"
		var host := get_parent()
		if host == null:
			host = get_tree().current_scene
		if host != null:
			host.add_child(ms)
		else:
			add_child(ms)
		if ms.is_authority():
			# Peer 1 is the offline local player (arena / map bootstrap).
			ms.assign_team(1)
	setup(ms)


func setup(match_state: MatchState) -> void:
	_match_state = match_state
	_ensure_tick_connection()


func is_authority() -> bool:
	return multiplayer.multiplayer_peer == null \
		or multiplayer.multiplayer_peer is OfflineMultiplayerPeer \
		or multiplayer.is_server()


func try_pickup(player: FPSController) -> void:
	if not is_authority() or carrier_peer != 0 or player == null or player.is_dead:
		return
	var r := MatchConfig.get_value("ctf.capture_radius_m")
	if global_position.distance_to(player.global_position) > r:
		return
	carrier_peer = player.input.get_multiplayer_authority()
	at_home = false
	drop_ticks_left = 0
	picked_up.emit(carrier_peer)
	_broadcast()


func try_drop() -> void:
	if not is_authority() or carrier_peer == 0:
		return
	var peer := carrier_peer
	carrier_peer = 0
	drop_ticks_left = int(roundf(
		MatchConfig.get_value("ctf.flag_return_s") * NetworkTime.tickrate))
	dropped.emit(peer)
	_broadcast()


func process_tick(_tick: int) -> void:
	if not is_authority():
		return
	if carrier_peer != 0:
		var carrier := _find_player(carrier_peer)
		if carrier == null or carrier.is_dead:
			try_drop()
			return
		global_position = carrier.global_position + Vector3(0, 1.6, 0)
		# Capture: bring the flag to this team's goal (return-to-base).
		var carrier_team := _match_state.team_of(carrier_peer) if _match_state != null else -1
		if carrier_team >= 0:
			var goal := home_pos
			var goal_node := get_tree().get_first_node_in_group("ctf_goal_%d" % carrier_team)
			if goal_node is Node3D:
				goal = (goal_node as Node3D).global_position
			if carrier.global_position.distance_to(goal) <= MatchConfig.get_value("ctf.capture_radius_m"):
				_score(carrier_team)
		return
	if not at_home and drop_ticks_left > 0:
		drop_ticks_left -= 1
		if drop_ticks_left <= 0:
			_return_home()


func _score(team: int) -> void:
	if team < 0 or team >= team_scores.size():
		return
	team_scores[team] += 1
	captured.emit(team)
	carrier_peer = 0
	_return_home()
	var win := int(MatchConfig.get_value("ctf.score_to_win"))
	if team_scores[team] >= win and _match_state != null and _match_state.is_authority():
		_match_state.winning_team = team
		_match_state.phase = MatchState.MATCH_END
		_match_state.match_ended.emit(team)


func _return_home() -> void:
	global_position = home_pos
	at_home = true
	drop_ticks_left = 0
	_broadcast()


func _find_player(peer: int) -> FPSController:
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as FPSController
		if p != null and p.input.get_multiplayer_authority() == peer:
			return p
	return null


func _broadcast() -> void:
	if not is_authority():
		return
	if multiplayer.multiplayer_peer != null \
			and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_sync.rpc(global_position, carrier_peer, at_home, drop_ticks_left, team_scores)


@rpc("authority", "call_remote", "reliable")
func _sync(pos: Vector3, carrier: int, home: bool, drop_left: int, scores: Array) -> void:
	global_position = pos
	carrier_peer = carrier
	at_home = home
	drop_ticks_left = drop_left
	team_scores = [int(scores[0]), int(scores[1])] if scores.size() >= 2 else [0, 0]
