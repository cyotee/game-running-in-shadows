# Simple Steam status display for testing.
# Attach directly to a Label node.
extends Label

func _ready() -> void:
	var sm = get_node_or_null("/root/SteamManager")
	if sm == null:
		text = "SteamManager autoload not found"
		return

	sm.steam_initialized.connect(_on_steam_initialized)

	if sm.is_initialized:
		_update_text(true, {})
	else:
		text = "Steam: Initializing..."

func _on_steam_initialized(success: bool, _response: Dictionary) -> void:
	_update_text(success, _response)

func _update_text(success: bool, _response: Dictionary) -> void:
	var sm = get_node_or_null("/root/SteamManager")
	if sm == null:
		text = "SteamManager missing"
		return

	if success:
		text = "Steam: ✅ %s" % sm.get_persona_name()
	else:
		text = "Steam: ❌ Init failed (check Output)"
