# Per-tick input gathering for the FPS controller (netfox BaseNetInput).
# Networked properties below are registered as RollbackSynchronizer
# input_properties ("Input:<name>") in fps_controller.tscn.
# Edge-triggered actions are latched in _process so presses between network
# ticks are never lost, and consumed on exactly one tick by _gather().
class_name PlayerInput
extends BaseNetInput

@export var mouse_sensitivity: float = 0.0025

# --- Networked per-tick input ---
var movement: Vector2 = Vector2.ZERO
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0
var jump: bool = false
var sprint: bool = false
var repulse: bool = false
var glide: bool = false
var fire: bool = false

# --- Local-only view state (never rolled back) ---
var local_yaw: float = 0.0
var local_pitch: float = 0.0

var _pending_jump: bool = false
var _pending_repulse: bool = false
var _pending_glide: bool = false
var _pending_fire: bool = false


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


func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_pending_jump = _pending_jump or Input.is_action_just_pressed("jump")
	_pending_repulse = _pending_repulse or Input.is_action_just_pressed("repulse")
	_pending_glide = _pending_glide or Input.is_action_just_pressed("glide")
	_pending_fire = _pending_fire or Input.is_action_just_pressed("fire_primary")


func _gather() -> void:
	movement = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	sprint = Input.is_action_pressed("sprint")
	aim_yaw = local_yaw
	aim_pitch = local_pitch
	jump = _pending_jump
	repulse = _pending_repulse
	glide = _pending_glide
	fire = _pending_fire
	_pending_jump = false
	_pending_repulse = false
	_pending_glide = false
	_pending_fire = false
