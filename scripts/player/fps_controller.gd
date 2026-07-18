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
@export var archetype: StringName = &"human"

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Rollback state (registered as state_properties) ---
var is_gliding: bool = false
var glide_ticks_remaining: int = 0
var last_down_repulse_tick: int = -(1 << 30)
var health: float = 100.0

@onready var input: PlayerInput = $Input
@onready var camera: Camera3D = $Camera3D
@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer
@onready var resonance: ResonancePool = $Resonance


func _ready() -> void:
	add_to_group("players")
	_apply_archetype_config()
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
		# Controller-only aim assist: reticle friction while an enemy is in
		# view. Mouse look never reads look_rate_scale (decided design).
		input.look_rate_scale = (
			MatchConfig.get_value("input.slowdown_mult")
			if enemy_under_reticle(MatchConfig.get_value("input.slowdown_range_m"))
			else 1.0
		)


# TODO(weapons): use the hit-zone layer once the weapons plan adds hit zones;
# for now any FPSController body counts.
func enemy_under_reticle(max_range: float) -> bool:
	var space_state := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z) * max_range

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)

	return not result.is_empty() and result.collider is FPSController


func _config(key_suffix: String) -> float:
	return MatchConfig.get_value("archetype.%s.%s" % [archetype, key_suffix])


func _apply_archetype_config() -> void:
	resonance.max_resonance = _config("max_resonance")
	resonance.regen_per_s = _config("regen_per_s")
	resonance.combat_timeout_ticks = int(roundf(
		MatchConfig.get_value("resonance.combat_timeout_s") * NetworkTime.tickrate))
	resonance.reserved = 0.0
	# Glide Harness is always equipped in the prototype; reservation scales
	# with the archetype tech multiplier (decided 2026-07-16).
	resonance.reserve(
		MatchConfig.get_value("resonance.glide_harness_reservation") * _config("tech_mult"))
	resonance.fill_to_cap()
	health = _config("max_health")


func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	transform.basis = Basis(Vector3.UP, input.aim_yaw)
	_force_update_is_on_floor()

	resonance.process_tick(delta, tick)
	_process_archetype_passives(delta, tick, is_fresh)

	# Press-tick inputs match exactly one simulated tick (see PlayerInput).
	var jump_pressed := input.jump_press_tick == tick
	# Capture boost intent before contextual deploy can consume the press.
	var jump_for_boost := jump_pressed and is_gliding

	if (
		input.repulse_press_tick == tick
		and resonance.try_spend(MatchConfig.get_value("resonance.repulse_cost"))
	):
		_cast_repulse(tick, is_fresh)
	# Contextual jump (controller A): airborne and not gliding -> deploy glide.
	var wants_glide := (
		input.glide_press_tick == tick
		or (jump_pressed and not is_on_floor() and not is_gliding)
	)
	if wants_glide and not is_gliding:
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
			if jump_for_boost:
				velocity.y = maxf(velocity.y + 9.0, 9.0)
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta
		if jump_pressed and is_on_floor():
			velocity.y = jump_velocity
		var target := direction * speed
		velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	if input.fire_press_tick == tick and is_fresh:
		_try_shoot(tick)

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


func _process_archetype_passives(delta: float, tick: int, is_fresh: bool) -> void:
	if archetype == &"elf":
		var max_health := _config("max_health")
		if health < max_health and not resonance.is_in_combat(tick):
			var floor_value := _config("heal_resonance_floor")
			if resonance.current > floor_value:
				var convert := minf(_config("heal_convert_per_s") * delta,
					resonance.current - floor_value)
				resonance.drain(convert)
				health = minf(health + convert * _config("heal_hp_per_resonance"), max_health)
	if archetype == &"dwarf" and is_fresh:
		# Cross-player state writes run on fresh ticks only, like Repulse
		# pushes. Drained Resonance is destroyed, never siphoned.
		var radius := _config("drain_radius_m")
		var rate := _config("drain_per_enemy_per_s")
		for node in get_tree().get_nodes_in_group("players"):
			var other := node as FPSController
			if other == null or other == self:
				continue
			if other.global_position.distance_to(global_position) <= radius:
				other.resonance.drain(rate * delta)


func take_damage(amount: float, attacker: FPSController, tick: int) -> void:
	health = maxf(health - amount, 0.0)
	resonance.mark_combat(tick)
	if attacker != null and attacker != self:
		attacker.resonance.mark_combat(tick)
	if health <= 0.0:
		# Death/respawn arrives with the round-flow plan; clamp for now.
		print("%s down (no death handling yet)" % name)


func _try_shoot(tick: int) -> void:
	var space_state := get_world_3d().direct_space_state
	var from := camera.global_position
	var aim := Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)
	var to := from + (aim * Vector3.FORWARD) * 100.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)

	if result and result.collider is FPSController:
		result.collider.take_damage(MatchConfig.get_value("weapon.hitscan_damage"), self, tick)
	elif result:
		print("Hit: ", result.collider.name, " at ", result.position)
	else:
		print("Shot fired (miss)")


func _cast_repulse(tick: int, is_fresh: bool) -> void:
	var looking_down := input.aim_pitch < -0.65
	if looking_down:
		last_down_repulse_tick = tick

	var aim := Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)
	var cast_dir := aim * Vector3.FORWARD

	# Self push (predicted; velocity is rollback state).
	velocity += cast_dir * (repulse_strength * 0.4)
	if looking_down:
		velocity.y -= 6.0

	# World side effects run once, on fresh ticks only — never re-applied
	# during rollback re-simulation.
	if is_fresh:
		_push_nearby_bodies(cast_dir)
		print("Repulse cast (downward=%s, tick=%d)" % [looking_down, tick])


func _push_nearby_bodies(cast_dir: Vector3) -> void:
	var space_state := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = repulse_range

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = global_transform.translated(cast_dir * 4.0)
	query.collide_with_bodies = true

	var results := space_state.intersect_shape(query)
	for res in results:
		var body = res["collider"]
		if body and body != self:
			var push_dir = (body.global_position - global_position).normalized()
			if body is CharacterBody3D:
				body.velocity += push_dir * repulse_strength + Vector3(0, 4, 0)
			elif body is RigidBody3D:
				body.apply_central_impulse(push_dir * repulse_strength * 3.0)


func _try_deploy_glide(tick: int) -> void:
	var window_ticks := int(roundf(combo_window * NetworkTime.tickrate))
	var is_combo := (tick - last_down_repulse_tick <= window_ticks) and input.aim_pitch < -0.4

	is_gliding = true
	glide_ticks_remaining = int(roundf(glide_duration * NetworkTime.tickrate))

	if is_combo:
		velocity.y = combo_launch_velocity
		print(">>> GLIDE LAUNCH COMBO! (tick=%d)" % tick)
	else:
		if not is_on_floor():
			velocity.y = maxf(velocity.y, 8.0)
		if velocity.y < 0:
			velocity.y *= 0.3
		print("Glide deployed (tick=%d)" % tick)
