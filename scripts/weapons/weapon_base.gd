# Base for all weapons. Fire pipeline lands in the next task; this task is
# identity + ammo + reload bookkeeping. All numeric config via MatchConfig
# under "weapon.<weapon_key>.*". Mutable vars are rollback state.
class_name WeaponBase
extends Node3D

@export var weapon_key: String = ""
@export var weight_class: int = 0  # 0 light, 1 medium, 2 heavy

# --- Rollback state ---
var mag: float = 0.0
var reserve: float = 0.0
var last_fire_tick: int = -(1 << 30)
var reload_until_tick: int = -(1 << 30)


func config(suffix: String) -> float:
	return MatchConfig.get_value("weapon.%s.%s" % [weapon_key, suffix])


func initialize_ammo() -> void:
	mag = config("mag")
	reserve = config("reserve")


func is_reloading(tick: int) -> bool:
	return tick < reload_until_tick


func start_reload(tick: int) -> void:
	if mag >= config("mag") or reserve <= 0.0 or is_reloading(tick):
		return
	reload_until_tick = tick + int(roundf(config("reload_s") * NetworkTime.tickrate))


func finish_reload_if_due(tick: int) -> void:
	# Called each tick; completes a pending reload exactly once.
	if reload_until_tick != -(1 << 30) and tick >= reload_until_tick:
		var need := config("mag") - mag
		var moved := minf(need, reserve)
		mag += moved
		reserve -= moved
		reload_until_tick = -(1 << 30)


# --- Fire pipeline (netfox rollback-fps pattern) ---

@onready var fire_action: RewindableAction = $FireAction
@onready var _rig: WeaponRig = get_parent()


func _ready() -> void:
	fire_action.mutate(self)
	# The owning controller is registered later via WeaponRig.setup()
	# (it does not exist yet when child _ready runs).


func _controller() -> FPSController:
	return _rig._controller


func supports_ads() -> bool:
	return false


func ads_zoom() -> float:
	return config("ads_zoom")


func _wants_fire(tick: int) -> bool:
	# Edge press-tick: semi-auto default.
	return _controller().input.fire_press_tick == tick


func _can_fire(tick: int) -> bool:
	return _rig.active_weapon() == self \
		and not _controller().is_wraithed \
		and not is_reloading(tick) \
		and mag > 0.0 \
		and NetworkTime.seconds_between(last_fire_tick, tick) >= config("fire_interval_s")


func _rollback_tick(delta: float, tick: int, _is_fresh: bool) -> void:
	if _controller().rollback_synchronizer.is_predicting():
		return
	_weapon_tick(delta, tick)
	if mag <= 0.0 and _rig.active_weapon() == self and not is_reloading(tick):
		start_reload(tick)

	fire_action.set_active(_wants_fire(tick) and _can_fire(tick))
	match fire_action.get_status():
		RewindableAction.CONFIRMING, RewindableAction.ACTIVE:
			_fire(tick)
		RewindableAction.CANCELLING:
			fire_action.erase_context()


func _weapon_tick(_delta: float, _tick: int) -> void:
	pass


func _fire(tick: int) -> void:
	last_fire_tick = tick
	mag -= 1.0
	for dir in _shot_directions(tick):
		_hitscan(dir, tick)
	_on_fire_tick(tick)


func _aim_basis() -> Basis:
	var input := _controller().input
	return Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)


func _shot_directions(_tick: int) -> Array[Vector3]:
	return [_aim_basis() * Vector3.FORWARD]


func _on_fire_tick(_tick: int) -> void:
	pass


func _falloff(distance: float) -> float:
	var start := config("falloff_start_m")
	var end := config("falloff_end_m")
	if distance <= start:
		return 1.0
	if distance >= end:
		return config("falloff_min_mult")
	return lerpf(1.0, config("falloff_min_mult"), (distance - start) / (end - start))


func _hitscan(direction: Vector3, tick: int) -> void:
	var me := _controller()
	var from := me.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * 200.0)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0b10011  # world (1) + hit zones (2) + Tangle block (5)
	var excludes: Array[RID] = [me.get_rid()]
	for zone_area: Area3D in me.get_node("HitZones").get_children():
		excludes.append(zone_area.get_rid())
	query.exclude = excludes
	var result := me.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Object = result.collider
	# Tangle blocks direct fire: the ray stops at the vortex, no damage past.
	if collider is StaticBody3D and collider.is_in_group("tangle_block"):
		return
	if collider is Area3D and collider.has_meta("player"):
		var victim: FPSController = collider.get_meta("player")
		if victim == me:
			return
		var dmg := config("damage") * _falloff(from.distance_to(result.position))
		victim.take_zone_damage(dmg, weapon_key, str(collider.get_meta("zone")), me, tick)
		NetworkRollback.mutate(victim)
