class_name TestMapsExist
extends GdUnitTestSuite


func test_close_quarters_map_loads() -> void:
	var scene: PackedScene = load("res://scenes/levels/map_close_quarters.tscn") as PackedScene
	assert_object(scene).is_not_null()
	var node: Node = scene.instantiate()
	assert_str(node.name).is_equal("MapCloseQuarters")
	node.free()


func test_objective_map_loads_with_ctf() -> void:
	var scene: PackedScene = load("res://scenes/levels/map_objective.tscn") as PackedScene
	assert_object(scene).is_not_null()
	var node: Node = scene.instantiate()
	assert_str(node.name).is_equal("MapObjective")
	assert_object(node.get_node_or_null("CtfFlag")).is_not_null()
	assert_object(node.get_node_or_null("GoalTeam0")).is_not_null()
	assert_object(node.get_node_or_null("GoalTeam1")).is_not_null()
	node.free()
