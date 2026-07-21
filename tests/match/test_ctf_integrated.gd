class_name TestCtfIntegrated
extends NetSuite

# Proves CtfObjective runs on NetworkTime.on_tick (shipped path), not only
# when tests call process_tick manually.


func before_test() -> void:
	NetworkTime.start()
	await await_millis(80)


func after_test() -> void:
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()
	for node in get_tree().get_nodes_in_group("ctf_objective"):
		if is_instance_valid(node):
			node.free()


func test_flag_follows_carrier_on_network_ticks() -> void:
	var root: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(root)
	var ms: MatchState = MatchState.new()
	root.add_child(ms)
	ms.assign_team(1)  # peer 1 -> team 0

	var flag: CtfObjective = CtfObjective.new()
	root.add_child(flag)
	flag.setup(ms)
	flag.home_pos = Vector3.ZERO
	flag.global_position = Vector3.ZERO

	var packed: PackedScene = load("res://scenes/player/fps_controller.tscn") as PackedScene
	var carrier: FPSController = auto_free(packed.instantiate()) as FPSController
	root.add_child(carrier)
	carrier.input.set_multiplayer_authority(1)
	carrier.global_position = Vector3(0.5, 0, 0)

	flag.try_pickup(carrier)
	assert_int(flag.carrier_peer).is_equal(1)

	var before := flag.global_position
	carrier.global_position = Vector3(4.0, 0, 2.0)
	await await_ticks(12)

	# process_tick must have been driven by NetworkTime.on_tick (flag leaves home).
	assert_float(flag.global_position.distance_to(before)).is_greater(1.0)
	assert_float(flag.global_position.distance_to(
		carrier.global_position + Vector3(0, 1.6, 0))).is_less(0.25)


func test_flag_scores_when_carried_to_goal_via_ticks() -> void:
	var root: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(root)
	var ms: MatchState = MatchState.new()
	root.add_child(ms)
	ms.assign_team(1)

	var goal: Node3D = Node3D.new()
	goal.add_to_group("ctf_goal_0")
	root.add_child(goal)
	goal.global_position = Vector3(6, 0, 0)

	var flag: CtfObjective = CtfObjective.new()
	root.add_child(flag)
	flag.setup(ms)
	flag.home_pos = Vector3.ZERO
	flag.global_position = Vector3.ZERO

	var packed: PackedScene = load("res://scenes/player/fps_controller.tscn") as PackedScene
	var carrier: FPSController = auto_free(packed.instantiate()) as FPSController
	root.add_child(carrier)
	carrier.input.set_multiplayer_authority(1)
	carrier.global_position = Vector3(0.4, 0, 0)
	flag.try_pickup(carrier)
	assert_int(flag.carrier_peer).is_equal(1)

	carrier.global_position = goal.global_position
	await await_ticks(10)

	assert_int(flag.team_scores[0]).is_equal(1)
	assert_int(flag.carrier_peer).is_equal(0)
	assert_bool(flag.at_home).is_true()


func test_map_objective_scene_has_match_state_and_flag() -> void:
	assert_bool(ResourceLoader.exists("res://scenes/levels/map_objective.tscn")).is_true()
	var scene: PackedScene = load("res://scenes/levels/map_objective.tscn") as PackedScene
	var state: SceneState = scene.get_state()
	var names: PackedStringArray = PackedStringArray()
	for i in state.get_node_count():
		names.append(String(state.get_node_name(i)))
	assert_bool(names.has("MatchState")).is_true()
	assert_bool(names.has("CtfFlag")).is_true()
	assert_bool(names.has("GoalTeam0")).is_true()
