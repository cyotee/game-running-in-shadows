class_name TestMapsExist
extends GdUnitTestSuite


func test_close_quarters_map_resource_valid() -> void:
	# Resource-only checks avoid orphaning full arena trees (autoload side effects).
	assert_bool(ResourceLoader.exists("res://scenes/levels/map_close_quarters.tscn")).is_true()
	var scene: PackedScene = load("res://scenes/levels/map_close_quarters.tscn") as PackedScene
	assert_object(scene).is_not_null()


func test_objective_map_resource_has_ctf_nodes() -> void:
	assert_bool(ResourceLoader.exists("res://scenes/levels/map_objective.tscn")).is_true()
	var scene: PackedScene = load("res://scenes/levels/map_objective.tscn") as PackedScene
	assert_object(scene).is_not_null()
	var state: SceneState = scene.get_state()
	var names: PackedStringArray = PackedStringArray()
	for i in state.get_node_count():
		names.append(String(state.get_node_name(i)))
	assert_bool(names.has("MapObjective") or names.has("CtfFlag")).is_true()
	assert_bool(names.has("CtfFlag")).is_true()
	assert_bool(names.has("GoalTeam0")).is_true()
	assert_bool(names.has("GoalTeam1")).is_true()
