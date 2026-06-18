# ==============================================================================
# SteamManager (Autoload for Godot 4.6 + GodotSteam GDExtension)
# ==============================================================================
#
# HOW TO ADD IN GODOT 4.6:
#   1. Project > Project Settings
#   2. In the left panel select "Globals"
#   3. Select the "Autoload" section (or search for "autoload" in the top search bar)
#   4. Add this script as "SteamManager" (recommended name) or "Steamworks"
#
# IMPORTANT:
# - The GodotSteam GDExtension automatically registers the global "Steam" class.
#   You do NOT need to autoload the plugin itself.
# - This script is a clean wrapper for initialization + running callbacks every frame.
# - Steam client must be running for full functionality during development.
# - For local testing without Steam: create steam_appid.txt (gitignored) containing "480".
#
# Recommended GodotSteam version: 4.19+ or newer compatible with Godot 4.6.
# ==============================================================================

extends Node

# --- Signals ---
signal steam_initialized(success: bool, response: Dictionary)

# --- State ---
var is_initialized: bool = false
var init_response: Dictionary = {}
var steam_id: int = 0
var persona_name: String = ""

func _ready() -> void:
	_initialize_steam()

func _process(_delta: float) -> void:
	if is_initialized:
		Steam.run_callbacks()

func _exit_tree() -> void:
	# Optional: clean up if needed in the future
	pass

# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _initialize_steam() -> void:
	if not Engine.has_singleton("Steam"):
		push_error("GodotSteam GDExtension not found. Make sure addons/godotsteam/godotsteam.gdextension is present and the editor was restarted after installation.")
		steam_initialized.emit(false, {})
		return

	# steamInitEx() returns a Dictionary with "status" and "verbal"
	# Status 0 = success in most versions.
	# Newer GodotSteam also respects Project Settings → Steam → Initialization
	init_response = Steam.steamInitEx()
	print("GodotSteam initialization response: ", init_response)

	var status: int = init_response.get("status", -1)

	# In GodotSteam, status == 0 means success.
	# We also check the constant when available to be extra safe.
	var success := status == 0
	if not success:
		# This will only succeed if the constant is exposed in this build
		if "STEAM_API_INIT_RESULT_OK" in Steam and status == Steam.STEAM_API_INIT_RESULT_OK:
			success = true

	if success:
		is_initialized = true
		steam_id = Steam.getSteamID()
		persona_name = Steam.getPersonaName()

		print("✅ Steam initialized successfully!")
		print("   User: %s" % persona_name)
		print("   SteamID: %s" % steam_id)

		steam_initialized.emit(true, init_response)
	else:
		is_initialized = false
		push_warning("❌ Steam initialization failed or Steam client not running.")
		push_warning("   Response: ", init_response)
		steam_initialized.emit(false, init_response)

# ==============================================================================
# PUBLIC API
# ==============================================================================

func is_steam_ready() -> bool:
	return is_initialized

func get_init_response() -> Dictionary:
	return init_response

func get_steam_id() -> int:
	return steam_id

func get_persona_name() -> String:
	return persona_name if is_initialized else "Local Player"

# --- Convenience helpers (expand these as you build features) ---

func set_rich_presence(key: String, value: String) -> void:
	if is_initialized:
		Steam.setRichPresence(key, value)

func clear_rich_presence() -> void:
	if is_initialized:
		Steam.clearRichPresence()

# Example: Unlock an achievement (call after Steam is ready)
func unlock_achievement(achievement_api_name: String) -> void:
	if is_initialized:
		Steam.setAchievement(achievement_api_name)
		Steam.storeStats()

# You can add more wrappers here for:
# - Lobbies (Steam.getLobbyData, createLobby, joinLobby, etc.)
# - Leaderboards
# - Stats
# - Inventory
# - etc.

# ==============================================================================
# DEBUG / UTILITY
# ==============================================================================

func print_steam_info() -> void:
	if not is_initialized:
		print("Steam is not initialized.")
		return

	print("--- Steam Info ---")
	print("Persona: ", persona_name)
	print("SteamID: ", steam_id)
	print("Is on Steam Deck: ", Steam.isSteamRunningOnSteamDeck())
	print("Current game language: ", Steam.getCurrentGameLanguage())
	print("-------------------")

