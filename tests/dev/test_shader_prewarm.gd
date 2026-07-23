class_name TestShaderPrewarm
extends GdUnitTestSuite

# ShaderPrewarm forces the GL Compatibility renderer to compile the PlaytestViz
# effect shader variants at load, so the compile stutter is absorbed into the
# initial load instead of hitting mid-play. GPU compilation itself cannot be
# asserted headlessly; these cover the display-independent contract.

const PrewarmScript := preload("res://scripts/dev/shader_prewarm.gd")


func _make() -> Node:
	return auto_free(PrewarmScript.new())


func test_should_not_warm_under_headless() -> void:
	# Test env is headless: no viewport to draw into, so warming is a no-op.
	var prewarm := _make()
	assert_bool(prewarm.should_warm()).is_false()


func test_target_materials_include_aura_variant() -> void:
	# The aura material must match PlaytestViz.unshaded_mat's variant exactly
	# (unshaded / alpha / cull-disabled) so the warmed shader matches gameplay.
	var prewarm := _make()
	var mats: Array = prewarm.target_materials()
	assert_int(mats.size()).is_greater_equal(2)
	var aura: StandardMaterial3D = null
	for m in mats:
		if m is StandardMaterial3D and not m.vertex_color_use_as_albedo:
			aura = m
			break
	assert_that(aura).is_not_null()
	assert_int(aura.shading_mode).is_equal(BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert_int(aura.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_int(aura.cull_mode).is_equal(BaseMaterial3D.CULL_DISABLED)


func test_target_materials_include_tracer_variant() -> void:
	# The tracer is a distinct variant: vertex color used as albedo.
	var prewarm := _make()
	var mats: Array = prewarm.target_materials()
	var has_tracer := false
	for m in mats:
		if m is StandardMaterial3D and m.vertex_color_use_as_albedo:
			has_tracer = true
			break
	assert_bool(has_tracer).is_true()


func test_build_warm_nodes_carry_materials() -> void:
	var prewarm := _make()
	var container: Node3D = auto_free(prewarm.build_warm_nodes())
	assert_that(container).is_not_null()
	var meshes: Array = []
	for c in container.get_children():
		if c is MeshInstance3D:
			meshes.append(c)
	assert_int(meshes.size()).is_greater_equal(2)
	for mi in meshes:
		assert_that(mi.material_override).is_not_null()


func test_build_warm_nodes_free_leaves_no_orphans() -> void:
	var prewarm := _make()
	var container: Node3D = prewarm.build_warm_nodes()
	add_child(container)
	assert_int(container.get_child_count()).is_greater_equal(2)
	var child: Node = container.get_child(0)
	container.free()
	assert_bool(is_instance_valid(child)).is_false()
