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


# Deterministic edge-action press: sets the PlayerInput pending latch
# directly, consumed by the next _gather. Real Input event -> poll -> latch
# integration is covered by the PlayerInput suite; behavior tests inject here
# because Input.action_press timing races node process order once awaits
# resume from tick signals.
func press(input: PlayerInput, action: StringName) -> void:
	match action:
		&"jump":
			input._pending_jump = true
		&"repulse":
			input._pending_repulse = true
		&"glide":
			input._pending_glide = true
		&"fire":
			input._pending_fire = true
		&"weapon_swap":
			input._pending_swap = true
		&"reload":
			input._pending_reload = true
		&"slip":
			input._pending_slip = true
		&"wraith":
			input._pending_wraith = true
		&"grenade":
			input._pending_grenade = true
		&"lifebloom":
			input._pending_lifebloom = true
		&"tangle":
			input._pending_tangle = true
		&"null_charge":
			input._pending_null = true
		&"interact":
			input._pending_interact = true
		&"reclaim":
			input._pending_reclaim = true
		&"familiar":
			input._pending_familiar = true
		&"pulse_sight":
			input._pending_pulse_sight = true
		&"smart_rig":
			input._pending_smart_rig = true
		&"overclock":
			input._pending_overclock = true
		_:
			assert(false, "unknown edge action %s" % action)


func select_slot(input: PlayerInput, slot: int) -> void:
	input._pending_slot = slot


## Equip purchased kit items for tests (buy == equip).
## Sets kit flags immediately (not rollback), then queues so consumable stock /
## weapon slots apply on a fresh sim tick and enter history.
func equip_kit(controller: FPSController, items: Array) -> void:
	for item in items:
		controller.grant_kit(str(item))
		controller.queue_grant_kit(str(item))
	await await_ticks(3)


## Grant purchased movement kit (Repulse + Glide Harness) for ability tests.
func grant_movement_kit(controller: FPSController) -> void:
	await equip_kit(controller, ["repulse", "glide"])
