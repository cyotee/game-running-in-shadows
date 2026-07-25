class_name TestReleaseStrip
extends GdUnitTestSuite


func after_test() -> void:
	# Restore dev defaults so other suites keep tracing.
	ProjectSettings.set_setting("counterspell/release_build", false)
	InputTrace.reconfigure_from_env()
	InputTrace.clear()


func test_input_trace_disabled_when_release_project_setting() -> void:
	ProjectSettings.set_setting("counterspell/release_build", false)
	assert_bool(InputTrace.reconfigure_from_env()).is_true()
	InputTrace.clear()
	InputTrace.record(1, &"jump", 10)
	assert_int(InputTrace.recent(8).size()).is_equal(1)

	ProjectSettings.set_setting("counterspell/release_build", true)
	assert_bool(InputTrace.reconfigure_from_env()).is_false()
	assert_bool(InputTrace.is_enabled()).is_false()
	InputTrace.record(1, &"repulse", 11)
	assert_int(InputTrace.recent(8).size()).is_equal(0)


func test_input_trace_records_when_enabled() -> void:
	ProjectSettings.set_setting("counterspell/release_build", false)
	assert_bool(InputTrace.reconfigure_from_env()).is_true()
	InputTrace.clear()
	InputTrace.record(1, &"jump", 42)
	var recent: Array = InputTrace.recent(8)
	assert_int(recent.size()).is_equal(1)
	assert_int(recent[0]["tick"]).is_equal(42)


func test_playtest_viz_disabled_in_release() -> void:
	OS.set_environment("COUNTERSPELL_RELEASE", "1")
	assert_bool(PlaytestViz.enabled()).is_false()
	OS.set_environment("COUNTERSPELL_RELEASE", "")


func test_mcp_release_mode_helper_reads_project_setting() -> void:
	# Autoload already constructed; exercise the same release predicate the
	# server uses so strip policy is not vaporware.
	var mcp: Node = get_tree().root.get_node_or_null("McpInteractionServer")
	assert_object(mcp).is_not_null()
	ProjectSettings.set_setting("counterspell/release_build", true)
	assert_bool(mcp.call("_release_mode")).is_true()
	ProjectSettings.set_setting("counterspell/release_build", false)
	assert_bool(mcp.call("_release_mode")).is_false()
	# Dev suite expects interaction enabled (not a release process).
	assert_bool(mcp.call("is_interaction_enabled")).is_true()
