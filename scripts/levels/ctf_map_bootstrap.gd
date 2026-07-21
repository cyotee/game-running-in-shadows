# Offline CTF map bootstrap: starts NetworkTime, ensures MatchState is bound
# for the local peer, and wires CtfObjective.setup(match_state).
# Used by map_objective.tscn (standalone greybox CTF playtest scene).
extends Node3D


func _ready() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer:
		NetworkTime.start()
	var ms := get_node_or_null("MatchState") as MatchState
	if ms == null:
		ms = get_tree().get_first_node_in_group("match_state") as MatchState
	if ms == null:
		ms = MatchState.new()
		ms.name = "MatchState"
		add_child(ms)
	if ms.is_authority() and ms.team_of(1) < 0:
		ms.assign_team(1)
		ms.start_match()
	for node in get_tree().get_nodes_in_group("ctf_objective"):
		var flag := node as CtfObjective
		if flag != null:
			flag.setup(ms)
