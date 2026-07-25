class_name TestPlaytestViz
extends GdUnitTestSuite


func after_test() -> void:
	MatchConfig.reset_to_defaults()
	OS.set_environment("COUNTERSPELL_RELEASE", "")
	ProjectSettings.set_setting("counterspell/release_build", false)


func test_enabled_follows_match_config() -> void:
	MatchConfig.set_value("debug.playtest_viz", 0.0)
	assert_bool(MatchConfig.get_value("debug.playtest_viz") > 0.5).is_false()
	MatchConfig.set_value("debug.playtest_viz", 1.0)
	assert_bool(MatchConfig.get_value("debug.playtest_viz") > 0.5).is_true()


func test_enabled_false_in_release_mode() -> void:
	# Simulate release the same way InputTrace does.
	OS.set_environment("COUNTERSPELL_RELEASE", "1")
	# Force PlaytestViz to re-read if it caches; otherwise call enabled() which must check env each time.
	assert_bool(PlaytestViz.enabled()).is_false()
	OS.set_environment("COUNTERSPELL_RELEASE", "")


func test_debug_viz_defaults_exist() -> void:
	MatchConfig.reset_to_defaults()
	assert_float(MatchConfig.get_value("debug.playtest_viz")).is_equal(1.0)
	assert_float(MatchConfig.get_value("debug.viz.tracer_duration_s")).is_equal(0.28)
	assert_float(MatchConfig.get_value("debug.viz.hit_marker_duration_s")).is_equal(0.2)
	assert_float(MatchConfig.get_value("debug.viz.muzzle_duration_s")).is_equal(0.07)
	assert_float(MatchConfig.get_value("debug.viz.show_damage_pips")).is_equal(1.0)
	assert_float(MatchConfig.get_value("debug.viz.combat_log_lines")).is_equal(8.0)
	assert_float(MatchConfig.get_value("debug.viz.max_active_fx")).is_equal(64.0)
	assert_float(MatchConfig.get_value("debug.viz.max_tracers_per_tick")).is_equal(12.0)
	assert_float(MatchConfig.get_value("debug.viz.replicate")).is_equal(1.0)
	assert_float(MatchConfig.get_value("debug.viz.show_state_silhouettes")).is_equal(1.0)
	assert_float(MatchConfig.get_value("debug.viz.show_slip_ghost")).is_equal(1.0)
	assert_float(MatchConfig.get_value("debug.viz.host_force_session")).is_equal(1.0)


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
