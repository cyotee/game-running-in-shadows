class_name TestPlayerHudPing
extends GdUnitTestSuite

const HUD_SCENE := "res://scenes/ui/player_hud.tscn"
const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)
	PingService.setup(null)
	PingService.reset()


func after_test() -> void:
	PingService.reset()
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func test_world_ping_projects_to_a_screen_target() -> void:
	var controller: FPSController = auto_free(
		(load(CONTROLLER_SCENE) as PackedScene).instantiate())
	add_child(controller)
	var hud: PlayerHud = auto_free((load(HUD_SCENE) as PackedScene).instantiate())
	add_child(hud)
	await await_millis(50)
	hud.bind(controller)

	# A point 10m straight ahead of the camera should project on-screen.
	var ahead := controller.camera.global_position \
		- controller.camera.global_transform.basis.z * 10.0
	PingService._apply_ping(controller.input.get_multiplayer_authority(),
		PingService.WORLD, ahead, 0)

	var record: Dictionary = PingService.visible_pings(
		controller.input.get_multiplayer_authority())[0]
	var target: Dictionary = hud._ping_screen_target(record)
	assert_bool(target["visible"]).is_true()
	assert_bool(target["behind"]).is_false()
	assert_float(target["distance"]).is_greater(5.0)
