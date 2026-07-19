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


func test_lobby_browser_model_formats_and_skips_malformed() -> void:
	var browser_script := load("res://scripts/ui/lobby_browser.gd")
	var model = browser_script.LobbyBrowserModel
	var rows: Array[Dictionary] = model.to_rows([
		{"id": 1, "name": "Rooftop Run", "mode": "arena", "count": 3, "max": 16},
		{"id": 2, "name": "NoMode"},  # malformed: skipped
		"garbage",  # malformed: skipped
	])

	assert_int(rows.size()).is_equal(1)
	assert_str(rows[0].label).is_equal("Rooftop Run — arena — 3/16")
	assert_int(rows[0].id).is_equal(1)


func test_headless_without_steam_surfaces_error() -> void:
	SessionManager.lobby_service = SteamLobbyService.new()
	SessionManager._reset_for_tests()
	var errors: Array = []
	SessionManager.session_error.connect(func(m: String) -> void: errors.append(m))

	SessionManager.host(SteamLobbyService.VIS_PUBLIC)

	assert_int(SessionManager.state).is_equal(SessionManager.IDLE)
	assert_array(errors).contains(["Steam unavailable"])
