class_name TestPingService
extends GdUnitTestSuite

var _state: MatchState


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)
	_state = auto_free(MatchState.new())
	add_child(_state)
	_state.assign_team(10)  # team 0
	_state.assign_team(20)  # team 1
	_state.assign_team(30)  # team 0
	PingService.setup(_state)
	PingService.reset()


func after_test() -> void:
	PingService.setup(null)
	PingService.reset()
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func test_world_ping_is_stored_and_visible_to_owner() -> void:
	PingService._apply_ping(10, PingService.WORLD, Vector3(1, 0, 2), 0)
	var pings := PingService.visible_pings(10)
	assert_int(pings.size()).is_equal(1)
	assert_int(pings[0]["kind"]).is_equal(PingService.WORLD)
	assert_vector(pings[0]["world_pos"]).is_equal(Vector3(1, 0, 2))


func test_enemy_ping_records_target_and_feeds_familiar_query() -> void:
	PingService._apply_ping(10, PingService.ENEMY, Vector3.ZERO, 20)
	assert_int(PingService.latest_enemy_tag(10)).is_equal(20)
	# World ping has no enemy tag.
	PingService._apply_ping(30, PingService.WORLD, Vector3(5, 0, 0), 0)
	assert_int(PingService.latest_enemy_tag(30)).is_equal(0)


func test_visibility_is_team_scoped() -> void:
	PingService._apply_ping(10, PingService.WORLD, Vector3(1, 0, 0), 0)  # team 0
	assert_int(PingService.visible_pings(30).size()).is_equal(1)  # 30 is team 0 -> sees it
	assert_int(PingService.visible_pings(20).size()).is_equal(0)  # 20 is team 1 -> hidden


func test_re_ping_replaces_owner_previous_ping() -> void:
	PingService._apply_ping(10, PingService.WORLD, Vector3(1, 0, 0), 0)
	PingService._apply_ping(10, PingService.ENEMY, Vector3.ZERO, 20)
	var pings := PingService.visible_pings(10)
	assert_int(pings.size()).is_equal(1)  # limit 1: replaced, not added
	assert_int(pings[0]["kind"]).is_equal(PingService.ENEMY)


func test_ping_expires_after_duration() -> void:
	PingService._apply_ping(10, PingService.WORLD, Vector3(1, 0, 0), 0)
	var record: Dictionary = PingService.visible_pings(10)[0]
	PingService._cull(record["expire_tick"] + 1)
	assert_int(PingService.active_count()).is_equal(0)
	assert_int(PingService.latest_enemy_tag(10)).is_equal(0)


func test_no_team_falls_back_to_owner_only() -> void:
	PingService.setup(null)  # no MatchState -> team -1
	PingService._apply_ping(10, PingService.WORLD, Vector3(1, 0, 0), 0)
	assert_int(PingService.visible_pings(10).size()).is_equal(1)  # owner sees own
	assert_int(PingService.visible_pings(20).size()).is_equal(0)  # nobody else
