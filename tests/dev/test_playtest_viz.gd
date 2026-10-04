class_name TestPlaytestViz
extends GdUnitTestSuite


func after_test() -> void:
	MatchConfig.reset_to_defaults()
	OS.set_environment("COUNTERSPELL_RELEASE", "")
	ProjectSettings.set_setting("counterspell/release_build", false)
	PlaytestViz.clear_fx_pool()


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


func test_unshaded_mat_reuses_same_instance() -> void:
	var c := Color(0.35, 0.75, 1.0, 0.28)
	var a: StandardMaterial3D = PlaytestViz.unshaded_mat(c)
	var b: StandardMaterial3D = PlaytestViz.unshaded_mat(c)
	assert_that(a).is_same(b)


func test_tracer_mat_is_vertex_color_variant() -> void:
	var m: StandardMaterial3D = PlaytestViz.tracer_mat(Color(1.0, 0.9, 0.2, 0.9))
	assert_that(m).is_not_null()
	assert_bool(m.vertex_color_use_as_albedo).is_true()
	assert_int(m.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_int(m.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)


func test_tracer_mat_does_not_poison_unshaded_cache() -> void:
	var c := Color(0.5, 0.5, 0.5, 0.5)
	var aura: StandardMaterial3D = PlaytestViz.unshaded_mat(c)
	var tracer: StandardMaterial3D = PlaytestViz.tracer_mat(c)
	assert_that(aura).is_not_same(tracer)
	assert_bool(aura.vertex_color_use_as_albedo).is_false()
	assert_bool(tracer.vertex_color_use_as_albedo).is_true()


func test_gameplay_materials_include_tracer_and_aura() -> void:
	var mats: Array = PlaytestViz.gameplay_materials()
	assert_int(mats.size()).is_greater_equal(2)
	var has_aura := false
	var has_tracer := false
	for m in mats:
		if m is StandardMaterial3D:
			if m.vertex_color_use_as_albedo:
				has_tracer = true
			else:
				has_aura = true
	assert_bool(has_aura).is_true()
	assert_bool(has_tracer).is_true()


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


func test_zone_tracer_colors_distinct() -> void:
	var miss := PlaytestViz.zone_tracer_color("", false)
	var limb := PlaytestViz.zone_tracer_color("limbs", true)
	var body := PlaytestViz.zone_tracer_color("body", true)
	var head := PlaytestViz.zone_tracer_color("head", true)
	assert_bool(miss != body).is_true()
	assert_bool(body != head).is_true()
	assert_bool(limb != head).is_true()
	assert_bool(miss != limb).is_true()
	assert_bool(limb != body).is_true()


func test_flash_line_uses_config_duration_when_default() -> void:
	# Unit-level: duration resolution helper
	assert_float(PlaytestViz.tracer_duration()).is_equal_approx(0.28, 0.001)
	MatchConfig.set_value("debug.viz.tracer_duration_s", 0.5)
	assert_float(PlaytestViz.tracer_duration()).is_equal_approx(0.5, 0.001)


func test_owner_color_stable_and_distinct() -> void:
	var a := PlaytestViz.owner_color(1)
	var a2 := PlaytestViz.owner_color(1)
	var b := PlaytestViz.owner_color(2)
	assert_that(a).is_equal(a2)
	assert_bool(a != b).is_true()
	assert_float(a.a).is_equal_approx(0.35, 0.001)


func test_fx_pool_evicts_oldest_at_cap() -> void:
	MatchConfig.set_value("debug.viz.max_active_fx", 3.0)
	# Pool owns these nodes — do not auto_free (eviction / clear_fx_pool free them).
	var n1 := Node.new()
	var n2 := Node.new()
	var n3 := Node.new()
	var n4 := Node.new()
	PlaytestViz.register_fx_node(n1)
	PlaytestViz.register_fx_node(n2)
	PlaytestViz.register_fx_node(n3)
	assert_int(PlaytestViz.active_fx_count()).is_equal(3)
	PlaytestViz.register_fx_node(n4)
	assert_int(PlaytestViz.active_fx_count()).is_equal(3)
	# Oldest (n1) evicted / freed; n2–n4 remain.
	assert_bool(is_instance_valid(n1)).is_false()
	assert_bool(is_instance_valid(n4)).is_true()
	PlaytestViz.clear_fx_pool()
	assert_int(PlaytestViz.active_fx_count()).is_equal(0)


func test_gameplay_materials_include_zone_tracer_colors() -> void:
	var mats: Array = PlaytestViz.gameplay_materials()
	var head_col := PlaytestViz.zone_tracer_color("head", true)
	var limb_col := PlaytestViz.zone_tracer_color("limbs", true)
	var body_col := PlaytestViz.zone_tracer_color("body", true)
	var miss_col := PlaytestViz.zone_tracer_color("", false)
	var found_head := false
	var found_limb := false
	var found_body := false
	var found_miss := false
	for m in mats:
		if m is StandardMaterial3D:
			var sm: StandardMaterial3D = m
			if not sm.vertex_color_use_as_albedo:
				continue
			var c: Color = sm.albedo_color
			if _color_near(c, head_col):
				found_head = true
			if _color_near(c, limb_col):
				found_limb = true
			if _color_near(c, body_col):
				found_body = true
			if _color_near(c, miss_col):
				found_miss = true
	assert_bool(found_head).is_true()
	assert_bool(found_limb).is_true()
	assert_bool(found_body).is_true()
	assert_bool(found_miss).is_true()


func _color_near(a: Color, b: Color, eps: float = 0.02) -> bool:
	return absf(a.r - b.r) <= eps and absf(a.g - b.g) <= eps \
		and absf(a.b - b.b) <= eps and absf(a.a - b.a) <= eps
