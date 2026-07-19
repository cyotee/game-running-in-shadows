class_name TestSessionManager
extends GdUnitTestSuite


class FakeLobbyService:
	extends SteamLobbyService
	var created := false
	var joined_id := 0

	func is_available() -> bool:
		return true

	func create_lobby(_visibility: int, _max_members: int) -> void:
		created = true

	func join_lobby(lobby_id: int) -> void:
		joined_id = lobby_id

	func leave_lobby(_lobby_id: int) -> void:
		pass


var fake: FakeLobbyService


func before_test() -> void:
	fake = FakeLobbyService.new()
	SessionManager.lobby_service = fake
	SessionManager._reset_for_tests()


func after_test() -> void:
	SessionManager.lobby_service = null
	SessionManager.state = SessionManager.IDLE


func test_host_requests_lobby_then_becomes_host_on_created() -> void:
	SessionManager.host(SteamLobbyService.VIS_PUBLIC)
	assert_bool(fake.created).is_true()
	assert_int(SessionManager.state).is_equal(SessionManager.HOSTING_LOBBY)

	fake.lobby_created.emit(123456)
	assert_int(SessionManager.state).is_equal(SessionManager.IN_LOBBY)
	assert_int(SessionManager.current_lobby_id).is_equal(123456)


func test_join_flow_reaches_connecting() -> void:
	SessionManager.join(999)
	assert_int(fake.joined_id).is_equal(999)
	fake.lobby_joined.emit(999)
	assert_int(SessionManager.state).is_equal(SessionManager.CONNECTING)


func test_join_failure_returns_to_idle_with_error() -> void:
	var errors: Array = []
	SessionManager.session_error.connect(func(m: String) -> void: errors.append(m))
	SessionManager.join(999)
	fake.lobby_join_failed.emit("full")
	assert_int(SessionManager.state).is_equal(SessionManager.IDLE)
	assert_array(errors).has_size(1)


func test_headless_without_steam_surfaces_error() -> void:
	SessionManager.lobby_service = SteamLobbyService.new()
	SessionManager._reset_for_tests()
	var errors: Array = []
	SessionManager.session_error.connect(func(m: String) -> void: errors.append(m))

	SessionManager.host(SteamLobbyService.VIS_PUBLIC)

	assert_int(SessionManager.state).is_equal(SessionManager.IDLE)
	assert_array(errors).contains(["Steam unavailable"])
