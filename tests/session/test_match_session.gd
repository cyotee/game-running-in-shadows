class_name TestMatchSession
extends NetSuite


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()


func test_offline_boot_spawns_single_local_player() -> void:
	var runner := scene_runner("res://scenes/session/match_session.tscn")
	await await_ticks(5)
	var session: Node = runner.scene()

	assert_int(session.get_node("SpawnPoints").get_child_count()).is_equal(16)
	assert_int(session.get_node("Players").get_child_count()).is_equal(2)  # spawner + player 1
	assert_bool(session.is_spectator(1)).is_false()


func test_promote_spectator_spawns_body() -> void:
	var runner := scene_runner("res://scenes/session/match_session.tscn")
	await await_ticks(5)
	var session: Node = runner.scene()

	session._register_late_joiner(42)
	assert_bool(session.is_spectator(42)).is_true()
	session.promote_spectator(42)
	await await_ticks(2)

	assert_object(session.get_node_or_null("Players/42")).is_not_null()
	assert_bool(session.is_spectator(42)).is_false()
