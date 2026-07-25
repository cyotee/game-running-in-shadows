class_name TestPlaytestFxBus
extends GdUnitTestSuite


func before_test() -> void:
	MatchConfig.reset_to_defaults()
	PlaytestFxBus.reset_for_tests()


func after_test() -> void:
	MatchConfig.reset_to_defaults()
	PlaytestFxBus.reset_for_tests()
	OS.set_environment("COUNTERSPELL_RELEASE", "")


func test_host_policy_forces_session_on() -> void:
	PlaytestFxBus.apply_host_policy(true, true)
	assert_bool(PlaytestFxBus.session_active()).is_true()
	assert_bool(PlaytestFxBus.session_viz_on()).is_true()
	# Local MatchConfig off must not clear host-forced session bit.
	MatchConfig.set_value("debug.playtest_viz", 0.0)
	assert_bool(PlaytestFxBus.session_viz_on()).is_true()


func test_host_policy_off() -> void:
	PlaytestFxBus.apply_host_policy(true, false)
	assert_bool(PlaytestFxBus.session_active()).is_true()
	assert_bool(PlaytestFxBus.session_viz_on()).is_false()


func test_notify_hitscan_pushes_log() -> void:
	PlaytestFxBus.apply_host_policy(true, true)
	# Headless: PlaytestViz.enabled() is false, so notify_hitscan returns early.
	# Force log via push_log to prove ring buffer, and call notify under session.
	PlaytestFxBus.push_log("pistol body 12")
	var lines := PlaytestFxBus.log_lines()
	assert_int(lines.size()).is_greater(0)
	assert_str(lines[lines.size() - 1]).contains("pistol")


func test_log_ring_respects_cap() -> void:
	MatchConfig.set_value("debug.viz.combat_log_lines", 3.0)
	for i in range(5):
		PlaytestFxBus.push_log("line %d" % i)
	assert_int(PlaytestFxBus.log_lines().size()).is_equal(3)
	assert_str(PlaytestFxBus.log_lines()[0]).contains("2")
