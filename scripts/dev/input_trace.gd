# Layer-1 anti-cheat input trace (G11). Records edge press-ticks for the
# local authority player into a ring buffer for host-side audits. Not
# rollback state — diagnostics only. Disabled in release when
# COUNTERSPELL_RELEASE=1.
extends Node

const MAX_ENTRIES := 256

var _entries: Array[Dictionary] = []
var _enabled: bool = true


func _ready() -> void:
	if OS.get_environment("COUNTERSPELL_RELEASE") == "1" \
			or ProjectSettings.get_setting("counterspell/release_build", false):
		_enabled = false


func record(peer: int, action: StringName, tick: int) -> void:
	if not _enabled:
		return
	_entries.append({"peer": peer, "action": String(action), "tick": tick})
	while _entries.size() > MAX_ENTRIES:
		_entries.pop_front()


func recent(limit: int = 32) -> Array:
	if limit >= _entries.size():
		return _entries.duplicate()
	return _entries.slice(_entries.size() - limit)


func clear() -> void:
	_entries.clear()
