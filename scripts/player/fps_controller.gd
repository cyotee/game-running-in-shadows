# FPSController
# Local-first, but already prepared for multiplayer authority.
# Attach to a CharacterBody3D with Camera3D child.
#
# Prototype: Basic movement + Repulse (force blast) + Glide (float + combo launch) implemented.
# Values are tunable via @export for the Ability Tuning Sheet.
class_name FPSController
extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 7.5
@export var mouse_sensitivity: float = 0.0025
@export var acceleration: float = 20.0

# --- Repulse & Glide (prototype values - tune via inspector or Tuning Sheet) ---
@export var repulse_strength: float = 22.0
@export var repulse_range: float = 10.0
@export var glide_duration: float = 4.0
@export var glide_gravity_mult: float = 0.25
@export var glide_speed: float = 4.0  # set in-flight horizontal speed (scalar, ~80% of slowest race base walk speed)
@export var glide_air_control: float = 30.0  # horizontal accel rate (passed as max_delta after *delta) while gliding for snappy control
@export var combo_launch_velocity: float = 28.0
@export var combo_window: float = 0.7

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_speed: float = walk_speed

@onready var camera: Camera3D = $Camera3D

# Glide state
var is_gliding: bool = false
var glide_time_remaining: float = 0.0
var last_down_repulse_time: float = -100.0

func _ready() -> void:
	if not is_multiplayer_authority():
		camera.current = false
		set_process_input(false)
		return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2.0, PI/2.0)

	# Toggle mouse capture (useful during development)
	if event.is_action_pressed("toggle_mouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Ability prototype inputs
	if event.is_action_pressed("repulse"):
		_cast_repulse()
	if event.is_action_pressed("glide"):
		_try_deploy_glide()

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	# Sprint
	var is_sprinting := Input.is_action_pressed("sprint")
	current_speed = sprint_speed if is_sprinting else walk_speed

	# Glide state handling - takes precedence for movement feel
	if is_gliding:
		glide_time_remaining -= delta
		if glide_time_remaining <= 0.0 or is_on_floor():
			is_gliding = false
		else:
			# Reduced gravity effect
			if not is_on_floor():
				velocity.y -= gravity * delta * glide_gravity_mult
			# Set horizontal speed for more in-flight control (fixed scalar speed, not race-based)
			var glide_input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			var glide_direction := (transform.basis * Vector3(glide_input_dir.x, 0, glide_input_dir.y)).normalized()
			if glide_direction:
				velocity.x = move_toward(velocity.x, glide_direction.x * glide_speed, glide_air_control * delta)
				velocity.z = move_toward(velocity.z, glide_direction.z * glide_speed, glide_air_control * delta)
			# Soft cap downward speed for floaty feel
			if velocity.y < -6.0:
				velocity.y = -6.0
			# Allow extra height boost with jump while gliding
			if Input.is_action_just_pressed("jump"):
				velocity.y = max(velocity.y + 9.0, 9.0)
	else:
		# Normal gravity and jump
		if not is_on_floor():
			velocity.y -= gravity * delta

		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity

		# Normal movement input
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		var target_velocity := Vector3.ZERO
		if direction:
			target_velocity = direction * current_speed

		# Smooth acceleration
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	move_and_slide()

	# Basic fire input (we'll turn this into a proper weapon soon)
	if Input.is_action_just_pressed("fire_primary"):
		_try_shoot()

func _try_shoot() -> void:
	# Simple raycast from camera for now (hitscan)
	var space_state := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + -camera.global_transform.basis.z * 100.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	var result := space_state.intersect_ray(query)

	if result:
		print("Hit: ", result.collider.name if result.collider else "something", " at ", result.position)
		# TODO: Spawn hit effect, apply damage in multiplayer, etc.
	else:
		print("Shot fired (miss)")

# --- Repulse & Glide prototype implementation ---

func _cast_repulse() -> void:
	if not is_multiplayer_authority():
		return

	var now := Time.get_unix_time_from_system()
	var cam_forward := -camera.global_transform.basis.z
	var pitch := camera.rotation.x
	var looking_down := pitch < -0.65  # roughly 37 degrees down

	# Record for combo
	if looking_down:
		last_down_repulse_time = now

	# Self push in cast direction (helps with combo feel)
	velocity += cam_forward * (repulse_strength * 0.4)
	if looking_down:
		velocity.y -= 6.0  # slight downward assist for ground interaction

	# Push nearby bodies (simple prototype using shape query)
	var space_state := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = repulse_range

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = global_transform.translated(cam_forward * 4.0)
	query.collide_with_bodies = true

	var results := space_state.intersect_shape(query)
	for res in results:
		var body = res["collider"]
		if body and body != self:
			var push_dir = (body.global_position - global_position).normalized()
			if body is CharacterBody3D:
				body.velocity += push_dir * repulse_strength + Vector3(0, 4, 0)  # slight lift
			elif body is RigidBody3D:
				body.apply_central_impulse(push_dir * repulse_strength * 3.0)

	print("Repulse cast (downward=%s)" % looking_down)

func _try_deploy_glide() -> void:
	if not is_multiplayer_authority() or is_gliding:
		return

	var now := Time.get_unix_time_from_system()
	var is_combo := (now - last_down_repulse_time < combo_window) and camera.rotation.x < -0.4

	is_gliding = true
	glide_time_remaining = glide_duration

	if is_combo:
		velocity.y = combo_launch_velocity
		print(">>> GLIDE LAUNCH COMBO! (upward boost)")
	else:
		# Normal deploy - give some initial lift if jumping
		if not is_on_floor():
			velocity.y = max(velocity.y, 8.0)
		print("Glide deployed")

	# Optional: reduce current downward velocity
	if velocity.y < 0:
		velocity.y *= 0.3
