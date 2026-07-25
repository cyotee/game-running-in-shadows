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
@onready var crosshair: Control = %Crosshair
@onready var combat_log_label: Label = get_node_or_null("%CombatLogLabel") as Label

const PING_EDGE_MARGIN := 24.0
## Distances (m) sampled along sim aim when projecting onto the active camera.
## First-person and third-person both use this so cast aim stays marked.
const CROSSHAIR_SAMPLE_DISTANCES: Array[float] = [
	200.0, 50.0, 20.0, 10.0, 5.0, 3.0, 1.5, 0.75,
]


static func format_combat_log_line(weapon_key: String, zone: String, damage: float) -> String:
	return "%s %s %.0f" % [weapon_key, zone, damage]


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
	_update_crosshair()
	_update_combat_log()


func _update_combat_log() -> void:
	if combat_log_label == null:
		return
	if not PlaytestViz.enabled():
		combat_log_label.visible = false
		return
	combat_log_label.visible = true
	var bus := get_node_or_null("/root/PlaytestFxBus")
	if bus != null and bus.has_method("log_lines"):
		combat_log_label.text = "\n".join(bus.call("log_lines"))
	else:
		combat_log_label.text = ""


# --- Crosshair (view-only; projects sim aim onto the *active* camera) ---
# Guns, Lifebloom/Tangle/Null, Familiar use camera origin + aim_yaw/aim_pitch.
# First-person: mark sits near screen center. Third-person (blade): mark sits
# where that same ray lands in the over-the-shoulder view — not camera center.

## World-space point the sim aims at this frame (surface hit or far fallback).
func _aim_world_point() -> Vector3:
	var from := _player.camera.global_position
	var aim := Basis(Vector3.UP, _player.input.aim_yaw) \
		* Basis(Vector3.RIGHT, _player.input.aim_pitch)
	var dir := aim * Vector3.FORWARD
	var to := from + dir * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b10011  # world + hit zones + tangle (same as hitscan)
	var excludes: Array[RID] = [_player.get_rid()]
	var hit_zones := _player.get_node_or_null("HitZones")
	if hit_zones != null:
		for zone_area: Area3D in hit_zones.get_children():
			excludes.append(zone_area.get_rid())
	query.exclude = excludes
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit["position"] as Vector3
	return from + dir * 20.0


## Screen point for sim aim under the active camera (FP or third-person).
## Always returns ok when a player + viewport camera exist — never drops the
## reticle just because the over-the-shoulder camera sees the ray differently.
func _aim_screen_point() -> Dictionary:
	var out := {"ok": false, "pos": Vector2.ZERO, "soft": false}
	if _player == null or not is_instance_valid(_player):
		return out
	# Prefer the camera actually drawing the frame (blade TP swaps current).
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		cam = _player.third_person_camera if _player.third_person_camera.current \
			else _player.camera
	if cam == null:
		return out
	var from := _player.camera.global_position
	var aim := Basis(Vector3.UP, _player.input.aim_yaw) \
		* Basis(Vector3.RIGHT, _player.input.aim_pitch)
	var dir := aim * Vector3.FORWARD
	var candidates: Array[Vector3] = [_aim_world_point()]
	for dist in CROSSHAIR_SAMPLE_DISTANCES:
		candidates.append(from + dir * dist)
	for world_pt in candidates:
		if cam.is_position_behind(world_pt):
			continue
		out["ok"] = true
		out["pos"] = cam.unproject_position(world_pt)
		out["soft"] = false
		return out
	# Ray is entirely behind the view camera (extreme TP angles): pin to the
	# screen edge in the aim direction so the cast mark never disappears.
	var fallback_pt := from + dir * 10.0
	var raw := cam.unproject_position(fallback_pt)
	out["ok"] = true
	out["pos"] = _clamp_crosshair_to_view(raw)
	out["soft"] = true
	return out


func _clamp_crosshair_to_view(pos: Vector2) -> Vector2:
	var rect := get_viewport().get_visible_rect()
	var center := rect.get_center()
	var margin := 28.0
	var usable := rect.grow(-margin)
	if usable.has_point(pos) and not _is_degenerate_unproject(pos, center):
		return pos
	var away := pos - center
	if away.length_squared() < 0.01:
		away = Vector2(0.0, -1.0)
	var radius := minf(usable.size.x, usable.size.y) * 0.5
	return center + away.normalized() * radius


func _is_degenerate_unproject(pos: Vector2, center: Vector2) -> bool:
	# Behind-camera unproject can collapse near the viewport origin/center oddly.
	return pos.x < -1000.0 or pos.y < -1000.0 \
		or pos.x > center.x * 4.0 or pos.y > center.y * 4.0


func _update_crosshair() -> void:
	if crosshair == null:
		return
	var target := _aim_screen_point()
	if not target["ok"]:
		crosshair.visible = false
		return
	crosshair.visible = true
	# Soft = edge-clamped (aim mostly off the third-person frustum).
	crosshair.modulate = Color(1.0, 1.0, 1.0, 0.55) if target["soft"] \
		else Color(1.0, 1.0, 1.0, 1.0)
	var half := crosshair.size * 0.5
	if half == Vector2.ZERO:
		half = Vector2(14.0, 14.0)
	var pos: Vector2 = target["pos"]
	crosshair.position = pos - half


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
