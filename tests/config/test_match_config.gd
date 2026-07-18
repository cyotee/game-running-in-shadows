class_name TestMatchConfig
extends GdUnitTestSuite


func after_test() -> void:
	MatchConfig.reset_to_defaults()


func test_defaults_are_loaded() -> void:
	assert_float(MatchConfig.get_value("resonance.repulse_cost")).is_equal(2.0)
	assert_float(MatchConfig.get_value("archetype.troll.max_health")).is_equal(135.0)


func test_unknown_key_pushes_error_and_returns_zero() -> void:
	assert_float(MatchConfig.get_value("no.such.key")).is_equal(0.0)


func test_runtime_override_and_reset() -> void:
	MatchConfig.set_value("resonance.repulse_cost", 5.0)
	assert_float(MatchConfig.get_value("resonance.repulse_cost")).is_equal(5.0)
	MatchConfig.reset_to_defaults()
	assert_float(MatchConfig.get_value("resonance.repulse_cost")).is_equal(2.0)


func test_loads_json_override_file() -> void:
	var path := "user://test_match_config.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"resonance.combat_timeout_s": 9.5}))
	f.close()

	MatchConfig.load_overrides(path)
	assert_float(MatchConfig.get_value("resonance.combat_timeout_s")).is_equal(9.5)
	# Untouched keys keep defaults.
	assert_float(MatchConfig.get_value("resonance.repulse_cost")).is_equal(2.0)

	DirAccess.remove_absolute(path)
