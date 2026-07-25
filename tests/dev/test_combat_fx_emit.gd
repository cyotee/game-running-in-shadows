class_name TestCombatFxEmit
extends GdUnitTestSuite


func after_test() -> void:
	MatchConfig.reset_to_defaults()
	PlaytestViz.clear_fx_pool()


func test_hitscan_zone_color_helper_maps_head() -> void:
	assert_that(PlaytestViz.zone_tracer_color("head", true)).is_not_equal(
		PlaytestViz.zone_tracer_color("body", true)
	)
	assert_that(PlaytestViz.zone_tracer_color("limbs", true)).is_not_equal(
		PlaytestViz.zone_tracer_color("body", true)
	)
	assert_that(PlaytestViz.zone_tracer_color("", false)).is_not_equal(
		PlaytestViz.zone_tracer_color("body", true)
	)


func test_present_hitscan_skips_when_not_fresh() -> void:
	var w: WeaponBase = auto_free(WeaponBase.new())
	w.weapon_key = "pistol"
	var count_before := PlaytestViz.active_fx_count()
	var presented := w._present_hitscan_fx(
		Vector3.ZERO, Vector3.FORWARD, "head", 10.0, true, false
	)
	assert_bool(presented).is_false()
	assert_int(PlaytestViz.active_fx_count()).is_equal(count_before)


func test_present_hitscan_attempts_when_fresh() -> void:
	# Headless: PlaytestViz.enabled() is false, so no meshes spawn, but the
	# seam still reports "attempted" for fresh frames (local authority path).
	var w: WeaponBase = auto_free(WeaponBase.new())
	w.weapon_key = "pistol"
	var presented := w._present_hitscan_fx(
		Vector3.ZERO, Vector3.FORWARD, "body", 12.0, true, true
	)
	assert_bool(presented).is_true()
	# Headless pool stays empty when viz is gated off.
	assert_int(PlaytestViz.active_fx_count()).is_equal(0)


func test_present_blade_skips_when_not_fresh() -> void:
	var b: BladeWeapon = auto_free(BladeWeapon.new())
	b.weapon_key = "blade"
	var count_before := PlaytestViz.active_fx_count()
	var presented := b._present_blade_fx(
		Vector3.ZERO, Vector3.FORWARD, Vector3(0, 1, 1), 25.0, true, false
	)
	assert_bool(presented).is_false()
	assert_int(PlaytestViz.active_fx_count()).is_equal(count_before)


func test_present_blade_attempts_when_fresh() -> void:
	var b: BladeWeapon = auto_free(BladeWeapon.new())
	b.weapon_key = "blade"
	var presented := b._present_blade_fx(
		Vector3.ZERO, Vector3.FORWARD, Vector3(0, 1, 1), 25.0, true, true
	)
	assert_bool(presented).is_true()
	assert_int(PlaytestViz.active_fx_count()).is_equal(0)


func test_present_hitscan_miss_uses_empty_zone() -> void:
	# Pure color contract: miss path uses hit_player=false regardless of zone string.
	var miss := PlaytestViz.zone_tracer_color("", false)
	var miss_with_zone := PlaytestViz.zone_tracer_color("head", false)
	assert_that(miss).is_equal(miss_with_zone)
