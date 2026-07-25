class_name TestPlayerHud
extends NetSuite
# (cast_denied test drives the controller through the pending-latch inject.)


func test_combat_log_format_helper() -> void:
	assert_str(PlayerHud.format_combat_log_line("pistol", "body", 12.0)).contains("12")
	assert_str(PlayerHud.format_combat_log_line("pistol", "body", 12.0)).contains("pistol")


func test_pip_formatting_semantics() -> void:
	# 4 filled, partial, empties, then 2 reserved-locked (max 10, cap 8).
	assert_str(PlayerHud.format_pips(4.4, 10.0, 8.0)).is_equal("●●●●◐○○○▣▣")
	# Full pool, nothing reserved.
	assert_str(PlayerHud.format_pips(3.0, 3.0, 3.0)).is_equal("●●●")
	# Everything reserved and empty.
	assert_str(PlayerHud.format_pips(0.0, 2.0, 0.0)).is_equal("▣▣")


func test_kill_feed_keeps_last_four() -> void:
	var hud: PlayerHud = (load("res://scenes/ui/player_hud.tscn") as PackedScene).instantiate()
	auto_free(hud)
	add_child(hud)

	for i in range(6):
		hud.note_kill(i, 100 + i)

	assert_int(hud._feed.size()).is_equal(4)
	assert_str(hud._feed[0]).is_equal("102 ✖ 2")
	assert_str(hud._feed[3]).is_equal("105 ✖ 5")


func test_cast_denied_fires_on_insufficient_resonance() -> void:
	NetworkTime.start()
	await await_millis(100)
	var runner := scene_runner("res://scenes/player/fps_controller.tscn")
	var controller: FPSController = runner.scene()
	await equip_kit(controller, ["repulse"])
	# Out-of-band writes to Resonance rollback state are restored — raise cost
	# via MatchConfig so the cast path hard-blocks for real (same pattern as
	# test_repulse_hard_blocked_when_insufficient).
	MatchConfig.set_value("resonance.repulse_cost", 999.0)
	var denials: Array = []
	controller.cast_denied.connect(func() -> void: denials.append(true))

	press(controller.input, &"repulse")
	await await_ticks(6)

	assert_array(denials).has_size(1)
	MatchConfig.reset_to_defaults()
	NetworkTime.stop()


func test_crosshair_tracks_aim_when_bound() -> void:
	NetworkTime.start()
	await await_millis(100)
	var runner := scene_runner("res://scenes/player/fps_controller.tscn")
	var controller: FPSController = runner.scene()
	var hud: PlayerHud = (load("res://scenes/ui/player_hud.tscn") as PackedScene).instantiate()
	auto_free(hud)
	# Parent under the runner scene so we share the same World3D / viewport.
	runner.scene().get_parent().add_child(hud)
	hud.bind(controller)
	await runner.simulate_frames(5)

	assert_that(hud.crosshair).is_not_null()
	var target: Dictionary = hud._aim_screen_point()
	assert_bool(target["ok"]).is_true()
	assert_bool(hud.crosshair.visible).is_true()
	# Crosshair center should sit on the projected aim point.
	var center: Vector2 = hud.crosshair.position + hud.crosshair.size * 0.5
	var aim_pos: Vector2 = target["pos"]
	assert_float(center.distance_to(aim_pos)).is_less(1.0)

	NetworkTime.stop()


func test_crosshair_stays_visible_in_third_person() -> void:
	# Blade (and any future TP view) must still show cast aim under the
	# over-the-shoulder camera — not only first-person screen center.
	NetworkTime.start()
	await await_millis(100)
	var runner := scene_runner("res://scenes/player/fps_controller.tscn")
	var controller: FPSController = runner.scene()
	controller.weapon_rig.grant("blade", 1)
	controller.weapon_rig.active_slot = 1
	var hud: PlayerHud = (load("res://scenes/ui/player_hud.tscn") as PackedScene).instantiate()
	auto_free(hud)
	runner.scene().get_parent().add_child(hud)
	hud.bind(controller)
	await runner.simulate_frames(10)

	assert_bool(controller.third_person_camera.current).is_true()
	assert_bool(controller.camera.current).is_false()
	hud._update_crosshair()
	var target: Dictionary = hud._aim_screen_point()
	assert_bool(target["ok"]).is_true()
	assert_bool(hud.crosshair.visible).is_true()
	# Projected mark is a finite on-screen point (not dropped as "behind").
	var pos: Vector2 = target["pos"]
	assert_float(pos.x).is_greater(-50.0)
	assert_float(pos.y).is_greater(-50.0)

	NetworkTime.stop()
