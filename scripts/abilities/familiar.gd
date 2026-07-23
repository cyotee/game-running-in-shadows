# Familiar — rollback-simulated combat minion (G5 Wave 3).
# Mobile PlacedField sibling: FOLLOW / HUNT (ping overlay) / GUARD modes,
# deterministic melee vs enemy players and enemy Familiars, destroyed by Null
# fields, nearby Dwarves, gunfire, or caster death. Free only in _process.
class_name Familiar
extends Node3D

const FOLLOW := 0
const HUNT := 1
const GUARD := 2

# --- Rollback state ---
var hp: float = 100.0
var mode: int = FOLLOW
var guard_pos: Vector3 = Vector3.ZERO
var attack_cooldown_ticks: int = 0

var caster_peer: int = 0
var _freed: bool = false

# Plain-pending re-mode (cross-node write applied in this entity's own tick).
var _pending_mode: int = -1
var _pending_guard_pos: Vector3 = Vector3.ZERO

@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer


func _ready() -> void:
	add_to_group("familiars")
	rollback_synchronizer.process_settings()
	# Aggro + melee rings (MatchConfig meters).
	var aggro := MatchConfig.get_value("familiar.aggro_radius_m")
	var melee := MatchConfig.get_value("familiar.melee_range_m")
	PlaytestViz.attach_disc(self, aggro, Color(1.0, 0.4, 0.2, 0.12))
	PlaytestViz.attach_sphere(self, melee, Color(1.0, 0.2, 0.15, 0.25))


func setup(spawn_position: Vector3, caster: int, start_mode: int, guard: Vector3) -> void:
	position = spawn_position
	caster_peer = caster
	mode = start_mode
	guard_pos = guard
	hp = MatchConfig.get_value("familiar.hp")
	attack_cooldown_ticks = 0


func _process(_delta: float) -> void:
	if _is_dead() and not _freed:
		_freed = true
		queue_free()


func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	if _pending_mode >= 0 and is_fresh:
		mode = _pending_mode
		guard_pos = _pending_guard_pos
		_pending_mode = -1
	if _is_dead():
		return
	if _in_null_field() or _dwarf_in_range():
		hp = 0.0
		return

	var caster := _find_player(caster_peer)
	if caster == null or caster.is_dead:
		return

	var target: Node = null
	var home := global_position

	# HUNT overlay: live enemy-tag ping outranks base FOLLOW/GUARD mode.
	# Base `mode` stays FOLLOW/GUARD (cast/re-mode); ping only redirects target.
	var tag := PingService.latest_enemy_tag(caster_peer)
	if tag != 0:
		var tagged := _find_player(tag)
		if tagged != null and not tagged.is_dead:
			target = tagged
			home = tagged.global_position

	if target == null:
		if mode == GUARD:
			home = guard_pos
			target = _nearest_enemy(guard_pos, MatchConfig.get_value("familiar.aggro_radius_m"))
		else:
			# FOLLOW (default / HUNT-with-expired-tag fallback).
			home = _home_position(caster)
			target = _nearest_enemy(global_position,
				MatchConfig.get_value("familiar.aggro_radius_m"))

	var melee_range := MatchConfig.get_value("familiar.melee_range_m")
	var desired := home
	if target != null:
		var tpos := _node_position(target)
		if global_position.distance_to(tpos) > melee_range:
			desired = tpos

	# Steer in XZ only; keep Y grounded to the home/target plane.
	var next := global_position.move_toward(desired,
		MatchConfig.get_value("familiar.move_speed") * delta)
	next.y = desired.y
	global_position = next

	attack_cooldown_ticks = maxi(0, attack_cooldown_ticks - 1)
	if target != null and global_position.distance_to(_node_position(target)) <= melee_range \
			and attack_cooldown_ticks == 0:
		_attack(target, caster, tick)
		attack_cooldown_ticks = int(roundf(
			MatchConfig.get_value("familiar.attack_interval_s") * NetworkTime.tickrate))


func _attack(target: Node, caster: FPSController, tick: int) -> void:
	var dmg := MatchConfig.get_value("familiar.melee_damage")
	if target is FPSController:
		(target as FPSController).take_damage(dmg, caster, tick)
	elif target is Familiar:
		(target as Familiar).take_familiar_damage(dmg)


func take_familiar_damage(amount: float) -> void:
	hp = maxf(hp - amount, 0.0)
	NetworkRollback.mutate(self)


func destroy() -> void:
	hp = 0.0
	NetworkRollback.mutate(self)


func queue_set_mode(new_mode: int, new_guard: Vector3) -> void:
	_pending_mode = new_mode
	_pending_guard_pos = new_guard


func _is_dead() -> bool:
	return hp <= 0.0 or _caster_gone()


func _caster_gone() -> bool:
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as FPSController
		if player != null and player.input.get_multiplayer_authority() == caster_peer:
			return player.is_dead
	return true


func _home_position(caster: FPSController) -> Vector3:
	# Stand a fixed offset behind the caster's facing (aim yaw).
	var back := Basis(Vector3.UP, caster.input.aim_yaw) * Vector3(0.0, 0.0, 1.0)
	return caster.global_position + back * MatchConfig.get_value("familiar.follow_offset_m")


func _in_null_field() -> bool:
	var radius := MatchConfig.get_value("ability.null_radius_m")
	for node in get_tree().get_nodes_in_group("null_fields"):
		var field := node as PlacedField
		if field != null and not field._is_dead() \
				and global_position.distance_to(field.global_position) <= radius:
			return true
	return false


func _dwarf_in_range() -> bool:
	var radius := MatchConfig.get_value("familiar.dwarf_destroy_radius_m")
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as FPSController
		if player == null or player.is_dead or player.archetype != &"dwarf":
			continue
		if global_position.distance_to(player.global_position) <= radius:
			return true
	return false


func _nearest_enemy(from: Vector3, radius: float) -> Node:
	var my_team := _team_of(caster_peer)
	var best: Node = null
	var best_d := radius
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as FPSController
		if player == null or player.is_dead:
			continue
		var peer := player.input.get_multiplayer_authority()
		if peer == caster_peer:
			continue
		if my_team != -1 and _team_of(peer) == my_team:
			continue
		var d := from.distance_to(player.global_position)
		if d <= best_d:
			best_d = d
			best = player
	for node in get_tree().get_nodes_in_group("familiars"):
		var fam := node as Familiar
		if fam == null or fam == self or fam._is_dead():
			continue
		if fam.caster_peer == caster_peer:
			continue
		if my_team != -1 and _team_of(fam.caster_peer) == my_team:
			continue
		var d := from.distance_to(fam.global_position)
		if d <= best_d:
			best_d = d
			best = fam
	return best


func _team_of(peer: int) -> int:
	var ms := get_tree().get_first_node_in_group("match_state") as MatchState
	return ms.team_of(peer) if ms != null else -1


func _find_player(peer: int) -> FPSController:
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as FPSController
		if p != null and p.input.get_multiplayer_authority() == peer:
			return p
	return null


func _node_position(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).global_position
	return global_position
