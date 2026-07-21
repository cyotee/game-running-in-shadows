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
@onready var ping_layer: Control = %PingLayer

const PING_EDGE_MARGIN := 24.0


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

	_render_pings()


# --- Ping markers (view-only HUD projection; PingService is the source) ---

func _ping_screen_target(record: Dictionary) -> Dictionary:
	var out := {"visible": false, "pos": Vector2.ZERO, "behind": true, "distance": 0.0}
	if _player == null or not is_instance_valid(_player):
		return out
	var cam := _player.camera
	var world_pos: Vector3 = record["world_pos"]
	if record["kind"] == PingService.ENEMY:
		var enemy := _find_player(record["target_peer"])
		if enemy == null or enemy.is_dead or enemy.is_wraithed:
			return out  # unrenderable this frame (dead / hidden)
		world_pos = enemy.global_position + Vector3(0.0, 1.5, 0.0)
	out["distance"] = cam.global_position.distance_to(world_pos)
	out["behind"] = cam.is_position_behind(world_pos)
	out["pos"] = cam.unproject_position(world_pos)
	out["visible"] = not out["behind"]
	return out


func _find_player(peer: int) -> FPSController:
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as FPSController
		if p != null and p.input.get_multiplayer_authority() == peer:
			return p
	return null


func _render_pings() -> void:
	if ping_layer == null:
		return
	for child in ping_layer.get_children():
		child.queue_free()
	if _player == null or not is_instance_valid(_player):
		return
	var local_peer := _player.input.get_multiplayer_authority()
	var rect := ping_layer.get_rect()
	for record in PingService.visible_pings(local_peer):
		var target := _ping_screen_target(record)
		var pos: Vector2 = target["pos"]
		if not target["visible"]:
			# Off-screen / behind: clamp to the nearest screen edge.
			if target["behind"]:
				pos = rect.get_center() + (rect.get_center() - pos)
			pos = pos.clamp(
				Vector2(PING_EDGE_MARGIN, PING_EDGE_MARGIN),
				rect.size - Vector2(PING_EDGE_MARGIN, PING_EDGE_MARGIN))
		var label := Label.new()
		var glyph := "[!]" if record["kind"] == PingService.ENEMY else "[x]"
		label.text = "%s %dm" % [glyph, int(target["distance"])]
		label.position = pos
		ping_layer.add_child(label)
