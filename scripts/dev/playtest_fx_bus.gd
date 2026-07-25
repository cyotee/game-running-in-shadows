# PlaytestFxBus (autoload) — presentation-only multiplayer FX channel + combat log.
# Never touches netfox rollback state. Host-forced session policy for playtest viz.
extends Node

var _session_active: bool = false
var _session_viz_on: bool = false
var _log: PackedStringArray = PackedStringArray()
## Test hook: remote FX receive counter.
var _test_remote_fx_count: int = 0


func reset_for_tests() -> void:
	_session_active = false
	_session_viz_on = false
	_log.clear()
	_test_remote_fx_count = 0


func session_active() -> bool:
	return _session_active


func session_viz_on() -> bool:
	return _session_viz_on


## Host (or tests) apply forced session policy.
func apply_host_policy(forced: bool, viz_on: bool) -> void:
	_session_active = forced
	_session_viz_on = forced and viz_on


func host_publish_policy() -> void:
	if not _is_host():
		return
	var forced := MatchConfig.get_value("debug.viz.host_force_session") > 0.5
	var on := MatchConfig.get_value("debug.playtest_viz") > 0.5
	apply_host_policy(forced, on)
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	_sync_policy.rpc(forced, on)


@rpc("authority", "call_remote", "reliable")
func _sync_policy(forced: bool, on: bool) -> void:
	apply_host_policy(forced, on)


func log_lines() -> PackedStringArray:
	return _log


func push_log(text: String) -> void:
	_push_log(text)


func notify_hitscan(
		owner_peer: int,
		from: Vector3,
		to: Vector3,
		zone: String,
		damage: float,
		hit_player: bool,
		weapon_key: String
) -> void:
	if not PlaytestViz.enabled():
		return
	var label := weapon_key if weapon_key != "" else "hitscan"
	if hit_player:
		_push_log("%s %s %.0f" % [label, zone if zone != "" else "body", damage])
	else:
		_push_log("%s miss" % label)
	if MatchConfig.get_value("debug.viz.replicate") <= 0.5:
		return
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	_send_hitscan.rpc(owner_peer, from, to, zone, damage, hit_player, weapon_key)


@rpc("any_peer", "call_remote", "unreliable")
func _send_hitscan(
		owner_peer: int,
		from: Vector3,
		to: Vector3,
		zone: String,
		damage: float,
		hit_player: bool,
		weapon_key: String
) -> void:
	if not PlaytestViz.enabled():
		return
	if owner_peer == multiplayer.get_unique_id():
		return
	_test_remote_fx_count += 1
	var col := PlaytestViz.zone_tracer_color(zone, hit_player)
	PlaytestViz.flash_line(get_tree(), from, to, col)
	PlaytestViz.flash_muzzle(get_tree(), from)
	if hit_player and damage > 0.0:
		PlaytestViz.flash_hit_marker(get_tree(), to, damage, zone if zone != "" else "body")
	var label := weapon_key if weapon_key != "" else "hitscan"
	if hit_player:
		_push_log("%s %s %.0f (p%d)" % [label, zone, damage, owner_peer])
	else:
		_push_log("%s miss (p%d)" % [label, owner_peer])


func notify_generic(kind: StringName, payload: Dictionary) -> void:
	if not PlaytestViz.enabled():
		return
	_push_log("%s" % String(kind))
	if MatchConfig.get_value("debug.viz.replicate") <= 0.5:
		return
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	_send_generic.rpc(String(kind), payload)


@rpc("any_peer", "call_remote", "unreliable")
func _send_generic(kind: String, payload: Dictionary) -> void:
	if not PlaytestViz.enabled():
		return
	_test_remote_fx_count += 1
	_push_log("%s (remote)" % kind)
	match kind:
		"slip":
			var from: Vector3 = payload.get("from", Vector3.ZERO)
			var to: Vector3 = payload.get("to", Vector3.ZERO)
			PlaytestViz.flash_line(get_tree(), from, to, Color(0.2, 1.0, 0.4, 0.7))
			PlaytestViz.flash_slip_ghost(get_tree(), to)
		_:
			pass


func _push_log(text: String) -> void:
	_log.append(text)
	var cap := int(MatchConfig.get_value("debug.viz.combat_log_lines"))
	if cap < 1:
		cap = 1
	while _log.size() > cap:
		_log.remove_at(0)


func _is_host() -> bool:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return true
	return multiplayer.is_server()
