# FPSController
# Local-first, but already prepared for multiplayer authority.
# Attach to a CharacterBody3D with Camera3D child.
class_name FPSController
extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 7.5
@export var mouse_sensitivity: float = 0.0025
@export var acceleration: float = 20.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_speed: float = walk_speed

@onready var camera: Camera3D = $Camera3D

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

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	# Sprint
	var is_sprinting := Input.is_action_pressed("sprint")
	current_speed = sprint_speed if is_sprinting else walk_speed

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Movement input
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
