# Debug match-flow readout for match_session (real HUD arrives with G4).
extends Label

const PHASE_NAMES := ["BUY PHASE", "ROUND LIVE", "ROUND END", "MATCH END"]

var _state: MatchState


func _ready() -> void:
	_state = get_node_or_null("../../MatchState") as MatchState


func _process(_delta: float) -> void:
	if _state == null:
		text = "match: no state"
		return
	var remaining := maxf(0.0,
		float(_state.phase_end_tick - NetworkTime.tick) / NetworkTime.tickrate)
	text = "Round %d — %s (%.0fs)\nKills %d : %d   Rounds %d : %d" % [
		_state.round_number, PHASE_NAMES[_state.phase], remaining,
		_state.team_kills[0], _state.team_kills[1],
		_state.round_wins[0], _state.round_wins[1]]
	if _state.phase == MatchState.MATCH_END:
		text += "\nWINNER: TEAM %d" % _state.winning_team
