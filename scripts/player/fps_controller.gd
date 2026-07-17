# FPSController — netfox predicted movement.
# All simulation runs in _rollback_tick; input comes from the PlayerInput
# child node; per-tick state is registered in RollbackSynchronizer
# (see fps_controller.tscn). Values are tunable via @export for the
# Ability Tuning Sheet.
class_name FPSController
extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 7.5
@export var acceleration: float = 20.0

# --- Repulse & Glide (tuning sheet values) ---
@export var repulse_strength: float = 22.0
@export var repulse_range: float = 10.0
@export var glide_duration: float = 4.0
@export var glide_gravity_mult: float = 0.25
@export var glide_speed: float = 4.0
@export var glide_air_control: float = 30.0
@export var combo_launch_velocity: float = 28.0
@export var combo_window: float = 0.7

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Rollback state (registered as state_properties) ---
var is_gliding: bool = false
var glide_ticks_remaining: int = 0
var last_down_repulse_tick: int = -(1 << 30)

@onready var input: PlayerInput = $Input
@onready var camera: Camera3D = $Camera3D
@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer


func _ready() -> void:
	# Input authority may have been reassigned by a spawner before _ready.
	rollback_synchronizer.process_settings()
	var is_local := input.is_multiplayer_authority()
	camera.current = is_local
	if is_local and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	# Camera pitch is view-only (never rolled back); yaw is applied to the
	# body in _rollback_tick from recorded input.
	if input.is_multiplayer_authority():
		camera.rotation.x = input.local_pitch


func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	transform.basis = Basis(Vector3.UP, input.aim_yaw)
	_force_update_is_on_floor()

	if input.repulse:
		_cast_repulse(tick, is_fresh)
	if input.glide and not is_gliding:
		_try_deploy_glide(tick)

	var speed := sprint_speed if input.sprint else walk_speed
	var direction := (transform.basis * Vector3(input.movement.x, 0, input.movement.y)).normalized()

	if is_gliding:
		glide_ticks_remaining -= 1
		# Cancel when landing (not while launching upward off the ground).
		if glide_ticks_remaining <= 0 or (is_on_floor() and velocity.y <= 0.01):
			is_gliding = false
		else:
			velocity.y -= gravity * delta * glide_gravity_mult
			if direction:
				velocity.x = move_toward(velocity.x, direction.x * glide_speed, glide_air_control * delta)
				velocity.z = move_toward(velocity.z, direction.z * glide_speed, glide_air_control * delta)
			velocity.y = maxf(velocity.y, -6.0)
			if input.jump:
				velocity.y = maxf(velocity.y + 9.0, 9.0)
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta
		if input.jump and is_on_floor():
			velocity.y = jump_velocity
		var target := direction * speed
		velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	if input.fire and is_fresh:
		_try_shoot()

	# netfox CharacterBody3D pattern: move_and_slide assumes engine delta.
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor


# move_and_slide is what updates is_on_floor; run it with zero velocity so
# floor state is correct at the start of each (re-)simulated tick.
func _force_update_is_on_floor() -> void:
	var old_velocity := velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity


func _try_shoot() -> void:
	var space_state := get_world_3d().direct_space_state
	var from := camera.global_position
	var aim := Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)
	var to := from + (aim * Vector3.FORWARD) * 100.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)

	if result:
		print("Hit: ", result.collider.name if result.collider else "something", " at ", result.position)
	else:
		print("Shot fired (miss)")


# --- Abilities (implemented in Task 4) ---

func _cast_repulse(_tick: int, _is_fresh: bool) -> void:
	pass


func _try_deploy_glide(_tick: int) -> void:
	pass
