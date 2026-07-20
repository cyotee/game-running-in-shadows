# Player HUD (functional/debug-grade — art pass is Milestone D).
# Binds to the local player's FPSController; all reads are view-only.
# Works in both the test arena and match_session: panels that need
# MatchState self-hide when it is absent.
class_name PlayerHud
extends CanvasLayer

const FEED_LIMIT := 4

var _player: FPSController
var _match_state: MatchState
var _denial_ticks_left := 0.0
var _feed: Array[String] = []

@onready var status_label: Label = %StatusLabel
@onready var denial_label: Label = %DenialLabel
@onready var feed_label: Label = %FeedLabel
@onready var scoreboard_label: Label = %ScoreboardLabel


static func format_pips(current: float, max_resonance: float, cap: float) -> String:
	# MECHANICS_REFERENCE §2 decided semantics: filled / partial / empty
	# pips, with reserved capacity visually locked at the top of the pool.
	var pips := ""
	var whole := int(floorf(current))
	var frac := current - float(whole)
	for i in range(int(roundf(max_resonance))):
		if i < whole:
			pips += "●"
		elif i == whole and frac > 0.05:
			pips += "◐"
		elif i >= int(roundf(cap)):
			pips += "▣"
		else:
			pips += "○"
	return pips


func bind(player: FPSController) -> void:
	_player = player
	player.cast_denied.connect(func() -> void: _denial_ticks_left = 1.2)


func bind_match_state(match_state: MatchState) -> void:
	_match_state = match_state


func note_kill(victim_peer: int, attacker_peer: int) -> void:
	_feed.append("%d ✖ %d" % [attacker_peer, victim_peer])
	while _feed.size() > FEED_LIMIT:
		_feed.pop_front()
	feed_label.text = "\n".join(_feed)


func _try_autobind() -> void:
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as FPSController
		if player != null \
				and player.input.get_multiplayer_authority() == multiplayer.get_unique_id():
			bind(player)
			return


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = null
		_try_autobind()
		if _player == null:
			status_label.text = "no player"
			return
	var pool := _player.resonance
	var tick := NetworkTime.tick
	var text := "Resonance %s  %.1f/%.0f\nHealth %.0f%s" % [
		format_pips(pool.current, pool.max_resonance, pool.cap()),
		pool.current, pool.max_resonance, _player.health,
		"   ⚔ in combat" if pool.is_in_combat(tick) else ""]
	var weapon := _player.weapon_rig.active_weapon()
	if weapon != null:
		if weapon.weapon_key == "blade":
			text += "\nblade"
		else:
			text += "\n%s  %d / %d%s" % [weapon.weapon_key, int(weapon.mag),
				int(weapon.reserve),
				" (reloading)" if weapon.is_reloading(tick) else ""]
	if _player.is_dead:
		text += "\nDOWN — round reset revives"
	status_label.text = text

	_denial_ticks_left = maxf(_denial_ticks_left - delta, 0.0)
	denial_label.visible = _denial_ticks_left > 0.0

	var show_scores := Input.is_action_pressed("scoreboard") and _match_state != null
	scoreboard_label.visible = show_scores
	if show_scores:
		scoreboard_label.text = "Round %d\nKills %d : %d\nRounds %d : %d" % [
			_match_state.round_number,
			_match_state.team_kills[0], _match_state.team_kills[1],
			_match_state.round_wins[0], _match_state.round_wins[1]]
