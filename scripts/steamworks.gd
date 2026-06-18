# Steamworks autoload (add to Project Settings > Autoload)
# Place this as an autoload named "Steamworks" or similar.
extends Node

var is_steam_initialized: bool = false
var steam_user_id: int = 0
var steam_username: String = ""

func _ready() -> void:
	_initialize_steam()

func _process(_delta: float) -> void:
	# Always run callbacks so Steam events are processed
	if is_steam_initialized:
		Steam.run_callbacks()

func _initialize_steam() -> void:
	# steamInitEx returns a dictionary with "status" and "verbal"
	var init_response: Dictionary = Steam.steamInitEx()
	print("Steam init response: ", init_response)

	if init_response.get("status", -1) == Steam.STEAM_API_INIT_RESULT_OK:
		is_steam_initialized = true
		steam_user_id = Steam.getSteamID()
		steam_username = Steam.getPersonaName()
		print("Steam initialized successfully for user: ", steam_username, " (", steam_user_id, ")")
	else:
		is_steam_initialized = false
		push_warning("Steam initialization failed or Steam client not running: ", init_response)
		# In a real game you might show a warning or disable Steam-only features

func is_steam_ready() -> bool:
	return is_steam_initialized

# Example helpers you will expand
func get_current_username() -> String:
	return steam_username if is_steam_initialized else "Local Player"

func get_steam_id() -> int:
	return steam_user_id
