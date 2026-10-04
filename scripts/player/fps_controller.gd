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
## Free loadout: pistol only (slot 2). Slot 1 stays empty until buy.
@export var default_slot1: String = ""
@export var default_slot2: String = "pistol"

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Rollback state (registered as state_properties) ---
var is_gliding: bool = false
var glide_ticks_remaining: int = 0
# Ground jump once per contact: disarmed on takeoff, re-armed only after a real land.
var jump_armed: bool = true
# One contextual jump→glide per airborne period (not unlimited multi-jump).
var air_glide_from_jump_available: bool = true
var last_down_repulse_tick: int = -(1 << 30)
var health: float = 100.0
var bleed_ticks_remaining: int = 0
var bleed_hp_per_s: float = 0.0
var is_dead: bool = false
var is_wraithed: bool = false
var is_dragging: bool = false
var grenade_stock: int = 0
var grenade_cook_ticks: int = 0
var null_stock: int = 0
## Purchased kit flags (view + cast gates). Not rollback state — buy/refund
## apply via queue on fresh ticks, same pattern as weapon grants.
var kit_owned: Dictionary = {}
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
# Familiar (G5 W3): held reservation while a live owned Familiar exists.
var familiar_reserved: bool = false
var familiar_cast_tick: int = -(1 << 30)
# Pulse Sight / Smart Rig / Overclock (G5 W3 augments).
var pulse_sight_ticks_remaining: int = 0
var pulse_sight_reserved: bool = false
var smart_rig_active: bool = false
var smart_rig_reserved: bool = false
var overclock_active: bool = false
var overclock_reserved: bool = false
var overclock_grace_ticks: int = 0
var overclock_reset_ticks: int = 0

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
var _pending_clear_keys: Array[String] = []
var _pending_grenade_stock: int = -1
var _pending_null_stock: int = -1
var _pending_kit_grants: Array[String] = []
var _pending_kit_revokes: Array[String] = []

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

# View-only blade prop poses (not rollback state).
const _BLADE_REST_ROT := Vector3(-0.26, -0.61, 0.35)  # ~(-15, -35, 20) deg
const _BLADE_WINDUP_ROT := Vector3(-0.44, 0.96, 0.52)  # ~(-25, 55, 30) deg
const _BLADE_FOLLOW_ROT := Vector3(0.09, -1.66, -0.17)  # ~(5, -95, -10) deg
var _blade_swing_tween: Tween


func _ready() -> void:
	add_to_group("players")
	for zone_area: Area3D in $HitZones.get_children():
		zone_area.set_meta("zone", zone_area.name.to_lower())
		zone_area.set_meta("player", self)
	_apply_archetype_config()
	weapon_rig.setup(self)
	if default_slot2 != "":
		weapon_rig.grant(default_slot2, 2)
	if default_slot1 != "":
		weapon_rig.grant(default_slot1, 1)
	# Prefer primary when present; otherwise hold free pistol in slot 2.
	if weapon_rig.slot1 == "" and weapon_rig.slot2 != "":
		weapon_rig.active_slot = 2
	# Input authority may have been reassigned by a spawner before _ready.
	rollback_synchronizer.process_settings()
	var is_local := input.is_multiplayer_authority()
	camera.current = is_local
	if is_local and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Free kit only: pistol + 2 grenades. Everything else is purchased.
	grant_free_starters()
	_setup_playtest_body_mesh(is_local)


func _process(_delta: float) -> void:
	# Camera pitch is view-only (never rolled back); yaw is applied to the
	# body in _rollback_tick from recorded input.
	var active := weapon_rig.active_weapon() if weapon_rig != null else null
	var blade_out := active != null and active.weapon_key == "blade"

	if input.is_multiplayer_authority():
		# Smart Rig forced view is local input shaping (like stick look).
		if smart_rig_active and has_equipped("smart_rig"):
			_apply_smart_rig_view(_delta)
		camera.rotation.x = input.local_pitch
		# ADS zoom is view-only feedback.
		var target_fov := 75.0
		if active != null and input.ads and active.supports_ads():
			var zoom := active.ads_zoom()
			if smart_rig_active:
				zoom *= MatchConfig.get_value("smart_rig.passive_zoom")
			target_fov = 75.0 / zoom
		camera.fov = lerpf(camera.fov, target_fov, minf(10.0 * _delta, 1.0))
		# Blade wields in third person (view-only camera swap).
		if blade_out != third_person_camera.current:
			third_person_camera.current = blade_out
			camera.current = not blade_out
		if blade_out:
			third_person_rig.rotation = Vector3(input.local_pitch * 0.5, 0, 0)
		# Controller-only aim assist: reticle friction while an enemy is in
		# view. Mouse look never reads look_rate_scale (decided design).
		# Mult/range come from local InputBindings prefs (Controls menu).
		var slow_mult := InputBindings.stick_slowdown_mult
		var slow_range := InputBindings.stick_slowdown_range_m
		input.look_rate_scale = (
			slow_mult if enemy_under_reticle(slow_range) else 1.0
		)

	# Local FP hides the capsule; blade TP shows body + stick. Remotes always
	# keep the capsule; stick only while blade is equipped.
	_sync_playtest_body_for_view(blade_out)
	_update_playtest_state_silhouette()
	_update_smart_rig_wedge()


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
	# Glide Harness reservation only while equipped.
	if has_equipped("glide"):
		resonance.reserve(_glide_harness_reserve_amount())
	resonance.fill_to_cap()
	health = _config("max_health")
	# Restock only equipped consumables (free grenades always equipped at start).
	grenade_cook_ticks = 0
	if has_equipped("grenades"):
		grenade_stock = int(MatchConfig.get_value("ability.grenade_stock"))
	else:
		grenade_stock = 0
	if has_equipped("null_charge"):
		null_stock = int(MatchConfig.get_value("ability.null_stock"))
	else:
		null_stock = 0


func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if _has_pending_respawn and is_fresh:
		_apply_pending_respawn()
	if _has_pending_reclaim and is_fresh:
		_apply_pending_reclaim()
	if not _pending_grants.is_empty() and is_fresh:
		for grant in _pending_grants:
			weapon_rig.grant(grant[0], grant[1])
		_pending_grants.clear()
	if not _pending_clear_keys.is_empty() and is_fresh:
		for key in _pending_clear_keys:
			weapon_rig.clear_key(key)
		_pending_clear_keys.clear()
	if _pending_grenade_stock >= 0 and is_fresh:
		grenade_stock = _pending_grenade_stock
		_pending_grenade_stock = -1
	if _pending_null_stock >= 0 and is_fresh:
		null_stock = _pending_null_stock
		_pending_null_stock = -1
	if is_fresh and not _pending_kit_grants.is_empty():
		for item in _pending_kit_grants:
			_apply_kit_grant(item)
		_pending_kit_grants.clear()
	if is_fresh and not _pending_kit_revokes.is_empty():
		for item in _pending_kit_revokes:
			_apply_kit_revoke(item)
		_pending_kit_revokes.clear()

	# Death is simulation state: a dead body freezes where it fell (full
	# body persistence is a pillar; the corpse system extends this later).
	if is_dead:
		return
	if _pending_damage > 0.0 and is_fresh:
		health = maxf(health - _pending_damage, 0.0)
		_pending_damage = 0.0
	if health <= 0.0:
		is_dead = true
		revived_by_peer = 0  # a dead ally no longer carries the reviver link
		if is_fresh:
			_spawn_corpse(tick)
			died.emit(input.get_multiplayer_authority(), last_attacker_peer)
		return

	transform.basis = Basis(Vector3.UP, input.aim_yaw)
	_force_update_is_on_floor()
	# Re-arm ground jump / jump→glide only after a firm landing (not mid-launch).
	if is_on_floor() and velocity.y <= 0.01:
		jump_armed = true
		air_glide_from_jump_available = true

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

	# All Manifestations / Augments / equipment: only if purchased into kit.
	_process_equipped_kit(delta, tick, is_fresh, jump_pressed)
	_reconcile_field_reservations(tick)
	_process_reclaim_bleedout()
	_process_interact(tick, is_fresh)

	var base_speed := walk_speed if is_wraithed else (sprint_speed if input.sprint else walk_speed)
	var speed := base_speed * weapon_rig.carry_weight_mult() * _overclock_move_mult()
	if input.crouch:
		speed *= MatchConfig.get_value("movement.crouch_speed_mult")
	var direction := (transform.basis * Vector3(input.movement.x, 0, input.movement.y)).normalized()

	if is_gliding:
		glide_ticks_remaining -= 1
		# Cancel when landing (not while launching upward off the ground).
		if glide_ticks_remaining <= 0 or (is_on_floor() and velocity.y <= 0.01):
			is_gliding = false
		else:
			# Glide only softens fall + air control. Upward impulse comes only
			# from Repulse+Glide combo launch (or external forces like an
			# enemy Repulse hit) — never from jump while gliding.
			velocity.y -= gravity * delta * glide_gravity_mult
			if direction:
				velocity.x = move_toward(velocity.x, direction.x * glide_speed, glide_air_control * delta)
				velocity.z = move_toward(velocity.z, direction.z * glide_speed, glide_air_control * delta)
			velocity.y = maxf(velocity.y, -6.0)
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta
		# Ground jump only — never a free air jump. Requires jump_armed so
		# multi-frame floor contact after takeoff cannot re-fire.
		if jump_pressed and is_on_floor() and jump_armed:
			velocity.y = jump_velocity * _overclock_jump_mult()
			jump_armed = false
			air_glide_from_jump_available = false
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
	# Smart Rig active: no friendly fire from direct gunfire (attacker has FF off).
	if attacker != null and attacker != self and attacker.smart_rig_active:
		var my_team := _reclaim_team_of(input.get_multiplayer_authority())
		var at_team := _reclaim_team_of(attacker.input.get_multiplayer_authority())
		if my_team != -1 and my_team == at_team:
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


func queue_clear_weapon(key: String) -> void:
	_pending_clear_keys.append(key)


func queue_set_grenade_stock(amount: int) -> void:
	_pending_grenade_stock = amount


func queue_set_null_stock(amount: int) -> void:
	_pending_null_stock = amount


## Purchased + delivered gear is "equipped" for this life (buy = equip).
func has_equipped(item: String) -> bool:
	return kit_owned.has(item)


## Alias kept for tests / call sites written against owns_kit.
func owns_kit(item: String) -> bool:
	return has_equipped(item)


## Free starter loadout: pistol + grenades only (no primary / no abilities).
func grant_free_starters() -> void:
	_apply_kit_grant("grenades")
	if default_slot2 != "":
		kit_owned[default_slot2] = true


## Immediate equip (tests / offline). Economy buy path uses queue_grant_kit.
func grant_kit(item: String) -> void:
	_apply_kit_grant(item)


func queue_grant_kit(item: String) -> void:
	_pending_kit_grants.append(item)


func queue_revoke_kit(item: String) -> void:
	_pending_kit_revokes.append(item)


func _glide_harness_reserve_amount() -> float:
	return MatchConfig.get_value("resonance.glide_harness_reservation") * _config("tech_mult")


func _is_weapon_item(item: String) -> bool:
	return MatchConfig.DEFAULTS.has("weapon.%s.damage" % item)


## True when this press-tick fires *and* the item is equipped.
## Unowned press on a fresh tick emits cast_denied (feedback for locked binds).
func _kit_press(item: String, press_tick: int, tick: int, is_fresh: bool) -> bool:
	if press_tick != tick:
		return false
	if has_equipped(item):
		return true
	if is_fresh:
		cast_denied.emit()
	return false


## Single path for all kit gear: presses, consumables, glide, sustained augments.
func _process_equipped_kit(
		delta: float, tick: int, is_fresh: bool, jump_pressed: bool
) -> void:
	# Wraith: enter/exit only if equipped; forced out if unequipped mid-form.
	if _kit_press("wraith", input.wraith_press_tick, tick, is_fresh):
		_toggle_wraith(is_fresh)
	if is_wraithed:
		if not has_equipped("wraith"):
			is_wraithed = false
		else:
			resonance.drain(MatchConfig.get_value("resonance.wraith_drain_per_s") * delta)
			if resonance.current <= 0.0:
				is_wraithed = false

	if not is_wraithed:
		if _kit_press("repulse", input.repulse_press_tick, tick, is_fresh):
			_try_cast_repulse(tick, is_fresh)
		if _kit_press("slip", input.slip_press_tick, tick, is_fresh):
			_try_slip(is_fresh)
		if has_equipped("grenades"):
			var cook_max := int(roundf(
				MatchConfig.get_value("ability.grenade_cook_max_s") * NetworkTime.tickrate))
			if input.grenade_held and grenade_stock > 0:
				grenade_cook_ticks = mini(grenade_cook_ticks + 1, cook_max)
			if input.grenade_press_tick == tick and grenade_stock > 0:
				_throw_grenade(is_fresh, cook_max)
		else:
			grenade_cook_ticks = 0
		if _kit_press("lifebloom", input.lifebloom_press_tick, tick, is_fresh):
			_cast_lifebloom(tick, is_fresh)
		if _kit_press("tangle", input.tangle_press_tick, tick, is_fresh):
			_cast_tangle(tick, is_fresh)
		if _kit_press("null_charge", input.null_press_tick, tick, is_fresh):
			if null_stock > 0:
				null_stock -= 1
				if is_fresh:
					_place_field("null_charge")
			elif is_fresh:
				cast_denied.emit()
		if _kit_press("reclaim", input.reclaim_press_tick, tick, is_fresh):
			_cast_reclaim(tick, is_fresh)
		if _kit_press("familiar", input.familiar_press_tick, tick, is_fresh):
			_cast_familiar(tick, is_fresh)
		if _kit_press("pulse_sight", input.pulse_sight_press_tick, tick, is_fresh):
			_cast_pulse_sight(tick, is_fresh)
		if _kit_press("smart_rig", input.smart_rig_press_tick, tick, is_fresh):
			_toggle_smart_rig(is_fresh)
		if _kit_press("overclock", input.overclock_press_tick, tick, is_fresh):
			_toggle_overclock(is_fresh)

	# Sustained augment ticks only while that gear remains equipped.
	if has_equipped("pulse_sight"):
		_process_pulse_sight_tick()
	if has_equipped("smart_rig"):
		_process_smart_rig_tick(delta)
	if has_equipped("overclock"):
		_process_overclock_tick(delta)

	# Glide Harness: key press or one contextual jump→glide while airborne.
	if not is_wraithed and has_equipped("glide"):
		var jump_wants_air_glide := (
			jump_pressed and not is_on_floor() and not is_gliding
			and air_glide_from_jump_available
		)
		var wants_glide := input.glide_press_tick == tick or jump_wants_air_glide
		if wants_glide and not is_gliding:
			if jump_wants_air_glide:
				air_glide_from_jump_available = false
			_try_deploy_glide(tick)


func _try_cast_repulse(tick: int, is_fresh: bool) -> void:
	if not _in_null_field() and resonance.try_spend(
			MatchConfig.get_value("resonance.repulse_cost")):
		_cast_repulse(tick, is_fresh)
	elif is_fresh:
		# Hard block (decided): no overdraft; Null suppresses casting.
		cast_denied.emit()


func _apply_kit_grant(item: String) -> void:
	var first_equip := not kit_owned.has(item)
	kit_owned[item] = true
	if _is_weapon_item(item):
		# Always refresh ammo on grant (buy / re-deliver).
		weapon_rig.grant(item, 2 if item == "pistol" else 1)
	elif item == "glide":
		if first_equip:
			resonance.reserve(_glide_harness_reserve_amount())
	elif item == "grenades":
		grenade_stock = int(MatchConfig.get_value("ability.grenade_stock"))
	elif item == "null_charge":
		null_stock = int(MatchConfig.get_value("ability.null_stock"))


func _apply_kit_revoke(item: String) -> void:
	if not kit_owned.has(item):
		return
	if _is_weapon_item(item):
		weapon_rig.clear_key(item)
	elif item == "glide":
		resonance.release(_glide_harness_reserve_amount())
		is_gliding = false
		glide_ticks_remaining = 0
	elif item == "grenades":
		grenade_stock = 0
		grenade_cook_ticks = 0
	elif item == "null_charge":
		null_stock = 0
	elif item == "wraith":
		is_wraithed = false
	elif item == "pulse_sight":
		if pulse_sight_reserved:
			resonance.release(MatchConfig.get_value("resonance.pulse_sight_cost"))
		pulse_sight_ticks_remaining = 0
		pulse_sight_reserved = false
	elif item == "smart_rig":
		if smart_rig_reserved:
			resonance.release(MatchConfig.get_value("resonance.smart_rig_cost"))
		smart_rig_active = false
		smart_rig_reserved = false
	elif item == "overclock":
		if overclock_reserved:
			resonance.release(MatchConfig.get_value("resonance.overclock_cost"))
		overclock_active = false
		overclock_reserved = false
		overclock_grace_ticks = 0
		overclock_reset_ticks = 0
	kit_owned.erase(item)


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
	reclaim_reserved = false
	revived_by_peer = 0
	familiar_reserved = false
	_clear_augment_state()
	_apply_archetype_config()
	for key in [weapon_rig.slot1, weapon_rig.slot2]:
		if key != "":
			weapon_rig.weapon_by_key(key).initialize_ammo()


func _apply_pending_reclaim() -> void:
	# Runs in the revived player's OWN tick (dispatched before the is_dead
	# return), so these rollback-state writes stick. Revives at a fraction of
	# max health with the corpse's unlooted gear restored.
	_has_pending_reclaim = false
	is_dead = false
	last_attacker_peer = 0
	bleed_ticks_remaining = 0
	bleed_hp_per_s = 0.0
	is_gliding = false
	velocity = Vector3.ZERO
	global_position = _pending_reclaim_pos
	_apply_archetype_config()
	var snap := _pending_reclaim_snapshot
	if snap.size() >= 7:
		_restore_reclaim_weapon(snap[0], 1 if snap[0] != "pistol" else 2, snap[1], snap[2])
		_restore_reclaim_weapon(snap[3], 1 if snap[3] != "pistol" else 2, snap[4], snap[5])
		grenade_stock = int(snap[6])
	health = _config("max_health") * MatchConfig.get_value("reclaim.revive_health_frac")
	revived_by_peer = _pending_reclaim_reviver


func _restore_reclaim_weapon(key: String, slot: int, mag: float, reserve: float) -> void:
	if key == "":
		return
	weapon_rig.grant(key, slot)
	var w := weapon_rig.weapon_by_key(key)
	if w != null:
		w.mag = mag
		w.reserve = reserve


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
		# CTF flag pickup (host-authoritative objective).
		for node in get_tree().get_nodes_in_group("ctf_objective"):
			var flag := node as CtfObjective
			if flag != null:
				flag.try_pickup(self)


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


func _cast_reclaim(tick: int, is_fresh: bool) -> void:
	# Corpse-gated radius revive. Cross-node effects go through plain-pending +
	# own-tick apply (the corpse-drag lesson) — never a direct rollback write.
	var cost := MatchConfig.get_value("resonance.reclaim_cost")
	var targets := _reclaim_targets(MatchConfig.get_value("reclaim.radius_m"))
	if reclaim_reserved or _in_null_field() or resonance.current < cost or targets.is_empty():
		if is_fresh:
			cast_denied.emit()
		return
	for corpse in targets:
		var revive_owner := _find_player_by_peer(corpse.owner_peer)
		if revive_owner == null or not revive_owner.is_dead:
			continue
		revive_owner.queue_reclaim_revive(corpse.global_position,
			input.get_multiplayer_authority(), _corpse_snapshot(corpse))
		corpse.queue_reclaim_destroy()
	resonance.reserve(cost)
	reclaim_reserved = true
	reclaim_cast_tick = tick
	if is_fresh and PlaytestViz.enabled():
		var r := MatchConfig.get_value("reclaim.radius_m")
		PlaytestViz.flash_sphere(get_tree(), global_position, r,
			Color(0.4, 0.95, 0.55, 0.28), 0.45)
		var bus := get_node_or_null("/root/PlaytestFxBus")
		if bus != null and bus.has_method("push_log"):
			bus.call("push_log", "reclaim cast")


func _reclaim_targets(radius: float) -> Array:
	# Dead allies' corpses in range: same team (fallback to any-dead when the
	# caster has no team, e.g. Arena/headless).
	var my_team := _reclaim_team_of(input.get_multiplayer_authority())
	var out: Array = []
	for node in get_tree().get_nodes_in_group("corpses"):
		var corpse := node as Corpse
		if corpse == null or corpse.removed:
			continue
		if corpse.global_position.distance_to(global_position) > radius:
			continue
		var revive_owner := _find_player_by_peer(corpse.owner_peer)
		if revive_owner == null or not revive_owner.is_dead:
			continue
		if my_team != -1 and _reclaim_team_of(corpse.owner_peer) != my_team:
			continue
		out.append(corpse)
	return out


func _reclaim_team_of(peer: int) -> int:
	var ms := get_tree().get_first_node_in_group("match_state") as MatchState
	return ms.team_of(peer) if ms != null else -1


func _find_player_by_peer(peer: int) -> FPSController:
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as FPSController
		if p != null and p.input.get_multiplayer_authority() == peer:
			return p
	return null


func _corpse_snapshot(corpse: Corpse) -> Array:
	return [corpse.w1_key, corpse.w1_mag, corpse.w1_reserve,
		corpse.w2_key, corpse.w2_mag, corpse.w2_reserve, corpse.grenades]


func queue_reclaim_revive(pos: Vector3, reviver_peer: int, snapshot: Array) -> void:
	_pending_reclaim_pos = pos
	_pending_reclaim_reviver = reviver_peer
	_pending_reclaim_snapshot = snapshot
	_has_pending_reclaim = true


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
	# Reclaim: held while any revived ally lives; release once none remain
	# (grace window covers the revive apply landing a tick after the cast).
	if reclaim_reserved and tick > reclaim_cast_tick + 30 \
			and not _any_revived_alive(input.get_multiplayer_authority()):
		resonance.release(MatchConfig.get_value("resonance.reclaim_cost"))
		reclaim_reserved = false
	# Familiar: held while a live owned minion exists.
	if familiar_reserved and tick > familiar_cast_tick + 30 \
			and not _has_owned_familiar():
		resonance.release(MatchConfig.get_value("resonance.familiar_cost"))
		familiar_reserved = false


func _cast_familiar(tick: int, is_fresh: bool) -> void:
	# Summon or re-task the combat minion. Aim ray: ground hit within
	# guard_range_m -> GUARD there; else FOLLOW. Live Familiar is re-moded
	# via plain-pending (applied in the Familiar's own tick).
	var cost := MatchConfig.get_value("resonance.familiar_cost")
	var guard_range := MatchConfig.get_value("familiar.guard_range_m")
	var aim_point := _aim_placement_point_range(guard_range)
	var base_mode := Familiar.FOLLOW
	var guard := Vector3.ZERO
	if _aim_hits_world(guard_range):
		base_mode = Familiar.GUARD
		guard = aim_point

	var existing := _find_owned_familiar()
	if existing != null:
		existing.queue_set_mode(base_mode, guard)
		return
	if _in_null_field() or resonance.current < cost:
		if is_fresh:
			cast_denied.emit()
		return
	resonance.reserve(cost)
	familiar_reserved = true
	familiar_cast_tick = tick
	if is_fresh:
		var spawner := get_tree().get_first_node_in_group("projectile_spawner")
		if spawner != null:
			var spawn_pos := global_position + Vector3(0.0, 0.0, -1.0)
			spawner.spawn_familiar(spawn_pos, input.get_multiplayer_authority(),
				base_mode, guard)


func _aim_placement_point_range(max_range: float) -> Vector3:
	var aim := Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)
	var dir := aim * Vector3.FORWARD
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * max_range)
	query.collision_mask = 0b1
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else from + dir * max_range


func _aim_hits_world(max_range: float) -> bool:
	var aim := Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)
	var dir := aim * Vector3.FORWARD
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * max_range)
	query.collision_mask = 0b1
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _has_owned_familiar() -> bool:
	return _find_owned_familiar() != null


func _find_owned_familiar() -> Familiar:
	var my_peer := input.get_multiplayer_authority()
	for node in get_tree().get_nodes_in_group("familiars"):
		var fam := node as Familiar
		if fam != null and fam.caster_peer == my_peer and not fam._is_dead():
			return fam
	return null


func _clear_augment_state() -> void:
	if pulse_sight_reserved:
		resonance.release(MatchConfig.get_value("resonance.pulse_sight_cost"))
	if smart_rig_reserved:
		resonance.release(MatchConfig.get_value("resonance.smart_rig_cost"))
	if overclock_reserved:
		resonance.release(MatchConfig.get_value("resonance.overclock_cost"))
	pulse_sight_ticks_remaining = 0
	pulse_sight_reserved = false
	smart_rig_active = false
	smart_rig_reserved = false
	overclock_active = false
	overclock_reserved = false
	overclock_grace_ticks = 0
	overclock_reset_ticks = 0


func _cast_pulse_sight(tick: int, is_fresh: bool) -> void:
	var cost := MatchConfig.get_value("resonance.pulse_sight_cost")
	if pulse_sight_reserved or _in_null_field() or resonance.current < cost:
		if is_fresh:
			cast_denied.emit()
		return
	resonance.reserve(cost)
	pulse_sight_reserved = true
	pulse_sight_ticks_remaining = int(roundf(
		MatchConfig.get_value("pulse_sight.duration_s") * NetworkTime.tickrate))


func _process_pulse_sight_tick() -> void:
	if pulse_sight_ticks_remaining <= 0:
		return
	pulse_sight_ticks_remaining -= 1
	if pulse_sight_ticks_remaining <= 0 and pulse_sight_reserved:
		resonance.release(MatchConfig.get_value("resonance.pulse_sight_cost"))
		pulse_sight_reserved = false


func is_pulse_sight_active() -> bool:
	return pulse_sight_ticks_remaining > 0


## Peers this local player may see through walls (self Pulse Sight, or shared
## chrome-network with allies who also run Pulse Sight / Smart Rig).
func pulse_sight_revealed_peers() -> Array[int]:
	var out: Array[int] = []
	if not is_pulse_sight_active() and not smart_rig_active:
		return out
	var radius := MatchConfig.get_value("pulse_sight.radius_m")
	var wraith_r := MatchConfig.get_value("pulse_sight.wraith_radius_m")
	var my_peer := input.get_multiplayer_authority()
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as FPSController
		if p == null or p == self or p.is_dead:
			continue
		# Shared reveal: allies with Eye chrome (Pulse Sight active or Smart Rig)
		# also contribute when *we* have chrome; viewer must own reveal source.
		if not is_pulse_sight_active() and not smart_rig_active:
			continue
		var d := global_position.distance_to(p.global_position)
		var max_r := wraith_r if p.is_wraithed else radius
		if d <= max_r:
			out.append(p.input.get_multiplayer_authority())
	return out


func _toggle_smart_rig(is_fresh: bool) -> void:
	if smart_rig_active:
		smart_rig_active = false
		if smart_rig_reserved:
			resonance.release(MatchConfig.get_value("resonance.smart_rig_cost"))
			smart_rig_reserved = false
		return
	var cost := MatchConfig.get_value("resonance.smart_rig_cost")
	if _in_null_field() or resonance.current < cost:
		if is_fresh:
			cast_denied.emit()
		return
	resonance.reserve(cost)
	smart_rig_reserved = true
	smart_rig_active = true


func _process_smart_rig_tick(_delta: float) -> void:
	# View tracking is applied in _process (local view); sim tick only needs
	# the active flag for FF rules / reload etc.
	pass


func _apply_smart_rig_view(delta: float) -> void:
	var target := _nearest_track_target()
	if target == null:
		return
	var to := target.global_position - camera.global_position
	if to.length_squared() < 0.01:
		return
	var desired_yaw := atan2(-to.x, -to.z)
	var desired_pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var max_step := deg_to_rad(MatchConfig.get_value("smart_rig.track_rate_deg_s")) * delta
	input.local_yaw = _approach_angle(input.local_yaw, desired_yaw, max_step)
	input.local_pitch = clampf(
		_approach_angle(input.local_pitch, desired_pitch, max_step),
		-PI / 2.0, PI / 2.0)


func _nearest_track_target() -> FPSController:
	var best: FPSController = null
	var best_d := INF
	var my_peer := input.get_multiplayer_authority()
	var my_team := _reclaim_team_of(my_peer)
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as FPSController
		if p == null or p == self or p.is_dead or p.is_wraithed:
			continue
		var peer := p.input.get_multiplayer_authority()
		if peer == my_peer:
			continue
		if my_team != -1 and _reclaim_team_of(peer) == my_team:
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _approach_angle(current: float, target: float, max_step: float) -> float:
	var diff := wrapf(target - current, -PI, PI)
	if absf(diff) <= max_step:
		return target
	return current + signf(diff) * max_step


func _toggle_overclock(is_fresh: bool) -> void:
	if overclock_active:
		overclock_active = false
		if overclock_reserved:
			resonance.release(MatchConfig.get_value("resonance.overclock_cost"))
			overclock_reserved = false
		# All-or-nothing grace reset after deactivation.
		overclock_reset_ticks = int(roundf(
			MatchConfig.get_value("overclock.grace_reset_s") * NetworkTime.tickrate))
		overclock_grace_ticks = 0
		return
	var cost := MatchConfig.get_value("resonance.overclock_cost")
	if _in_null_field() or resonance.current < cost:
		if is_fresh:
			cast_denied.emit()
		return
	resonance.reserve(cost)
	overclock_reserved = true
	overclock_active = true
	if overclock_reset_ticks > 0:
		# Reactivating before reset: drain immediately (no grace).
		overclock_grace_ticks = 0
		overclock_reset_ticks = int(roundf(
			MatchConfig.get_value("overclock.grace_reset_s") * NetworkTime.tickrate))
	else:
		overclock_grace_ticks = int(roundf(
			MatchConfig.get_value("overclock.grace_s") * NetworkTime.tickrate))


func _process_overclock_tick(delta: float) -> void:
	if overclock_reset_ticks > 0:
		overclock_reset_ticks = maxi(0, overclock_reset_ticks - 1)
	if not overclock_active:
		return
	if overclock_grace_ticks > 0:
		overclock_grace_ticks -= 1
	else:
		# HP drain after grace (does not mark combat).
		health = maxf(health - MatchConfig.get_value("overclock.hp_drain_per_s") * delta, 0.0)


func _overclock_move_mult() -> float:
	# Passive mults require ownership gating (deferred); apply only while Overdrive
	# is active so baseline movement/weapon tests stay unscaled.
	if overclock_active:
		return MatchConfig.get_value("overclock.active_move_mult")
	return 1.0


func _overclock_jump_mult() -> float:
	if overclock_active:
		return MatchConfig.get_value("overclock.active_jump_mult")
	return 1.0


func overclock_reload_mult() -> float:
	if overclock_active:
		return MatchConfig.get_value("overclock.active_reload_mult")
	return 1.0


func _process_reclaim_bleedout() -> void:
	# Victim-side pull (Tangle pattern): a revived ally bleeds out once its
	# reviver is dead or gone. One-shot — clears the link after applying.
	if revived_by_peer == 0:
		return
	var reviver := _find_player_by_peer(revived_by_peer)
	if reviver == null or reviver.is_dead:
		apply_bleed(MatchConfig.get_value("reclaim.bleedout_hp_per_s"),
			MatchConfig.get_value("reclaim.bleedout_duration_s"))
		revived_by_peer = 0


func _any_revived_alive(reviver_peer: int) -> bool:
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as FPSController
		if p != null and not p.is_dead and p.revived_by_peer == reviver_peer:
			return true
	return false


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
		var start_pos := global_position
		resonance.try_spend(cost)
		global_position = destination
		if is_fresh and PlaytestViz.enabled() \
				and MatchConfig.get_value("debug.viz.show_slip_ghost") > 0.5:
			PlaytestViz.flash_line(get_tree(), start_pos, global_position,
				Color(0.2, 1.0, 0.4, 0.7))
			PlaytestViz.flash_slip_ghost(get_tree(), global_position)
			var bus := get_node_or_null("/root/PlaytestFxBus")
			if bus != null and bus.has_method("notify_generic"):
				bus.call("notify_generic", &"slip", {
					"from": start_pos,
					"to": global_position,
					"peer": input.get_multiplayer_authority(),
				})
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
		# Match sim query: sphere of repulse_range centered ahead of cast dir.
		var viz_pos := global_position + cast_dir * 4.0
		PlaytestViz.flash_sphere(get_tree(), viz_pos, repulse_range,
			Color(0.35, 0.75, 1.0, 0.28), 0.3)
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
	if not has_equipped("glide"):
		return
	var window_ticks := int(roundf(combo_window * NetworkTime.tickrate))
	var is_combo := (tick - last_down_repulse_tick <= window_ticks) and input.aim_pitch < -0.4

	is_gliding = true
	glide_ticks_remaining = int(roundf(glide_duration * NetworkTime.tickrate))

	if is_combo:
		velocity.y = combo_launch_velocity
		print(">>> GLIDE LAUNCH COMBO! (tick=%d)" % tick)
	else:
		# Soften fall only — never grant free upward impulse on deploy
		# (jump or key). Vertical launch is combo-only.
		if velocity.y < 0.0:
			velocity.y *= 0.3
		print("Glide deployed (tick=%d)" % tick)


## Capsule body + held-blade stick + simple viewmodel for playtest silhouettes.
## Local FP starts with body hidden (camera is inside it); remotes stay visible.
## Blade equip toggles local body + stick via _sync_playtest_body_for_view.
func _setup_playtest_body_mesh(is_local: bool) -> void:
	if not PlaytestViz.enabled():
		return
	if get_node_or_null("PlaytestBody") != null:
		return
	var body := MeshInstance3D.new()
	body.name = "PlaytestBody"
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.8
	body.mesh = cap
	body.position = Vector3(0.0, 0.9, 0.0)
	body.material_override = PlaytestViz.unshaded_mat(Color(0.35, 0.55, 0.85, 0.85))
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Local starts first-person: hide capsule so it doesn't fill the camera.
	# Remotes always show a silhouette.
	body.visible = not is_local
	add_child(body)
	_setup_playtest_blade_prop(body)
	# Simple viewmodel box so fire feels aimed (local only; hidden in blade TP).
	if is_local and weapon_rig != null:
		var stub := MeshInstance3D.new()
		stub.name = "PlaytestViewmodel"
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 0.45)
		stub.mesh = box
		stub.position = Vector3(0.0, 0.0, -0.2)
		stub.material_override = PlaytestViz.unshaded_mat(Color(0.2, 0.2, 0.22, 1.0))
		stub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		weapon_rig.add_child(stub)


## Thin stick on the right side of the capsule (visible when blade is equipped).
func _setup_playtest_blade_prop(body: MeshInstance3D) -> void:
	var pivot := Node3D.new()
	pivot.name = "PlaytestBladePivot"
	# Right hand-ish relative to body mesh center.
	pivot.position = Vector3(0.38, 0.12, 0.08)
	pivot.rotation = _BLADE_REST_ROT
	pivot.visible = false
	body.add_child(pivot)
	var blade := MeshInstance3D.new()
	blade.name = "PlaytestBlade"
	var stick := BoxMesh.new()
	# Long axis along local -Z (character forward).
	stick.size = Vector3(0.04, 0.055, 1.05)
	blade.mesh = stick
	blade.position = Vector3(0.0, 0.0, -0.52)
	blade.material_override = PlaytestViz.unshaded_mat(Color(0.72, 0.74, 0.8, 1.0))
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(blade)


## View-only: body/stick/viewmodel follow blade equip + camera mode.
func _sync_playtest_body_for_view(blade_out: bool) -> void:
	var is_local := input.is_multiplayer_authority()
	var body := get_node_or_null("PlaytestBody") as MeshInstance3D
	if body != null:
		# Remotes always keep a silhouette; local only when blade third-person.
		body.visible = blade_out if is_local else true
		var pivot := body.get_node_or_null("PlaytestBladePivot") as Node3D
		if pivot != null:
			pivot.visible = blade_out
	if not is_local or weapon_rig == null:
		return
	var stub := weapon_rig.get_node_or_null("PlaytestViewmodel") as MeshInstance3D
	if stub != null:
		stub.visible = not blade_out


## View-only: tint PlaytestBody for Wraith / Glide / Overclock state readability.
func _update_playtest_state_silhouette() -> void:
	if not PlaytestViz.enabled():
		return
	if MatchConfig.get_value("debug.viz.show_state_silhouettes") <= 0.5:
		return
	var body := get_node_or_null("PlaytestBody") as MeshInstance3D
	if body == null:
		return
	var col := Color(0.35, 0.55, 0.85, 0.85)
	if is_wraithed:
		col = Color(0.45, 0.55, 0.75, 0.35)
	elif overclock_active:
		col = Color(1.0, 0.45, 0.15, 0.9)
	elif is_gliding:
		col = Color(0.35, 0.9, 1.0, 0.75)
	body.material_override = PlaytestViz.unshaded_mat(col)
	# Soft ring while gliding (recreated cheaply via flash is too noisy; use child).
	var ring := get_node_or_null("PlaytestGlideRing") as MeshInstance3D
	if is_gliding:
		if ring == null:
			ring = MeshInstance3D.new()
			ring.name = "PlaytestGlideRing"
			var tor := TorusMesh.new()
			tor.inner_radius = 0.55
			tor.outer_radius = 0.7
			ring.mesh = tor
			ring.position = Vector3(0.0, 0.15, 0.0)
			ring.material_override = PlaytestViz.unshaded_mat(Color(0.4, 0.95, 1.0, 0.35))
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ring)
		ring.visible = true
	elif ring != null:
		ring.visible = false


## View-only Smart Rig aim wedge (Phase B) — does not deal damage.
func _update_smart_rig_wedge() -> void:
	var wedge := get_node_or_null("PlaytestSmartRigWedge") as MeshInstance3D
	var show := PlaytestViz.enabled() \
			and MatchConfig.get_value("debug.viz.show_smart_rig_wedge") > 0.5 \
			and smart_rig_active and has_equipped("smart_rig")
	if not show:
		if wedge != null:
			wedge.visible = false
		return
	if wedge == null:
		wedge = MeshInstance3D.new()
		wedge.name = "PlaytestSmartRigWedge"
		wedge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wedge)
	var range_m := MatchConfig.get_value("debug.viz.smart_rig_wedge_range_m")
	var half_deg := MatchConfig.get_value("debug.viz.smart_rig_wedge_deg") * 0.5
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(Color(1.0, 0.35, 0.2, 0.75))
	var origin := Vector3(0.0, 1.5, 0.0)
	var yaw := input.aim_yaw if input != null else rotation.y
	var pitch := input.local_pitch if input != null else 0.0
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var forward := basis * Vector3.FORWARD
	var right := basis * Vector3.RIGHT
	var left_dir := (forward * cos(deg_to_rad(half_deg)) - right * sin(deg_to_rad(half_deg))).normalized()
	var right_dir := (forward * cos(deg_to_rad(half_deg)) + right * sin(deg_to_rad(half_deg))).normalized()
	im.surface_add_vertex(origin)
	im.surface_add_vertex(origin + left_dir * range_m)
	im.surface_add_vertex(origin)
	im.surface_add_vertex(origin + right_dir * range_m)
	im.surface_add_vertex(origin + left_dir * range_m)
	im.surface_add_vertex(origin + right_dir * range_m)
	im.surface_end()
	wedge.mesh = im
	wedge.material_override = PlaytestViz.tracer_mat(Color(1.0, 0.35, 0.2, 0.75))
	wedge.visible = true
	# Keep wedge in world-aligned local space under player root.
	wedge.global_position = global_position


## View-only slash on the playtest stick (triggered from BladeWeapon on fresh fire).
func play_blade_swing_fx() -> void:
	var body := get_node_or_null("PlaytestBody") as MeshInstance3D
	if body == null:
		return
	var pivot := body.get_node_or_null("PlaytestBladePivot") as Node3D
	if pivot == null:
		return
	if _blade_swing_tween != null and is_instance_valid(_blade_swing_tween):
		_blade_swing_tween.kill()
	pivot.rotation = _BLADE_WINDUP_ROT
	_blade_swing_tween = create_tween()
	_blade_swing_tween.tween_property(pivot, "rotation", _BLADE_FOLLOW_ROT, 0.1) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_blade_swing_tween.tween_property(pivot, "rotation", _BLADE_REST_ROT, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
