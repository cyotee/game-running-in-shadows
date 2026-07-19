class_name TestMatchState
extends GdUnitTestSuite


func before_test() -> void:
	# Short phases so full cycles fit in test time.
	MatchConfig.set_value("match.buy_phase_s", 0.2)
	MatchConfig.set_value("match.round_time_s", 0.5)
	MatchConfig.set_value("match.round_end_s", 0.2)
	MatchConfig.set_value("match.rounds_to_win", 2.0)
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func _make_state() -> MatchState:
	var state: MatchState = auto_free(MatchState.new())
	add_child(state)
	return state


func test_team_assignment_round_robins() -> void:
	var state := _make_state()
	assert_int(state.assign_team(10)).is_equal(0)
	assert_int(state.assign_team(20)).is_equal(1)
	assert_int(state.assign_team(30)).is_equal(0)
	assert_int(state.team_of(20)).is_equal(1)
	assert_int(state.team_of(99)).is_equal(-1)


func test_phase_cycle_advances_on_tick_timers() -> void:
	var state := _make_state()
	state.start_match()
	assert_int(state.phase).is_equal(MatchState.BUY_PHASE)

	await await_millis(400)
	state.process_tick(NetworkTime.tick)
	assert_int(state.phase).is_equal(MatchState.ROUND_LIVE)

	await await_millis(700)
	state.process_tick(NetworkTime.tick)
	assert_int(state.phase).is_equal(MatchState.ROUND_END)

	await await_millis(400)
	state.process_tick(NetworkTime.tick)
	assert_int(state.phase).is_equal(MatchState.BUY_PHASE)
	assert_int(state.round_number).is_equal(2)


func test_kill_scoring_and_timer_round_win() -> void:
	var state := _make_state()
	state.assign_team(10)  # team 0
	state.assign_team(20)  # team 1
	state.start_match()
	await await_millis(400)
	state.process_tick(NetworkTime.tick)  # -> ROUND_LIVE

	state.record_kill(20, 10)  # attacker 10 (team 0) kills 20 (team 1)
	assert_array(state.team_kills).contains_exactly([1, 0])
	state.record_kill(10, 10)  # suicide: no score
	assert_array(state.team_kills).contains_exactly([1, 0])

	await await_millis(700)
	state.process_tick(NetworkTime.tick)  # timer expiry -> team 0 wins round
	assert_array(state.round_wins).contains_exactly([1, 0])
	assert_int(state.phase).is_equal(MatchState.ROUND_END)


func test_match_ends_at_rounds_to_win() -> void:
	var state := _make_state()
	state.assign_team(10)
	state.assign_team(20)
	state.start_match()
	var ended: Array = []
	state.match_ended.connect(func(team: int) -> void: ended.append(team))

	for _round in range(2):
		await await_millis(400)
		state.process_tick(NetworkTime.tick)  # -> ROUND_LIVE
		state.record_kill(20, 10)
		await await_millis(700)
		state.process_tick(NetworkTime.tick)  # round win for team 0
		if state.phase == MatchState.MATCH_END:
			break
		await await_millis(400)
		state.process_tick(NetworkTime.tick)  # -> next BUY_PHASE

	assert_int(state.phase).is_equal(MatchState.MATCH_END)
	assert_int(state.winning_team).is_equal(0)
	assert_array(ended).has_size(1)
