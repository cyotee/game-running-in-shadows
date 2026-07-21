class_name TestCtfObjective
extends NetSuite


func before_test() -> void:
	NetworkTime.start()
	await await_millis(50)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func test_pickup_and_score() -> void:
	var root: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(root)
	var ms: MatchState = MatchState.new()
	root.add_child(ms)
	ms.assign_team(1)
	ms.assign_team(2)
	var flag: CtfObjective = CtfObjective.new()
	root.add_child(flag)
	flag.setup(ms)
	flag.home_pos = Vector3.ZERO
	flag.global_position = Vector3.ZERO
	var goal: Node3D = Node3D.new()
	goal.add_to_group("ctf_goal_0")
	root.add_child(goal)
	goal.global_position = Vector3(5, 0, 0)

	var packed: PackedScene = load("res://scenes/player/fps_controller.tscn") as PackedScene
	var carrier: FPSController = auto_free(packed.instantiate()) as FPSController
	root.add_child(carrier)
	carrier.input.set_multiplayer_authority(1)
	carrier.global_position = Vector3(0.5, 0, 0)
	flag.try_pickup(carrier)
	assert_int(flag.carrier_peer).is_equal(1)

	carrier.global_position = goal.global_position
	flag.process_tick(NetworkTime.tick)
	assert_int(flag.team_scores[0]).is_equal(1)
	assert_int(flag.carrier_peer).is_equal(0)
	assert_bool(flag.at_home).is_true()
