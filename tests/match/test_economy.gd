class_name TestEconomy
extends GdUnitTestSuite


class SlottedEconomy:
	extends Economy
	# G5 preview: two items sharing the eye slot, priced via existing keys.
	const TEST_SLOTS: Dictionary = {
		"smg": ["eye"],
		"rifle": ["eye", "full_body"],
	}

	func _cyber_slots_of(item: String) -> Array:
		return TEST_SLOTS.get(item, [])


var economy: Economy
var match_state: MatchState


func before_test() -> void:
	match_state = auto_free(MatchState.new())
	add_child(match_state)
	economy = auto_free(Economy.new())
	add_child(economy)
	economy.setup(null, match_state)
	match_state.assign_team(10)
	match_state.assign_team(20)
	economy.register_player(10)
	economy.register_player(20)
	match_state.phase = MatchState.BUY_PHASE


func after_test() -> void:
	MatchConfig.reset_to_defaults()


func test_registration_gives_start_money_and_pistol() -> void:
	assert_int(economy.money_of(10)).is_equal(800)
	assert_bool(economy.owns(10, "pistol")).is_true()
	assert_bool(economy.owns(10, "grenades")).is_true()
	assert_bool(economy.owns(10, "repulse")).is_false()
	assert_bool(economy.owns(10, "glide")).is_false()


func test_buy_repulse_and_glide() -> void:
	economy.give_money(10, 5000)
	assert_bool(economy.try_buy(10, "repulse")).is_true()
	assert_bool(economy.owns(10, "repulse")).is_true()
	assert_int(economy.money_of(10)).is_equal(800 + 5000 - 1600)
	assert_bool(economy.try_buy(10, "glide")).is_true()
	assert_bool(economy.owns(10, "glide")).is_true()
	assert_int(economy.money_of(10)).is_equal(800 + 5000 - 1600 - 1800)
	# Free starters cannot be refunded.
	assert_bool(economy.refund(10, "grenades", true)).is_false()
	assert_bool(economy.owns(10, "grenades")).is_true()


func test_buy_deducts_and_rejects_when_poor_or_owned() -> void:
	assert_bool(economy.try_buy(10, "smg")).is_true()
	assert_int(economy.money_of(10)).is_equal(200)
	assert_bool(economy.try_buy(10, "smg")).is_false()  # already owned
	assert_bool(economy.try_buy(10, "rifle")).is_false()  # cannot afford
	assert_int(economy.money_of(10)).is_equal(200)


func test_buy_rejected_outside_buy_phase() -> void:
	match_state.phase = MatchState.ROUND_LIVE
	assert_bool(economy.try_buy(10, "smg")).is_false()
	assert_int(economy.money_of(10)).is_equal(800)


func test_wages_compound_for_winners_and_killers() -> void:
	economy.note_kill(10)
	economy.note_kill(10)
	economy.award_round_wages(0)  # team 0 (peer 10) won

	# 800 + base 1000 + 2 kills x 200 + win 600 = 2800
	assert_int(economy.money_of(10)).is_equal(2800)
	# 800 + base 1000 (loser, no kills) = 1800
	assert_int(economy.money_of(20)).is_equal(1800)
	# Kill counters reset each round.
	economy.award_round_wages(-1)
	assert_int(economy.money_of(10)).is_equal(3800)


func test_loadout_walk_skips_and_continues() -> void:
	# Money 800: rifle (1600) unaffordable -> SKIP AND CONTINUE to smg (600).
	economy.apply_loadout(10, ["rifle", "smg"])
	assert_bool(economy.owns(10, "rifle")).is_false()
	assert_bool(economy.owns(10, "smg")).is_true()
	assert_int(economy.money_of(10)).is_equal(200)


func test_cyber_slot_exclusivity_and_permanence() -> void:
	var slotted: Economy = auto_free(SlottedEconomy.new())
	add_child(slotted)
	slotted.setup(null, match_state)
	slotted.register_player(10)
	slotted.money[10] = 10000

	assert_bool(slotted.try_buy(10, "smg")).is_true()   # takes the eye slot
	assert_bool(slotted.try_buy(10, "rifle")).is_false()  # eye slot occupied
	assert_str(slotted.cyber_slots_used[10]["eye"]).is_equal("smg")
	# Permanence in live matches: owned items cannot be re-bought without refund.
	assert_bool(slotted.try_buy(10, "smg")).is_false()


func test_give_money_and_ignore_phase_for_dev() -> void:
	match_state.phase = MatchState.ROUND_LIVE
	assert_bool(economy.try_buy(10, "smg")).is_false()
	assert_bool(economy.try_buy(10, "smg", true)).is_true()  # ignore_phase (dev arsenal)
	assert_int(economy.money_of(10)).is_equal(200)
	economy.give_money(10, 1000)
	assert_int(economy.money_of(10)).is_equal(1200)
	# Unknown item is never free-bought.
	assert_bool(economy.try_buy(10, "not_a_real_item", true)).is_false()


func test_refund_returns_cash_and_allows_replacement() -> void:
	assert_bool(economy.try_buy(10, "smg")).is_true()
	assert_int(economy.money_of(10)).is_equal(200)
	assert_bool(economy.owns(10, "smg")).is_true()
	assert_bool(economy.refund(10, "smg", true)).is_true()
	assert_bool(economy.owns(10, "smg")).is_false()
	assert_int(economy.money_of(10)).is_equal(800)
	assert_bool(economy.try_buy(10, "smg")).is_true()
	# Remove without cash refund.
	assert_bool(economy.refund(10, "smg", false)).is_true()
	assert_int(economy.money_of(10)).is_equal(200)
	# Free sidearm cannot be refunded.
	assert_bool(economy.refund(10, "pistol", true)).is_false()
	assert_bool(economy.owns(10, "pistol")).is_true()


func test_refund_frees_cyber_slots() -> void:
	var slotted: Economy = auto_free(SlottedEconomy.new())
	add_child(slotted)
	slotted.setup(null, match_state)
	slotted.register_player(10)
	slotted.money[10] = 10000
	assert_bool(slotted.try_buy(10, "smg")).is_true()
	assert_bool(slotted.try_buy(10, "rifle")).is_false()
	assert_bool(slotted.refund(10, "smg", true)).is_true()
	assert_bool(slotted.cyber_slots_used[10].has("eye")).is_false()
	assert_bool(slotted.try_buy(10, "rifle")).is_true()
