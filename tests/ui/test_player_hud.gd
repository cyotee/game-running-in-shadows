class_name TestPlayerHud
extends NetSuite
# (cast_denied test drives the controller through the pending-latch inject.)


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
	controller.resonance.current = 1.0  # below Repulse cost (2)
	var denials: Array = []
	controller.cast_denied.connect(func() -> void: denials.append(true))

	press(controller.input, &"repulse")
	await await_ticks(6)

	assert_array(denials).has_size(1)
	NetworkTime.stop()
