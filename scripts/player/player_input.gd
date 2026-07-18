# Per-tick input gathering for the FPS controller (netfox BaseNetInput).
# Networked properties below are registered as RollbackSynchronizer
# input_properties ("Input:<name>") in fps_controller.tscn.
#
# Edge-triggered actions are transmitted as PRESS TICKS, not bools: netfox
# reuses the last gathered input for every tick in a catch-up batch (and
# extrapolates it while waiting for remote input), so a latched bool press
# is seen by many consecutive ticks and multi-fires. A press-tick only
# matches the single simulated tick it was stamped with — exactly-once under
# batching, extrapolation, and resimulation.
#
# Presses are latched in _process from polled state transitions
# (is_action_just_pressed is frame-exact and races node process order).
class_name PlayerInput
extends BaseNetInput

@export var mouse_sensitivity: float = 0.0025

# --- Networked per-tick input ---
var movement: Vector2 = Vector2.ZERO
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0
var sprint: bool = false
var jump_press_tick: int = -1
var repulse_press_tick: int = -1
var glide_press_tick: int = -1
var fire_press_tick: int = -1
var swap_press_tick: int = -1

# --- Local-only view state (never rolled back) ---
var local_yaw: float = 0.0
var local_pitch: float = 0.0

# --- Controller look (local shaping; feeds the same local_yaw/local_pitch) ---
var look_rate_scale: float = 1.0

var _pending_jump: bool = false
var _pending_repulse: bool = false
var _pending_glide: bool = false
var _pending_fire: bool = false
var _pending_swap: bool = false

var _held_jump: bool = false
var _held_repulse: bool = false
var _held_glide: bool = false
var _held_fire: bool = false
var _held_swap: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		local_yaw = wrapf(local_yaw - event.relative.x * mouse_sensitivity, -PI, PI)
		local_pitch = clampf(local_pitch - event.relative.y * mouse_sensitivity, -PI / 2.0, PI / 2.0)
	if event.is_action_pressed("toggle_mouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var jump_now := Input.is_action_pressed("jump")
	var repulse_now := Input.is_action_pressed("repulse")
	var glide_now := Input.is_action_pressed("glide")
	var fire_now := Input.is_action_pressed("fire_primary")
	var swap_now := Input.is_action_pressed("weapon_swap")
	_pending_jump = _pending_jump or (jump_now and not _held_jump)
	_pending_repulse = _pending_repulse or (repulse_now and not _held_repulse)
	_pending_glide = _pending_glide or (glide_now and not _held_glide)
	_pending_fire = _pending_fire or (fire_now and not _held_fire)
	_pending_swap = _pending_swap or (swap_now and not _held_swap)
	_held_jump = jump_now
	_held_repulse = repulse_now
	_held_glide = glide_now
	_held_fire = fire_now
	_held_swap = swap_now

	var stick_x := _remap_stick(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X))
	var stick_y := _remap_stick(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick_x != 0.0 or stick_y != 0.0:
		var yaw_rate := deg_to_rad(MatchConfig.get_value("input.look_max_yaw_deg_s"))
		var pitch_rate := deg_to_rad(MatchConfig.get_value("input.look_max_pitch_deg_s"))
		local_yaw = wrapf(local_yaw - stick_x * yaw_rate * look_rate_scale * delta, -PI, PI)
		local_pitch = clampf(local_pitch - stick_y * pitch_rate * look_rate_scale * delta,
			-PI / 2.0, PI / 2.0)


func _remap_stick(value: float) -> float:
	var inner := MatchConfig.get_value("input.stick_deadzone_inner")
	var outer := MatchConfig.get_value("input.stick_deadzone_outer")
	var mag := absf(value)
	if mag < inner:
		return 0.0
	var normalized := clampf((mag - inner) / (outer - inner), 0.0, 1.0)
	return signf(value) * pow(normalized, MatchConfig.get_value("input.look_curve_exponent"))


func _gather() -> void:
	movement = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	sprint = Input.is_action_pressed("sprint")
	aim_yaw = local_yaw
	aim_pitch = local_pitch
	if _pending_jump:
		jump_press_tick = NetworkTime.tick
	if _pending_repulse:
		repulse_press_tick = NetworkTime.tick
	if _pending_glide:
		glide_press_tick = NetworkTime.tick
	if _pending_fire:
		fire_press_tick = NetworkTime.tick
	if _pending_swap:
		swap_press_tick = NetworkTime.tick
	_pending_jump = false
	_pending_repulse = false
	_pending_glide = false
	_pending_fire = false
	_pending_swap = false
