class_name TestControlsMenu
extends GdUnitTestSuite

const CONTROLS_SCENE := preload("res://scenes/ui/controls_menu.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MAIN_MENU_SCRIPT := preload("res://scripts/ui/main_menu.gd")


func test_controls_scene_instantiates_and_lists_catalog() -> void:
	var menu: Control = auto_free(CONTROLS_SCENE.instantiate())
	add_child(menu)
	assert_that(menu).is_not_null()
	assert_that(menu.has_method("open_panel")).is_true()
	menu.open_panel()
	var list: VBoxContainer = menu.get_node("%ActionList") as VBoxContainer
	assert_that(list).is_not_null()
	# Movement category default — should have rows for catalog actions.
	assert_int(list.get_child_count()).is_greater_equal(1)


func test_settings_opens_controls() -> void:
	var settings: Control = auto_free(SETTINGS_SCENE.instantiate())
	add_child(settings)
	assert_that(settings.has_method("open_settings")).is_true()
	settings.open_settings("controls")
	assert_bool(settings.visible).is_true()
	var host: Control = settings.get_node("%ContentHost") as Control
	assert_that(host).is_not_null()
	assert_int(host.get_child_count()).is_greater_equal(1)


func test_settings_opens_display_tab() -> void:
	var settings: Control = auto_free(SETTINGS_SCENE.instantiate())
	add_child(settings)
	settings.open_settings("display")
	assert_bool(settings.visible).is_true()
	assert_that(settings.get_node("%DisplayTab")).is_not_null()
	var host: Control = settings.get_node("%ContentHost") as Control
	assert_int(host.get_child_count()).is_greater_equal(1)
	# Display panel should expose resolution / scale controls.
	var disp: Node = host.get_child(0)
	assert_that(disp.get_node("%ResOption")).is_not_null()
	assert_that(disp.get_node("%ScaleOption")).is_not_null()


func test_main_menu_script_opens_settings_scene() -> void:
	# Structural: main menu preloads settings and has open path.
	var src := FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	assert_str(src).contains("settings_menu.tscn")
	assert_str(src).contains("_open_settings")
	assert_str(src).contains("SettingsButton")


func test_pause_menu_wires_settings_and_menu_action() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/pause_menu.gd")
	assert_str(src).contains("settings_menu.tscn")
	assert_str(src).contains("menu")
	assert_str(src).contains("open_settings")
	var pause: CanvasLayer = auto_free(PAUSE_SCENE.instantiate())
	add_child(pause)
	assert_that(pause.get_node("%ResumeButton")).is_not_null()
	assert_that(pause.get_node("%SettingsButton")).is_not_null()


func test_player_input_reads_input_bindings_feel() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player/player_input.gd")
	assert_str(src).contains("InputBindings")
	assert_str(src).contains("_mouse_sens")
	assert_str(src).contains("_invert_y")
	var fps := FileAccess.get_file_as_string("res://scripts/player/fps_controller.gd")
	assert_str(fps).contains("stick_slowdown_mult")
	assert_str(fps).contains("InputBindings")


func test_catalog_excludes_dev_and_includes_core() -> void:
	assert_bool(InputBindings.is_catalog_action("fire_primary")).is_true()
	assert_bool(InputBindings.is_catalog_action("repulse")).is_true()
	assert_bool(InputBindings.is_catalog_action("dev_promote")).is_false()
