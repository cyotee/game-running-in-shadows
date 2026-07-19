# Owns the two weapon slots, switching, and carry weight.
# All children are WeaponBase nodes, present statically in the scene;
# "ownership" = a slot referencing their weapon_key.
class_name WeaponRig
extends Node3D

# --- Rollback state ---
var slot1: String = ""
var slot2: String = ""
var active_slot: int = 1

var _controller: FPSController


func setup(controller: FPSController) -> void:
	_controller = controller
	# Weapons register the controller for action mutation here — the
	# controller does not exist yet when their own _ready runs.
	for child in get_children():
		if child is WeaponBase:
			child.fire_action.mutate(controller)


func grant(key: String, slot: int) -> void:
	var weapon := weapon_by_key(key)
	assert(weapon != null, "unknown weapon key %s" % key)
	weapon.initialize_ammo()
	if slot == 1:
		slot1 = key
	else:
		slot2 = key


func weapon_by_key(key: String) -> WeaponBase:
	for child in get_children():
		if child is WeaponBase and child.weapon_key == key:
			return child
	return null


func active_weapon() -> WeaponBase:
	return weapon_by_key(slot1 if active_slot == 1 else slot2)


func carry_weight_mult() -> float:
	var mult := 1.0
	for key in [slot1, slot2]:
		if key == "":
			continue
		var weapon := weapon_by_key(key)
		match weapon.weight_class:
			1:
				mult = minf(mult, MatchConfig.get_value("weight.medium.%s" % _controller.archetype))
			2:
				mult = minf(mult, MatchConfig.get_value("weight.heavy.%s" % _controller.archetype))
	return mult


func process_tick(_delta: float, tick: int, _is_fresh: bool) -> void:
	var sel: int = _controller.input.slot_select
	if sel in [1, 2] and sel != active_slot:
		var target := slot1 if sel == 1 else slot2
		if target != "":
			active_slot = sel
	# weapon_swap (controller Y / keyboard Q): toggle to the other slot.
	if _controller.input.swap_press_tick == tick:
		var other := 2 if active_slot == 1 else 1
		if (slot1 if other == 1 else slot2) != "":
			active_slot = other
	var weapon := active_weapon()
	if weapon != null:
		weapon.finish_reload_if_due(tick)
		if _controller.input.reload_press_tick == tick:
			weapon.start_reload(tick)
