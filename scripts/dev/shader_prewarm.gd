# ShaderPrewarm (autoload) — forces the GL Compatibility renderer to compile the
# PlaytestViz effect shader variants at load, so first-use compile stutter is
# absorbed into the initial load stall instead of freezing mid-play frames.
# No class_name (autoload; avoids cache/LSP races). View-only — never touches
# rollback state. On macOS/AMD OpenGL, shader compiles are slow and synchronous.
#
# Warm geometry must be full-size and in-frustum. Sub-pixel scale (old approach)
# was culled / never submitted, so first real flash_line still compiled mid-play.
extends Node

const WARM_FRAMES: int = 5
const CAMERA_WAIT_FRAMES: int = 180  # ~3s at 60hz before giving up
## Local camera offset: past near plane, fills enough fragments to force compile.
const WARM_LOCAL_POS := Vector3(0.0, 0.0, -1.2)
## Opaque-enough alpha so the blend path still rasterizes (not fully discarded).
const _WARM_ALPHA: float = 0.02

var _done: bool = false


func _ready() -> void:
	# Nothing to draw into headless; the camera/scene also don't exist yet during
	# autoload _ready, so defer the actual pass until a camera is available.
	if DisplayServer.get_name() == "headless":
		return
	_run_warmup()


## Gating predicate: warm only once, only with a display, only when the viz whose
## materials we warm is actually enabled (otherwise they never appear in play).
func should_warm() -> bool:
	if _done:
		return false
	if DisplayServer.get_name() == "headless":
		return false
	return PlaytestViz.enabled()


## Distinct effect shader variants from PlaytestViz's cache so gameplay draws
## the exact same material resources (and feature flags) we warm.
func target_materials() -> Array:
	# Seed the cache with gameplay colors, then return unique *variant* samples
	# (one aura without vertex color, one tracer with vertex color).
	var seeded: Array = PlaytestViz.gameplay_materials()
	var aura: StandardMaterial3D = null
	var tracer: StandardMaterial3D = null
	for m in seeded:
		if m is StandardMaterial3D:
			var sm: StandardMaterial3D = m
			if sm.vertex_color_use_as_albedo:
				if tracer == null:
					tracer = sm
			elif aura == null:
				aura = sm
	if aura == null:
		aura = PlaytestViz.unshaded_mat(Color(1.0, 1.0, 1.0, _WARM_ALPHA))
	if tracer == null:
		tracer = PlaytestViz.tracer_mat(Color(1.0, 1.0, 0.0, 1.0))
	return [aura, tracer]


## Full-size MeshInstance3Ds covering every mesh class PlaytestViz / body uses.
## Parent places this under the active camera; no micro-scale (that skipped draws).
func build_warm_nodes() -> Node3D:
	var container := Node3D.new()
	container.name = "ShaderPrewarm"
	container.scale = Vector3.ONE

	var mats: Array = target_materials()
	var aura: StandardMaterial3D = mats[0]
	var tracer: StandardMaterial3D = mats[1]
	# Near-invisible but non-zero alpha so rasterization still runs.
	var warm_aura: StandardMaterial3D = PlaytestViz.unshaded_mat(
		Color(aura.albedo_color.r, aura.albedo_color.g, aura.albedo_color.b, _WARM_ALPHA)
	)
	var warm_tracer: StandardMaterial3D = PlaytestViz.tracer_mat(
		Color(tracer.albedo_color.r, tracer.albedo_color.g, tracer.albedo_color.b, _WARM_ALPHA)
	)

	# Mesh classes that appear at runtime: sphere (range), cylinder (disc),
	# capsule/box (body/viewmodel), ImmediateMesh lines (hitscan tracer).
	_add_mesh(container, _sphere_mesh(), warm_aura, Vector3(-0.15, 0.05, 0.0))
	_add_mesh(container, _cylinder_mesh(), warm_aura, Vector3(0.15, 0.0, 0.0))
	_add_mesh(container, _capsule_mesh(), warm_aura, Vector3(-0.15, -0.1, 0.0))
	_add_mesh(container, _box_mesh(), warm_aura, Vector3(0.15, -0.1, 0.0))
	_add_mesh(container, _tracer_mesh(warm_tracer.albedo_color), warm_tracer, Vector3.ZERO)
	return container


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, local_pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = local_pos
	parent.add_child(mi)


func _sphere_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 0.35
	m.height = 0.7
	m.radial_segments = 16
	m.rings = 8
	return m


func _cylinder_mesh() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.4
	m.bottom_radius = 0.4
	m.height = 0.08
	m.radial_segments = 16
	return m


func _capsule_mesh() -> Mesh:
	var m := CapsuleMesh.new()
	m.radius = 0.2
	m.height = 0.6
	return m


func _box_mesh() -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3(0.2, 0.2, 0.4)
	return m


func _tracer_mesh(color: Color) -> Mesh:
	# Same path as PlaytestViz.flash_line: ImmediateMesh PRIMITIVE_LINES +
	# vertex colors. Size is large enough in camera-local space to rasterize.
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)
	im.surface_add_vertex(Vector3(-0.4, -0.3, 0.0))
	im.surface_add_vertex(Vector3(0.4, 0.3, 0.0))
	im.surface_add_vertex(Vector3(-0.3, 0.35, 0.0))
	im.surface_add_vertex(Vector3(0.3, -0.35, 0.0))
	im.surface_end()
	return im


func _run_warmup() -> void:
	# The active camera isn't present during autoload _ready; poll a few frames
	# for it, then warm exactly once.
	for _attempt in CAMERA_WAIT_FRAMES:
		await get_tree().process_frame
		if not should_warm():
			return  # viz disabled or already warmed -> nothing to do
		var cam := _active_camera()
		if cam != null:
			await _warm(cam)
			return


func _active_camera() -> Camera3D:
	var vp := get_viewport()
	return vp.get_camera_3d() if vp != null else null


func _warm(cam: Camera3D) -> void:
	_done = true
	var container := build_warm_nodes()
	container.position = WARM_LOCAL_POS
	cam.add_child(container)
	var count := container.get_child_count()
	# frame_post_draw: submit → GPU compile on Compatibility happens here.
	for _i in WARM_FRAMES:
		await RenderingServer.frame_post_draw
	container.queue_free()
	print("ShaderPrewarm: warmed %d effect draw variants at load" % count)
