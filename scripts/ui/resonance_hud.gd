# Debug Resonance pip display. Attach to a Label under a CanvasLayer.
# Filled ● / partial ◐ / empty ○ / reserved ▣  — plus health readout.
extends Label

@export var player_path: NodePath = ^"/root/TestArena/FPSController"

var _player: FPSController


func _ready() -> void:
	_player = get_node_or_null(player_path) as FPSController


func _process(_delta: float) -> void:
	if _player == null:
		text = "Resonance: no player"
		return
	var pool := _player.resonance
	var pips := ""
	var whole := int(floorf(pool.current))
	var frac := pool.current - float(whole)
	for i in range(int(roundf(pool.max_resonance))):
		if i < whole:
			pips += "●"
		elif i == whole and frac > 0.05:
			pips += "◐"
		elif i >= int(roundf(pool.cap())):
			pips += "▣"
		else:
			pips += "○"
	text = "Resonance %s  %.1f/%.0f (cap %.0f)\nHealth %.0f" % [
		pips, pool.current, pool.max_resonance, pool.cap(), _player.health]
	var weapon := _player.weapon_rig.active_weapon()
	if weapon != null:
		text += "\n%s  %d / %d%s" % [weapon.weapon_key, int(weapon.mag),
			int(weapon.reserve),
			" (reloading)" if weapon.is_reloading(NetworkTime.tick) else ""]
