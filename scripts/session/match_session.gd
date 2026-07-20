# Networked match scene: spawns one FPSController per peer (16 max),
# tracks late joiners as spectators until promoted. Round boundaries arrive
# with the round-flow plan — until then the host can promote all waiting
# spectators with the dev_promote debug action (F9).
extends Node3D

signal late_joiner_waiting(peer_id: int)

const PLAYER_SCENE := "res://scenes/player/fps_controller.tscn"

var _spectators: Dictionary = {}
var _match_started := false

@onready var spawner: MultiplayerSpawner = $Players/MultiplayerSpawner
@onready var spawn_points: Node3D = $SpawnPoints
@onready var spectator_camera: Camera3D = $SpectatorCamera
@onready var match_state: MatchState = $MatchState
@onready var economy: Economy = $Economy

var _spawn_index := 0


func _ready() -> void:
	spawner.spawn_function = _spawn_player
	match_state.setup(self)
	economy.setup(self, match_state)
	$PlayerHud.bind_match_state(match_state)
	match_state.round_ended.connect(economy.award_round_wages)
	NetworkTime.on_tick.connect(func(_delta: float, tick: int) -> void:
		match_state.process_tick(tick))
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer:
		# Offline dev path: run the tick loop locally, spawn player 1.
		NetworkTime.start()
		_match_started = true
		match_state.assign_team(1)
		_do_spawn(1)
		match_state.start_match()
		return
	if multiplayer.is_server():
		_match_started = true
		match_state.assign_team(multiplayer.get_unique_id())
		_do_spawn(multiplayer.get_unique_id())
		for peer_id in multiplayer.get_peers():
			_admit_peer(peer_id)
		multiplayer.peer_connected.connect(_admit_peer)
		multiplayer.peer_disconnected.connect(_despawn)
		match_state.start_match()


func _admit_peer(peer_id: int) -> void:
	var player_count := get_tree().get_nodes_in_group("players").size()
	if player_count >= int(MatchConfig.get_value("session.max_players")):
		push_warning("MatchSession: rejecting peer %d (session full)" % peer_id)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	match_state.assign_team(peer_id)
	if _match_started and _spawn_index > 0:
		_register_late_joiner(peer_id)
	else:
		_do_spawn(peer_id)


func _register_late_joiner(peer_id: int) -> void:
	_spectators[peer_id] = true
	late_joiner_waiting.emit(peer_id)


func is_spectator(peer_id: int) -> bool:
	return _spectators.has(peer_id)


func promote_spectator(peer_id: int) -> void:
	if not _spectators.has(peer_id):
		return
	_spectators.erase(peer_id)
	_do_spawn(peer_id)


func _do_spawn(peer_id: int) -> void:
	spawner.spawn(peer_id)
	_spawn_index += 1


func _despawn(peer_id: int) -> void:
	_spectators.erase(peer_id)
	var node := get_node_or_null("Players/%d" % peer_id)
	if node:
		node.queue_free()


func _spawn_player(peer_id: int) -> Node:
	var player: FPSController = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.name = str(peer_id)
	# Economy mode: pistol only at spawn; everything else is bought.
	player.default_slot1 = ""
	var point_count := spawn_points.get_child_count()
	var point: Marker3D = spawn_points.get_child(_spawn_index % point_count)
	player.position = point.position
	player.get_node("Input").set_multiplayer_authority(peer_id)
	player.died.connect(match_state.record_kill)
	player.died.connect(func(_victim: int, attacker: int) -> void:
		economy.note_kill(attacker))
	player.died.connect($PlayerHud.note_kill)
	economy.register_player(peer_id)
	return player


func promote_all_spectators() -> void:
	for peer_id in _spectators.keys():
		promote_spectator(peer_id)


func reset_players_for_round() -> void:
	var index := 0
	var point_count := spawn_points.get_child_count()
	for player in get_tree().get_nodes_in_group("players"):
		var point: Marker3D = spawn_points.get_child(index % point_count)
		player.reset_for_round(point.global_position)
		index += 1


func _unhandled_input(event: InputEvent) -> void:
	# Debug promotion until the round-flow plan owns round boundaries.
	if event.is_action_pressed("dev_promote") and multiplayer.is_server():
		for peer_id in _spectators.keys():
			promote_spectator(peer_id)
