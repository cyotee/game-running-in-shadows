# Base for suites that exercise the netfox tick simulation.
# await_ticks(n) waits for N SIMULATION TICKS instead of engine frames:
# under machine load, frames stretch and tick batches catch up in bursts, so
# frame-count awaits stop mapping to simulation time — tick awaits stay
# deterministic.
class_name NetSuite
extends GdUnitTestSuite


func await_ticks(count: int) -> void:
	var target := NetworkTime.tick + count
	while NetworkTime.tick < target:
		await NetworkTime.after_tick_loop
