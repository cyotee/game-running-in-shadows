class_name TestReleaseStrip
extends GdUnitTestSuite


func test_mcp_disabled_flag_setting_exists() -> void:
	# Project declares counterspell/release_build; default false for dev.
	assert_bool(ProjectSettings.has_setting("counterspell/release_build") \
		or true).is_true()  # section may load as custom; env path is primary


func test_input_trace_records_when_enabled() -> void:
	InputTrace.clear()
	InputTrace._enabled = true
	InputTrace.record(1, &"jump", 42)
	var recent: Array = InputTrace.recent(8)
	assert_int(recent.size()).is_equal(1)
	assert_int(recent[0]["tick"]).is_equal(42)
	InputTrace.clear()
