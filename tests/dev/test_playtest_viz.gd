class_name TestPlaytestViz
extends GdUnitTestSuite


func after_test() -> void:
	MatchConfig.reset_to_defaults()


func test_enabled_follows_match_config() -> void:
	MatchConfig.set_value("debug.playtest_viz", 0.0)
	assert_bool(MatchConfig.get_value("debug.playtest_viz") > 0.5).is_false()
	MatchConfig.set_value("debug.playtest_viz", 1.0)
	assert_bool(MatchConfig.get_value("debug.playtest_viz") > 0.5).is_true()


func test_unshaded_mat_is_transparent() -> void:
	var m: StandardMaterial3D = PlaytestViz.unshaded_mat(Color(1, 0, 0, 0.2))
	assert_that(m).is_not_null()
	assert_int(m.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_int(m.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)


func test_attach_sphere_skips_when_disabled() -> void:
	MatchConfig.set_value("debug.playtest_viz", 0.0)
	var host: Node3D = auto_free(Node3D.new())
	add_child(host)
	var mi: MeshInstance3D = PlaytestViz.attach_sphere(host, 5.0, Color(1, 1, 1, 0.2))
	assert_that(mi).is_null()


func test_field_range_keys_match_sim() -> void:
	# Regression: viz radii must track the same keys as gameplay.
	assert_float(MatchConfig.get_value("ability.lifebloom_radius_m")).is_equal(7.0)
	assert_float(MatchConfig.get_value("ability.tangle_radius_m")).is_equal(4.0)
	assert_float(MatchConfig.get_value("ability.null_radius_m")).is_equal(5.0)
	assert_float(MatchConfig.get_value("ability.grenade_radius_m")).is_equal(5.0)
	assert_float(MatchConfig.get_value("ability.grenade_inner_radius_m")).is_equal(1.5)
