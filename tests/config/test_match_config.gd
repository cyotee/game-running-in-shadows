class_name TestMatchConfig
extends GdUnitTestSuite


func after_test() -> void:
	MatchConfig.reset_to_defaults()


func test_defaults_are_loaded() -> void:
	assert_float(MatchConfig.get_value("resonance.repulse_cost")).is_equal(2.0)
	assert_float(MatchConfig.get_value("archetype.troll.max_health")).is_equal(135.0)


## 2026-07-25 vertical-loop playtest pass: shipped DEFAULTS for mobility
## recover, Lifebloom sustain, and Familiar payoff (see ABILITY_TUNING_SHEET §9).
func test_playtest_pass_2026_07_25_tuned_defaults() -> void:
	MatchConfig.reset_to_defaults()
	assert_float(MatchConfig.DEFAULTS["archetype.human.regen_per_s"]).is_equal(0.5)
	assert_float(MatchConfig.get_value("archetype.human.regen_per_s")).is_equal(0.5)
	assert_float(MatchConfig.DEFAULTS["ability.lifebloom_heal_per_s"]).is_equal(8.0)
	assert_float(MatchConfig.get_value("ability.lifebloom_heal_per_s")).is_equal(8.0)
	assert_float(MatchConfig.DEFAULTS["familiar.melee_damage"]).is_equal(16.0)
	assert_float(MatchConfig.get_value("familiar.melee_damage")).is_equal(16.0)
	# Dwarf drain must outpace human OOC regen so the aura remains a counter.
	assert_float(MatchConfig.DEFAULTS["archetype.dwarf.drain_per_enemy_per_s"]).is_equal(0.75)
	assert_float(MatchConfig.get_value("archetype.dwarf.drain_per_enemy_per_s")).is_greater(
		MatchConfig.get_value("archetype.human.regen_per_s")
	)
	# Derived feel targets recorded in the playtest log (repulse cost still 2).
	var repulse := MatchConfig.get_value("resonance.repulse_cost")
	var regen := MatchConfig.get_value("archetype.human.regen_per_s")
	assert_float(repulse / regen).is_equal(4.0)
	var heal_s := MatchConfig.get_value("archetype.human.max_health") / MatchConfig.get_value(
		"ability.lifebloom_heal_per_s"
	)
	assert_float(heal_s).is_equal(12.5)
	var fam_dps := MatchConfig.get_value("familiar.melee_damage") / MatchConfig.get_value(
		"familiar.attack_interval_s"
	)
	assert_float(fam_dps).is_equal(20.0)


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
