# Main menu: session entry points. Functional/debug-grade UI — visual design
# is a later pass. Steam-dependent buttons disable gracefully so offline dev
# still reaches the arena.
extends Control

const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")

@onready var host_friends_button: Button = %HostFriendsButton
@onready var host_public_button: Button = %HostPublicButton
@onready var browse_button: Button = %BrowseButton
@onready var invite_button: Button = %InviteButton
@onready var status_label: Label = %StatusLabel
@onready var browser: Control = %LobbyBrowser

var _settings: Control = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%HostFriendsButton.pressed.connect(func() -> void:
		SessionManager.host(SteamLobbyService.VIS_FRIENDS))
	%HostPublicButton.pressed.connect(func() -> void:
		SessionManager.host(SteamLobbyService.VIS_PUBLIC))
	%BrowseButton.pressed.connect(func() -> void:
		browser.visible = true
		browser.refresh())
	%InviteButton.pressed.connect(func() -> void:
		SessionManager.lobby_service.open_invite_overlay(SessionManager.current_lobby_id))
	%ArenaButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/levels/test_arena.tscn"))
	if has_node("%SettingsButton"):
		%SettingsButton.pressed.connect(_open_settings)
	%QuitButton.pressed.connect(func() -> void: get_tree().quit())
	SessionManager.state_changed.connect(_on_state_changed)
	SessionManager.session_error.connect(func(message: String) -> void:
		status_label.text = "Error: %s" % message)
	_refresh_availability()


func _open_settings() -> void:
	if _settings == null:
		_settings = SETTINGS_SCENE.instantiate()
		add_child(_settings)
	if _settings.has_method("open_settings"):
		_settings.open_settings("display")
	else:
		_settings.visible = true


func _refresh_availability() -> void:
	var available := SessionManager.steam_available()
	host_friends_button.disabled = not available
	host_public_button.disabled = not available
	browse_button.disabled = not available
	invite_button.disabled = true
	status_label.text = "Steam: %s" % ("connected" if available else "unavailable (offline dev mode)")


func _on_state_changed(state: int) -> void:
	invite_button.disabled = state < SessionManager.IN_LOBBY
	status_label.text = "Session state: %d" % state
