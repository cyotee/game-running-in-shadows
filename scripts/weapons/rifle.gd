# 3-round burst with scoped ADS. The trigger starts a burst; continuation
# runs from _weapon_tick regardless of the trigger (burst vars are state, so
# direct _fire calls stay rollback-safe).
class_name RifleWeapon
extends WeaponBase

# --- Rollback state ---
var burst_remaining: int = 0
var next_burst_tick: int = -(1 << 30)


func supports_ads() -> bool:
	return true


func _wants_fire(tick: int) -> bool:
	# Trigger only starts bursts; continuation is handled in _weapon_tick.
	return _controller().input.fire_press_tick == tick and burst_remaining == 0


func _on_fire_tick(tick: int) -> void:
	if burst_remaining == 0:
		burst_remaining = int(config("burst_count")) - 1
	else:
		burst_remaining -= 1
	next_burst_tick = tick + int(roundf(config("burst_intra_s") * NetworkTime.tickrate))


func _weapon_tick(_delta: float, tick: int) -> void:
	if burst_remaining > 0 and tick >= next_burst_tick and mag > 0.0:
		_fire(tick)
