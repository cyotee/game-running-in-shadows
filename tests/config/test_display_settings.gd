class_name TestDisplayConfig
extends GdUnitTestSuite

const SAVE_PATH := "user://display_settings.json"
const BACKUP_PATH := "user://display_settings.backup_test.json"


func before_test() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var src := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var dst := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		DirAccess.remove_absolute(SAVE_PATH)
	DisplayConfig.width = DisplayConfig.DEFAULT_WIDTH
	DisplayConfig.height = DisplayConfig.DEFAULT_HEIGHT
	DisplayConfig.ui_scale = DisplayConfig.DEFAULT_UI_SCALE
	DisplayConfig.fullscreen = false


func after_test() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		var src := FileAccess.open(BACKUP_PATH, FileAccess.READ)
		var dst := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		DirAccess.remove_absolute(BACKUP_PATH)
	DisplayConfig.width = DisplayConfig.DEFAULT_WIDTH
	DisplayConfig.height = DisplayConfig.DEFAULT_HEIGHT
	DisplayConfig.ui_scale = DisplayConfig.DEFAULT_UI_SCALE
	DisplayConfig.fullscreen = false


func test_resolve_size_uses_explicit_dimensions() -> void:
	DisplayConfig.width = 1600
	DisplayConfig.height = 900
	assert_vector(DisplayConfig.resolve_size()).is_equal(Vector2i(1600, 900))


func test_resolve_size_clamps_minimum() -> void:
	DisplayConfig.width = 100
	DisplayConfig.height = 50
	assert_vector(DisplayConfig.resolve_size()).is_equal(Vector2i(640, 360))


func test_ui_scale_clamp() -> void:
	DisplayConfig.set_ui_scale(99.0, false)
	assert_float(DisplayConfig.ui_scale).is_equal(4.0)
	DisplayConfig.set_ui_scale(0.1, false)
	assert_float(DisplayConfig.ui_scale).is_equal(0.5)


func test_cycle_ui_scale_steps() -> void:
	DisplayConfig.ui_scale = 1.0
	DisplayConfig.cycle_ui_scale(1)
	assert_float(DisplayConfig.ui_scale).is_equal(1.25)
	DisplayConfig.cycle_ui_scale(20)
	assert_float(DisplayConfig.ui_scale).is_equal(3.0)


func test_defaults_are_sane() -> void:
	assert_int(DisplayConfig.DEFAULT_WIDTH).is_greater_equal(1280)
	assert_int(DisplayConfig.DEFAULT_HEIGHT).is_greater_equal(720)
	assert_float(DisplayConfig.DEFAULT_UI_SCALE).is_greater_equal(1.0)
	assert_vector(DisplayConfig.BASE_SIZE).is_equal(Vector2i(1920, 1080))


func test_save_and_reload_roundtrip() -> void:
	DisplayConfig.width = 2560
	DisplayConfig.height = 1440
	DisplayConfig.ui_scale = 1.75
	DisplayConfig.fullscreen = true
	DisplayConfig.save()
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_true()

	DisplayConfig.width = 1280
	DisplayConfig.height = 720
	DisplayConfig.ui_scale = 1.0
	DisplayConfig.fullscreen = false
	DisplayConfig._load()
	assert_int(DisplayConfig.width).is_equal(2560)
	assert_int(DisplayConfig.height).is_equal(1440)
	assert_float(DisplayConfig.ui_scale).is_equal(1.75)
	assert_bool(DisplayConfig.fullscreen).is_true()


func test_preset_index_for_current() -> void:
	DisplayConfig.width = 1920
	DisplayConfig.height = 1080
	assert_int(DisplayConfig.preset_index_for_current()).is_equal(2)
	DisplayConfig.width = 2880
	DisplayConfig.height = 1620
	assert_int(DisplayConfig.preset_index_for_current()).is_equal(4)
	DisplayConfig.width = 3840
	DisplayConfig.height = 2160
	assert_int(DisplayConfig.preset_index_for_current()).is_equal(6)
	DisplayConfig.width = 1234
	DisplayConfig.height = 567
	assert_int(DisplayConfig.preset_index_for_current()).is_equal(-1)


func test_presets_include_4k_and_mid_16x9() -> void:
	var max_w := 0
	var has_3200 := false
	var has_4k := false
	for p in DisplayConfig.PRESETS:
		var w: int = int(p["w"])
		var h: int = int(p["h"])
		if w > 0 and h > 0:
			assert_int(w * 9).is_equal(h * 16)
			max_w = maxi(max_w, w)
		if w == 3200 and h == 1800:
			has_3200 = true
		if w == 3840 and h == 2160:
			has_4k = true
	assert_bool(has_3200).is_true()
	assert_bool(has_4k).is_true()
	assert_int(max_w).is_greater_equal(3840)


func test_apply_dict_for_test() -> void:
	DisplayConfig.apply_dict_for_test({
		"width": 1280,
		"height": 720,
		"ui_scale": 2.0,
		"fullscreen": false,
	})
	assert_int(DisplayConfig.width).is_equal(1280)
	assert_float(DisplayConfig.ui_scale).is_equal(2.0)


func test_set_resolution_persists_to_user_file() -> void:
	DisplayConfig.set_resolution(3200, 1800, true)
	assert_int(DisplayConfig.width).is_equal(3200)
	assert_int(DisplayConfig.height).is_equal(1800)
	assert_bool(FileAccess.file_exists(SAVE_PATH)).is_true()
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	assert_that(parsed).is_not_null()
	assert_int(int(parsed["width"])).is_equal(3200)
	assert_int(int(parsed["height"])).is_equal(1800)


func test_stretch_uses_fixed_base_not_window_size() -> void:
	# Official pattern: content_scale_size is design base (1920x1080), NOT the
	# user resolution. User resolution is window.size only.
	var win := get_tree().root as Window
	assert_that(win).is_not_null()
	DisplayConfig.ui_scale = 1.25
	DisplayConfig._apply_stretch(win)
	assert_vector(win.content_scale_size).is_equal(DisplayConfig.BASE_SIZE)
	assert_float(win.content_scale_factor).is_equal_approx(1.25, 0.001)
	assert_int(win.content_scale_mode).is_equal(Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	assert_int(win.content_scale_aspect).is_equal(Window.CONTENT_SCALE_ASPECT_EXPAND)
