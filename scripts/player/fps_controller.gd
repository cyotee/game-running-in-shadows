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
@export var default_slot1: String = "rifle"
@export var default_slot2: String = "pistol"

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Rollback state (registered as state_properties) ---
var is_gliding: bool = false
var glide_ticks_remaining: int = 0
var last_down_repulse_tick: int = -(1 << 30)
var health: float = 100.0
var bleed_ticks_remaining: int = 0
var bleed_hp_per_s: float = 0.0
var is_dead: bool = false
var is_wraithed: bool = false
var is_dragging: bool = false
var grenade_stock: int = 2
var grenade_cook_ticks: int = 0
var null_stock: int = 4
var lifebloom_reserved: bool = false
var tangle_reserved: bool = false
var lifebloom_cast_tick: int = -(1 << 30)
var tangle_cast_tick: int = -(1 << 30)
var last_attacker_peer: int = 0
# Reclaim (G5 W3): held reservation while any revived ally lives; revived_by_peer
# links a revived ally back to its reviver for the caster-death bleed-out pull.
var reclaim_reserved: bool = false
var revived_by_peer: int = 0
var reclaim_cast_tick: int = -(1 << 30)

# Respawn request (plain vars, consumed inside the tick simulation).
var _pending_respawn: Vector3 = Vector3.ZERO
var _has_pending_respawn: bool = false

# Reclaim revive request (plain vars — cross-node writes must NOT touch rollback
# state directly; the owner applies this in its own tick). See corpse-drag lesson.
var _has_pending_reclaim: bool = false
var _pending_reclaim_pos: Vector3 = Vector3.ZERO
var _pending_reclaim_reviver: int = 0
var _pending_reclaim_snapshot: Array = []

# Weapon grant queue (rig slots are rollback state; grants must apply
# inside the tick, same pattern as respawn).
var _pending_grants: Array[Array] = []

# Damage queued to apply inside the tick. Out-of-band health writes are
# discarded by the rollback state restore, so external/test-initiated damage
# must be applied in-simulation (weapons already call take_damage in-tick).
var _pending_damage: float = 0.0

signal died(victim_peer: int, attacker_peer: int)
signal cast_denied()

@onready var input: PlayerInput = $Input
@onready var camera: Camera3D = $Camera3D
@onready var standing_shape: CollisionShape3D = $CollisionShape3D
@onready var crouch_shape: CollisionShape3D = $CrouchShape
@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer
@onready var resonance: ResonancePool = $Resonance
@onready var weapon_rig: WeaponRig = $Camera3D/WeaponSocket/WeaponRig
@onready var third_person_rig: Node3D = $ThirdPersonRig
@onready var third_person_camera: Camera3D = $ThirdPersonRig/SpringArm3D/ThirdPersonCamera


func _ready() -> void:
	add_to_group("players")
	for zone_area: Area3D in $HitZones.get_children():
		zone_area.set_meta("zone", zone_area.name.to_lower())
		zone_area.set_meta("player", self)
	_apply_archetype_config()
	weapon_rig.setup(self)
	weapon_rig.grant(default_slot2, 2)
	if default_slot1 != "":
		weapon_rig.grant(default_slot1, 1)
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
		# ADS zoom is view-only feedback.
		var active := weapon_rig.active_weapon() if weapon_rig != null else null
		var target_fov := 75.0
		if active != null and input.ads and active.supports_ads():
			target_fov = 75.0 / active.ads_zoom()
		camera.fov = lerpf(camera.fov, target_fov, minf(10.0 * _delta, 1.0))
		# Blade wields in third person (view-only camera swap).
		var blade_out := active != null and active.weapon_key == "blade"
		if blade_out != third_person_camera.current:
			third_person_camera.current = blade_out
			camera.current = not blade_out
		if blade_out:
			third_person_rig.rotation = Vector3(input.local_pitch * 0.5, 0, 0)
		# Controller-only aim assist: reticle friction while an enemy is in
		# view. Mouse look never reads look_rate_scale (decided design).
		input.look_rate_scale = (
			MatchConfig.get_value("input.slowdown_mult")
			if enemy_under_reticle(MatchConfig.get_value("input.slowdown_range_m"))
			else 1.0
		)


func enemy_under_reticle(max_range: float) -> bool:
	var space_state := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z) * max_range

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0b11  # world (1) + hit zones (2)
	var excludes: Array[RID] = [get_rid()]
	for zone_area: Area3D in $HitZones.get_children():
		excludes.append(zone_area.get_rid())
	query.exclude = excludes
	var result := space_state.intersect_ray(query)

	return (
		not result.is_empty()
		and result.collider is Area3D
		and result.collider.has_meta("player")
		and result.collider.get_meta("player") != self
	)


func try_ping() -> void:
	# Aimed ping: raycast from the camera; an enemy hit-zone -> enemy tag,
	# anything else -> world point. Intel/comms only — this runs outside the
	# rollback tick and hands off to PingService (host-authoritative).
	var space_state := get_world_3d().direct_space_state
	var from := camera.global_position
	var max_range := MatchConfig.get_value("ping.max_range_m")
	var to := from + (-camera.global_transform.basis.z) * max_range

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0b11  # world (1) + hit zones (2)
	var excludes: Array[RID] = [get_rid()]
	for zone_area: Area3D in $HitZones.get_children():
		excludes.append(zone_area.get_rid())
	query.exclude = excludes
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		PingService.request_ping(PingService.WORLD, to, 0)
		return
	var collider: Object = result.collider
	if collider is Area3D and collider.has_meta("player"):
		var enemy: FPSController = collider.get_meta("player")
		if enemy != self:
			PingService.request_ping(PingService.ENEMY, Vector3.ZERO,
				enemy.input.get_multiplayer_authority())
			return
	PingService.request_ping(PingService.WORLD, result.position, 0)


func _unhandled_input(event: InputEvent) -> void:
	if not input.is_multiplayer_authority():
		return
	if event.is_action_pressed("ping"):
		try_ping()


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
	grenade_stock = int(MatchConfig.get_value("ability.grenade_stock"))
	grenade_cook_ticks = 0
	null_stock = int(MatchConfig.get_value("ability.null_stock"))


func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if _has_pending_respawn and is_fresh:
		_apply_pending_respawn()
	if not _pending_grants.is_empty() and is_fresh:
		for grant in _pending_grants:
			weapon_rig.grant(grant[0], grant[1])
		_pending_grants.clear()

	# Death is simulation state: a dead body freezes where it fell (full
	# body persistence is a pillar; the corpse system extends this later).
	if is_dead:
		return
	if _pending_damage > 0.0 and is_fresh:
		health = maxf(health - _pending_damage, 0.0)
		_pending_damage = 0.0
	if health <= 0.0:
		is_dead = true
		if is_fresh:
			_spawn_corpse(tick)
			died.emit(input.get_multiplayer_authority(), last_attacker_peer)
		return

	transform.basis = Basis(Vector3.UP, input.aim_yaw)
	_force_update_is_on_floor()

	# Crouch: deterministic collider swap + speed multiplier from input.
	standing_shape.disabled = input.crouch
	crouch_shape.disabled = not input.crouch

	resonance.process_tick(delta, tick)
	_process_archetype_passives(delta, tick, is_fresh)
	weapon_rig.process_tick(delta, tick, is_fresh)

	if bleed_ticks_remaining > 0:
		bleed_ticks_remaining -= 1
		# Direct health reduction: bleed must NOT mark combat (decided) —
		# the Elf equilibrium depends on the heal running concurrently.
		health = maxf(health - bleed_hp_per_s * delta, 0.0)
		if bleed_ticks_remaining == 0:
			bleed_hp_per_s = 0.0

	# Press-tick inputs match exactly one simulated tick (see PlayerInput).
	var jump_pressed := input.jump_press_tick == tick
	# Capture boost intent before contextual deploy can consume the press.
	var jump_for_boost := jump_pressed and is_gliding

	# Wraith (toggle phase form). While phased: casts/weapons/glide locked,
	# walk speed only, bullet + fall immunity (see take_damage).
	if input.wraith_press_tick == tick:
		_toggle_wraith(is_fresh)
	if is_wraithed:
		resonance.drain(MatchConfig.get_value("resonance.wraith_drain_per_s") * delta)
		if resonance.current <= 0.0:
			is_wraithed = false  # forced out on empty pool

	if not is_wraithed and input.repulse_press_tick == tick:
		if not _in_null_field() and resonance.try_spend(MatchConfig.get_value("resonance.repulse_cost")):
			_cast_repulse(tick, is_fresh)
		elif is_fresh:
			# Hard block (decided): no overdraft; Null suppresses casting.
			cast_denied.emit()
	if not is_wraithed and input.slip_press_tick == tick:
		_try_slip(is_fresh)
	# Grenade cook (while held) + throw (on release).
	var cook_max := int(roundf(MatchConfig.get_value("ability.grenade_cook_max_s") * NetworkTime.tickrate))
	if not is_wraithed and input.grenade_held and grenade_stock > 0:
		grenade_cook_ticks = mini(grenade_cook_ticks + 1, cook_max)
	if not is_wraithed and input.grenade_press_tick == tick and grenade_stock > 0:
		_throw_grenade(is_fresh, cook_max)
	# Placed fields (instant placement at an aimed point; held reservations).
	if not is_wraithed and input.lifebloom_press_tick == tick:
		_cast_lifebloom(tick, is_fresh)
	if not is_wraithed and input.tangle_press_tick == tick:
		_cast_tangle(tick, is_fresh)
	if not is_wraithed and input.null_press_tick == tick and null_stock > 0:
		null_stock -= 1
		if is_fresh:
			_place_field("null_charge")
	_reconcile_field_reservations(tick)
	_process_interact(tick, is_fresh)
	# Contextual jump (controller A): airborne and not gliding -> deploy glide.
	var wants_glide := not is_wraithed and (
		input.glide_press_tick == tick
		or (jump_pressed and not is_on_floor() and not is_gliding)
	)
	if wants_glide and not is_gliding:
		_try_deploy_glide(tick)

	var base_speed := walk_speed if is_wraithed else (sprint_speed if input.sprint else walk_speed)
	var speed := base_speed * weapon_rig.carry_weight_mult()
	if input.crouch:
		speed *= MatchConfig.get_value("movement.crouch_speed_mult")
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

	_apply_tangle_pull(delta)

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


func apply_bleed(hp_per_s: float, duration_s: float) -> void:
	# No stacking (decided 2026-07-16): refresh duration, keep higher rate.
	bleed_ticks_remaining = int(roundf(duration_s * NetworkTime.tickrate))
	bleed_hp_per_s = maxf(bleed_hp_per_s, hp_per_s)


func can_use_weapon(weapon_key: String) -> bool:
	# Dragging a corpse restricts weapon use to Pistol / SMG (decided).
	if is_dragging:
		return weapon_key == "pistol" or weapon_key == "smg"
	return true


func is_blocking() -> bool:
	var active := weapon_rig.active_weapon()
	return active != null and active.weapon_key == "blade" and input.ads


func heal(amount: float, _tick: int) -> void:
	# Lifebloom heals friend or foe regardless of combat state (decided).
	if is_dead:
		return
	health = minf(health + amount, _config("max_health"))
	NetworkRollback.mutate(self)


func take_zone_damage(base_damage: float, weapon_key: String, zone: String,
		attacker: FPSController, tick: int) -> void:
	var mult := 1.0
	match zone:
		"head":
			# Dwarf headshot immunity: resolves as body damage.
			mult = 1.0 if archetype == &"dwarf" \
				else MatchConfig.get_value("weapon.%s.head_mult" % weapon_key)
		"limbs":
			mult = MatchConfig.get_value("zones.limb_mult")
	take_damage(base_damage * mult, attacker, tick)


func take_damage(amount: float, attacker: FPSController, tick: int) -> void:
	if is_wraithed:
		# Bullet + fall immunity while phased (decided). The Repulse
		# resonance-burn counter is a Resonance effect, handled separately.
		return
	health = maxf(health - amount, 0.0)
	resonance.mark_combat(tick)
	if attacker != null and attacker != self:
		attacker.resonance.mark_combat(tick)
		last_attacker_peer = attacker.input.get_multiplayer_authority()
	# External mutation of rollback state must be registered or the next
	# restore discards it (netfox upstream pattern).
	NetworkRollback.mutate(self)


func queue_grant(key: String, slot: int) -> void:
	_pending_grants.append([key, slot])


func reset_for_round(spawn_position: Vector3) -> void:
	# Queues a host-side round reset; the revive itself runs INSIDE the next
	# simulated tick (external writes to rollback state are discarded by the
	# restore, so out-of-band mutation cannot revive a player).
	_pending_respawn = spawn_position
	_has_pending_respawn = true


func _apply_pending_respawn() -> void:
	_has_pending_respawn = false
	is_dead = false
	last_attacker_peer = 0
	bleed_ticks_remaining = 0
	bleed_hp_per_s = 0.0
	is_gliding = false
	velocity = Vector3.ZERO
	global_position = _pending_respawn
	_apply_archetype_config()
	for key in [weapon_rig.slot1, weapon_rig.slot2]:
		if key != "":
			weapon_rig.weapon_by_key(key).initialize_ammo()


func queue_damage(amount: float) -> void:
	# Test/debug in-tick kill helper; applied on the next fresh tick.
	_pending_damage += amount


func _spawn_corpse(tick: int) -> void:
	var spawner := get_tree().get_first_node_in_group("projectile_spawner")
	if spawner == null:
		return
	var my_peer := input.get_multiplayer_authority()
	# Per-owner limit: remove the oldest owned corpse if at capacity.
	var owned: Array[Corpse] = []
	for node in get_tree().get_nodes_in_group("corpses"):
		var corpse := node as Corpse
		if corpse != null and corpse.owner_peer == my_peer and not corpse.removed:
			owned.append(corpse)
	if owned.size() >= int(MatchConfig.get_value("corpse.max_per_owner")):
		var oldest: Corpse = owned[0]
		for corpse in owned:
			if corpse.spawn_tick < oldest.spawn_tick:
				oldest = corpse
		oldest.destroy()
	# Flat snapshot: [w1_key, w1_mag, w1_reserve, w2_key, w2_mag, w2_reserve, grenades]
	var w1_mag := 0.0
	var w1_reserve := 0.0
	if weapon_rig.slot1 != "":
		var w1 := weapon_rig.weapon_by_key(weapon_rig.slot1)
		w1_mag = w1.mag
		w1_reserve = w1.reserve
	var w2_mag := 0.0
	var w2_reserve := 0.0
	if weapon_rig.slot2 != "":
		var w2 := weapon_rig.weapon_by_key(weapon_rig.slot2)
		w2_mag = w2.mag
		w2_reserve = w2.reserve
	var snapshot: Array = [weapon_rig.slot1, w1_mag, w1_reserve,
		weapon_rig.slot2, w2_mag, w2_reserve, grenade_stock]
	spawner.spawn_corpse(global_position, my_peer, tick, snapshot)


func _process_interact(_tick: int, _is_fresh: bool) -> void:
	# Drag (held) takes priority over loot (press) on the same corpse.
	var drag_range := MatchConfig.get_value("corpse.drag_range_m")
	if input.interact_held:
		var corpse := _nearest_corpse(drag_range)
		if corpse != null:
			is_dragging = true
			corpse.set_dragged_by(input.get_multiplayer_authority())
		else:
			is_dragging = false
	else:
		is_dragging = false
	if input.interact_press_tick == _tick:
		var loot_range := MatchConfig.get_value("corpse.loot_range_m")
		var corpse := _nearest_corpse(loot_range)
		if corpse != null:
			var w: Dictionary = corpse.loot_weapon()
			if not w.is_empty():
				queue_grant(w["key"], 1)


func _nearest_corpse(radius: float) -> Corpse:
	var best: Corpse = null
	var best_dist := radius
	for node in get_tree().get_nodes_in_group("corpses"):
		var corpse := node as Corpse
		if corpse == null or corpse.removed:
			continue
		var d := corpse.global_position.distance_to(global_position)
		if d <= best_dist:
			best_dist = d
			best = corpse
	return best


func _cast_lifebloom(tick: int, is_fresh: bool) -> void:
	var cost := MatchConfig.get_value("resonance.lifebloom_cost")
	if lifebloom_reserved or _in_null_field() or resonance.current < cost:
		if is_fresh:
			cast_denied.emit()
		return
	resonance.reserve(cost)  # held while the field lives; releases empty on death
	lifebloom_reserved = true
	lifebloom_cast_tick = tick
	if is_fresh:
		_place_field("lifebloom")


func _cast_tangle(tick: int, is_fresh: bool) -> void:
	var cost := MatchConfig.get_value("resonance.tangle_cost")
	if tangle_reserved or _in_null_field() or resonance.current < cost:
		if is_fresh:
			cast_denied.emit()
		return
	resonance.reserve(cost)
	tangle_reserved = true
	tangle_cast_tick = tick
	if is_fresh:
		_place_field("tangle")


func _apply_tangle_pull(delta: float) -> void:
	# Deterministic: the victim reads each Tangle's world position and drags
	# itself toward the center. A caster's own Tangle does not pull them.
	# (Team-based ally exemption folds in with team data — for now the caster
	# is the only exemption.)
	if is_wraithed:
		return
	var radius := MatchConfig.get_value("ability.tangle_radius_m")
	var pull_speed := MatchConfig.get_value("ability.tangle_pull_speed")
	var my_peer := input.get_multiplayer_authority()
	for node in get_tree().get_nodes_in_group("tangle_fields"):
		var field := node as PlacedField
		if field == null or field._is_dead() or field.caster_peer == my_peer:
			continue
		var offset := field.global_position - global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist > 0.3 and dist <= radius:
			# Conveyor-style drag: enforce a minimum inward speed so the pull
			# is not swamped by the movement decay (this is the final velocity
			# for move_and_slide this tick).
			var inward := offset.normalized()
			var inward_speed := velocity.dot(inward)
			if inward_speed < pull_speed:
				velocity += inward * (pull_speed - inward_speed)


func _reconcile_field_reservations(tick: int) -> void:
	# Release a held reservation (EMPTY) once the field is gone. A grace
	# window past the cast tick avoids the spawn/replication race where the
	# just-placed field is not yet in its group.
	if lifebloom_reserved and tick > lifebloom_cast_tick + 30 \
			and not _has_owned_field("lifebloom_fields"):
		resonance.release(MatchConfig.get_value("resonance.lifebloom_cost"))
		lifebloom_reserved = false
	if tangle_reserved and tick > tangle_cast_tick + 30 \
			and not _has_owned_field("tangle_fields"):
		resonance.release(MatchConfig.get_value("resonance.tangle_cost"))
		tangle_reserved = false


func _place_field(kind: String) -> void:
	var spawner := get_tree().get_first_node_in_group("projectile_spawner")
	if spawner == null:
		return
	spawner.place_field(kind, _aim_placement_point(), input.get_multiplayer_authority())


func _aim_placement_point() -> Vector3:
	var aim := Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)
	var dir := aim * Vector3.FORWARD
	var from := camera.global_position
	var max_range := MatchConfig.get_value("ability.field_cast_range_m")
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * max_range)
	query.collision_mask = 0b1
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else from + dir * max_range


func _has_owned_field(group: String) -> bool:
	var my_peer := input.get_multiplayer_authority()
	for node in get_tree().get_nodes_in_group(group):
		var field := node as PlacedField
		if field != null and field.caster_peer == my_peer and not field._is_dead():
			return true
	return false


func _in_null_field() -> bool:
	var radius := MatchConfig.get_value("ability.null_radius_m")
	for node in get_tree().get_nodes_in_group("null_fields"):
		var field := node as PlacedField
		if field != null and not field._is_dead() \
				and global_position.distance_to(field.global_position) <= radius:
			return true
	return false


func _throw_grenade(is_fresh: bool, cook_max: int) -> void:
	# Stock decrement + fuse computation are deterministic (state); the
	# actual spawn is a world side-effect, fresh-tick only.
	grenade_stock -= 1
	var fuse_total := int(roundf(MatchConfig.get_value("ability.grenade_fuse_s") * NetworkTime.tickrate))
	var fuse_ticks := maxi(fuse_total - grenade_cook_ticks, fuse_total - cook_max)
	grenade_cook_ticks = 0
	if is_fresh:
		_spawn_grenade(fuse_ticks)


func _spawn_grenade(fuse_ticks: int) -> void:
	var spawner := get_tree().get_first_node_in_group("projectile_spawner")
	if spawner == null:
		return
	var aim := Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)
	var dir := aim * Vector3.FORWARD
	var spawn_pos := camera.global_position + dir * 0.6
	var launch_vel := velocity + dir * MatchConfig.get_value("ability.grenade_throw_speed")
	spawner.throw_grenade(spawn_pos, launch_vel, fuse_ticks, input.get_multiplayer_authority())


func _toggle_wraith(is_fresh: bool) -> void:
	if is_wraithed:
		is_wraithed = false  # instant rematerialize, no cost (decided)
		return
	if _in_null_field():
		if is_fresh:
			cast_denied.emit()
		return
	if resonance.try_spend(MatchConfig.get_value("resonance.wraith_cost")):
		is_wraithed = true
		is_gliding = false  # glide is locked while phased
	elif is_fresh:
		cast_denied.emit()


func _try_slip(is_fresh: bool) -> void:
	# Velocity-directional blink; aim direction when stationary. Passes
	# through solids as long as the DESTINATION is clear; a blocked
	# destination refunds (never spends) and fizzles. Decided 2026-07-16.
	var cost := MatchConfig.get_value("resonance.slip_cost")
	if _in_null_field() or not resonance.can_afford(cost):
		if is_fresh:
			cast_denied.emit()
		return

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var dir: Vector3
	if horizontal.length() > 0.5:
		dir = velocity.normalized()
	else:
		dir = (Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)) * Vector3.FORWARD
	var destination := global_position + dir * MatchConfig.get_value("ability.slip_distance_m")

	if _slip_destination_clear(destination):
		resonance.try_spend(cost)
		global_position = destination
	elif is_fresh:
		cast_denied.emit()


func _slip_destination_clear(destination: Vector3) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, destination + Vector3(0.0, 0.9, 0.0))
	query.collision_mask = 0b1  # world geometry only
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


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

	# Grenades are Node3D (not physics bodies) — nudge them by group.
	for node in get_tree().get_nodes_in_group("grenades"):
		var grenade := node as Grenade
		if grenade == null:
			continue
		var offset := grenade.global_position - global_position
		if offset.length() <= repulse_range:
			grenade.velocity += offset.normalized() * repulse_strength + Vector3(0, 4, 0)


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
