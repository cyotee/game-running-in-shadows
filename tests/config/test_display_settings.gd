class_name TestDisplayConfig
extends GdUnitTestSuite

const SAVE_PATH := "user://display_settings.json"
const BACKUP_PATH := "user://display_settings.backup_test.json"


func before_test() -> void:
	# Preserve any real user settings around tests.
	if FileAccess.file_exists(SAVE_PATH):
		var src := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var dst := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		dst.store_string(src.get_as_text())
		src.close()
		dst.close()
		DirAccess.remove_absolute(SAVE_PATH)
	DisplayConfig.width = 2880
	DisplayConfig.height = 1620
	DisplayConfig.ui_scale = 1.25
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
	DisplayConfig.width = 2880
	DisplayConfig.height = 1620
	DisplayConfig.ui_scale = 1.25
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
	DisplayConfig.cycle_ui_scale(10)
	assert_float(DisplayConfig.ui_scale).is_equal(2.5)


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
	DisplayConfig.width = 1234
	DisplayConfig.height = 567
	assert_int(DisplayConfig.preset_index_for_current()).is_equal(-1)


func test_apply_dict_for_test() -> void:
	DisplayConfig.apply_dict_for_test({
		"width": 1280,
		"height": 720,
		"ui_scale": 2.0,
		"fullscreen": false,
	})
	assert_int(DisplayConfig.width).is_equal(1280)
	assert_float(DisplayConfig.ui_scale).is_equal(2.0)
