# ShaderPrewarm (autoload) — forces the GL Compatibility renderer to compile the
# PlaytestViz effect shader variants at load, so first-use compile stutter is
# absorbed into the initial load stall instead of freezing mid-play frames.
# No class_name (autoload; avoids cache/LSP races). View-only — never touches
# rollback state. On macOS/AMD OpenGL, shader compiles are slow and synchronous.
extends Node

const WARM_FRAMES: int = 3
const CAMERA_WAIT_FRAMES: int = 180  # ~3s at 60hz before giving up
const _AURA_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const _TRACER_COLOR: Color = Color(1.0, 1.0, 0.0, 1.0)

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


## Distinct effect shader variants, sourced from PlaytestViz's own factory so the
## compiled variant matches gameplay exactly: the unshaded/alpha aura (sphere and
## disc share it) and the vertex-color tracer.
func target_materials() -> Array:
	var aura: StandardMaterial3D = PlaytestViz.unshaded_mat(_AURA_COLOR)
	var tracer: StandardMaterial3D = PlaytestViz.unshaded_mat(_TRACER_COLOR)
	tracer.vertex_color_use_as_albedo = true
	return [aura, tracer]


## A container of tiny MeshInstance3Ds, one per target variant. Rendering these
## for a few frames issues the draw calls that trigger compilation.
func build_warm_nodes() -> Node3D:
	var container := Node3D.new()
	container.name = "ShaderPrewarm"
	var mats: Array = target_materials()
	for i in mats.size():
		var mat: StandardMaterial3D = mats[i]
		var mi := MeshInstance3D.new()
		mi.mesh = _tracer_mesh() if mat.vertex_color_use_as_albedo else _aura_mesh()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0.0, 0.0, -0.001 * float(i))
		container.add_child(mi)
	# Sub-pixel: renders (compiles) but is imperceptible for the few warm frames.
	container.scale = Vector3.ONE * 0.0005
	return container


func _aura_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 8
	m.rings = 4
	return m


func _tracer_mesh() -> Mesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(_TRACER_COLOR)
	im.surface_add_vertex(Vector3(0.0, 0.0, 0.0))
	im.surface_add_vertex(Vector3(0.0, 1.0, 0.0))
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
	container.position = Vector3(0.0, 0.0, -0.3)  # just past the near plane
	cam.add_child(container)
	var count := container.get_child_count()
	for _i in WARM_FRAMES:
		await RenderingServer.frame_post_draw
	container.queue_free()
	print("ShaderPrewarm: warmed %d effect shader variants at load" % count)
