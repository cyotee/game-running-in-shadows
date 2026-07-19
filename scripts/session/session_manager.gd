# Session lifecycle state machine (lobby <-> peer <-> scene).
# Owns multiplayer.multiplayer_peer for Steam sessions: gameplay code never
# touches the peer directly. All Steam calls go through lobby_service
# (SteamLobbyService), which tests replace with a fake.
extends Node

signal state_changed(state: int)
signal lobby_list_ready(entries: Array)
signal session_error(message: String)

enum { IDLE, HOSTING_LOBBY, IN_LOBBY, CONNECTING, IN_MATCH }

const MATCH_SCENE := "res://scenes/session/match_session.tscn"

var state: int = IDLE
var current_lobby_id: int = 0
var is_host: bool = false
var lobby_service: SteamLobbyService
var skip_peer_for_tests: bool = false

var _wired_service: SteamLobbyService


func _ready() -> void:
	if lobby_service == null:
		lobby_service = SteamLobbyService.new()
	_wire_service()


func _wire_service() -> void:
	if _wired_service == lobby_service or lobby_service == null:
		return
	_wired_service = lobby_service
	lobby_service.lobby_created.connect(_on_lobby_created)
	lobby_service.lobby_joined.connect(_on_lobby_joined)
	lobby_service.lobby_list.connect(func(entries: Array[Dictionary]) -> void:
		lobby_list_ready.emit(entries))
	lobby_service.lobby_join_failed.connect(_on_lobby_join_failed)


func _reset_for_tests() -> void:
	state = IDLE
	current_lobby_id = 0
	is_host = false
	skip_peer_for_tests = true
	_wire_service()


func steam_available() -> bool:
	return lobby_service != null and lobby_service.is_available()


func host(visibility: int) -> void:
	if state != IDLE:
		session_error.emit("cannot host from state %d" % state)
		return
	if not steam_available():
		session_error.emit("Steam unavailable")
		return
	is_host = true
	_set_state(HOSTING_LOBBY)
	lobby_service.create_lobby(
		visibility, int(MatchConfig.get_value("session.max_players")))


func join(lobby_id: int) -> void:
	if state != IDLE:
		session_error.emit("cannot join from state %d" % state)
		return
	if not steam_available():
		session_error.emit("Steam unavailable")
		return
	is_host = false
	_set_state(CONNECTING)
	lobby_service.join_lobby(lobby_id)


func browse(filters: Dictionary = {}) -> void:
	if not steam_available():
		session_error.emit("Steam unavailable")
		return
	lobby_service.request_list(filters)


func leave() -> void:
	lobby_service.leave_lobby(current_lobby_id)
	if multiplayer.multiplayer_peer != null \
			and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	current_lobby_id = 0
	is_host = false
	_set_state(IDLE)


func _set_state(new_state: int) -> void:
	state = new_state
	state_changed.emit(state)


func _on_lobby_created(lobby_id: int) -> void:
	if state != HOSTING_LOBBY:
		return
	current_lobby_id = lobby_id
	_set_state(IN_LOBBY)
	_start_networking(true)


func _on_lobby_joined(lobby_id: int) -> void:
	current_lobby_id = lobby_id
	if is_host:
		return  # host receives its own join callback; already networked
	_set_state(CONNECTING)
	_start_networking(false)


func _on_lobby_join_failed(reason: String) -> void:
	current_lobby_id = 0
	_set_state(IDLE)
	session_error.emit(reason)


func _start_networking(as_host: bool) -> void:
	if skip_peer_for_tests:
		return
	var peer := SteamMultiplayerPeer.new()
	var result: int
	if as_host:
		result = peer.create_host(0)
	else:
		result = peer.create_client(lobby_service.lobby_owner_id(current_lobby_id), 0)
	if result != OK:
		session_error.emit("peer setup failed (%d)" % result)
		leave()
		return
	multiplayer.multiplayer_peer = peer
	_set_state(IN_MATCH)
	get_tree().change_scene_to_file.call_deferred(MATCH_SCENE)
