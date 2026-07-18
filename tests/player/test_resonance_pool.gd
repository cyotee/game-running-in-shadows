class_name TestResonancePool
extends GdUnitTestSuite

var pool: ResonancePool


func before_test() -> void:
	pool = auto_free(ResonancePool.new())
	pool.max_resonance = 10.0
	pool.regen_per_s = 1.0
	pool.combat_timeout_ticks = 240
	pool.fill_to_cap()


func test_spawns_full_minus_reservations() -> void:
	pool.reserve(2.0)
	assert_float(pool.cap()).is_equal(8.0)
	assert_float(pool.current).is_equal(8.0)


func test_hard_block_spend() -> void:
	assert_bool(pool.try_spend(2.0)).is_true()
	assert_float(pool.current).is_equal(8.0)
	assert_bool(pool.try_spend(9.0)).is_false()
	assert_float(pool.current).is_equal(8.0)


func test_release_returns_empty_capacity() -> void:
	pool.reserve(4.0)          # cap 6, current clamped 10 -> 6
	assert_float(pool.current).is_equal(6.0)
	pool.release(4.0)          # cap back to 10...
	assert_float(pool.cap()).is_equal(10.0)
	assert_float(pool.current).is_equal(6.0)  # ...but pips come back EMPTY


func test_regen_gated_by_combat_timer() -> void:
	pool.drain(5.0)
	pool.mark_combat(1000)
	pool.process_tick(1.0, 1100)           # 100 ticks later: still in combat
	assert_float(pool.current).is_equal(5.0)
	pool.process_tick(1.0, 1241)           # past 240-tick timeout: regen 1.0
	assert_float(pool.current).is_equal(6.0)


func test_regen_respects_cap() -> void:
	pool.reserve(2.0)
	pool.drain(0.5)
	pool.process_tick(10.0, 100000)        # huge regen, must clamp to cap 8
	assert_float(pool.current).is_equal(8.0)


func test_drain_floors_at_zero() -> void:
	pool.drain(99.0)
	assert_float(pool.current).is_equal(0.0)
