# Thin GodotSteam lobby wrapper. Every Steam call in the game goes through
# this interface so tests can inject a fake (see test_session_manager.gd)
# and CI stays green with no Steam client running.
class_name SteamLobbyService
extends RefCounted

signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_list(entries: Array[Dictionary])
signal lobby_join_failed(reason: String)

const VIS_FRIENDS := 1  # Steam.LOBBY_TYPE_FRIENDS_ONLY
const VIS_PUBLIC := 2  # Steam.LOBBY_TYPE_PUBLIC

const LOBBY_GAME_KEY := "game"
const LOBBY_GAME_VALUE := "counterspell"
const LOBBY_VERSION_KEY := "version"

var _wired := false


func _wire_signals() -> void:
	if _wired or not is_available():
		return
	_wired = true
	Steam.lobby_created.connect(_on_steam_lobby_created)
	Steam.lobby_joined.connect(_on_steam_lobby_joined)
	Steam.lobby_match_list.connect(_on_steam_lobby_match_list)
	Steam.join_requested.connect(func(lobby_id: int, _friend_id: int) -> void:
		join_lobby(lobby_id))


func is_available() -> bool:
	return ClassDB.class_exists("Steam") and Steam.isSteamRunning() \
		and Steam.loggedOn()


func create_lobby(visibility: int, max_members: int) -> void:
	_wire_signals()
	Steam.createLobby(visibility, max_members)


func join_lobby(lobby_id: int) -> void:
	_wire_signals()
	Steam.joinLobby(lobby_id)


func leave_lobby(lobby_id: int) -> void:
	if is_available() and lobby_id != 0:
		Steam.leaveLobby(lobby_id)


func request_list(_filters: Dictionary = {}) -> void:
	_wire_signals()
	# App ID 480 is shared with other test projects: filtering on our
	# game/version lobby data is mandatory, not cosmetic.
	Steam.addRequestLobbyListStringFilter(
		LOBBY_GAME_KEY, LOBBY_GAME_VALUE, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.addRequestLobbyListStringFilter(
		LOBBY_VERSION_KEY, _project_version(), Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()


func open_invite_overlay(lobby_id: int) -> void:
	if is_available() and lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(lobby_id)


func set_lobby_data(lobby_id: int, key: String, value: String) -> void:
	if is_available() and lobby_id != 0:
		Steam.setLobbyData(lobby_id, key, value)


func get_lobby_data(lobby_id: int, key: String) -> String:
	if is_available() and lobby_id != 0:
		return Steam.getLobbyData(lobby_id, key)
	return ""


func lobby_owner_id(lobby_id: int) -> int:
	if is_available() and lobby_id != 0:
		return Steam.getLobbyOwner(lobby_id)
	return 0


func _project_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "dev"))


func _on_steam_lobby_created(result: int, lobby_id: int) -> void:
	if result == 1:  # k_EResultOK
		set_lobby_data(lobby_id, LOBBY_GAME_KEY, LOBBY_GAME_VALUE)
		set_lobby_data(lobby_id, LOBBY_VERSION_KEY, _project_version())
		lobby_created.emit(lobby_id)
	else:
		lobby_join_failed.emit("lobby create failed (%d)" % result)


func _on_steam_lobby_joined(lobby_id: int, _perms: int, _locked: bool, response: int) -> void:
	if response == 1:  # k_EChatRoomEnterResponseSuccess
		lobby_joined.emit(lobby_id)
	else:
		lobby_join_failed.emit("lobby join failed (%d)" % response)


func _on_steam_lobby_match_list(lobbies: Array) -> void:
	var entries: Array[Dictionary] = []
	for lobby_id in lobbies:
		entries.append({
			"id": lobby_id,
			"name": get_lobby_data(lobby_id, "name"),
			"count": Steam.getNumLobbyMembers(lobby_id),
			"max": Steam.getLobbyMemberLimit(lobby_id),
			"mode": get_lobby_data(lobby_id, "mode"),
		})
	lobby_list.emit(entries)
