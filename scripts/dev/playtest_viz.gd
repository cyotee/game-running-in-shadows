# Minimal playtest visualization: translucent spheres/discs/lines scaled from
# MatchConfig radii so effect ranges are readable without real art.
# Autoload singleton name: PlaytestViz (no class_name — avoids cache/LSP races).
# View-only — never touch rollback state. Toggle: MatchConfig debug.playtest_viz.
extends Node


func enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return MatchConfig.get_value("debug.playtest_viz") > 0.5


func unshaded_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m


## Persistent sphere parented under a field/device (radius in meters = sim radius).
func attach_sphere(
		parent: Node3D, radius: float, color: Color, y_offset: float = 0.05
) -> MeshInstance3D:
	if not enabled() or parent == null or radius <= 0.0:
		return null
	var existing := parent.get_node_or_null("PlaytestRange") as MeshInstance3D
	if existing != null:
		existing.queue_free()
	var mi := MeshInstance3D.new()
	mi.name = "PlaytestRange"
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	mi.mesh = mesh
	mi.material_override = unshaded_mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, y_offset, 0.0)
	parent.add_child(mi)
	return mi


## Flat ground disc (readable aura footprint).
func attach_disc(
		parent: Node3D, radius: float, color: Color, y_offset: float = 0.05
) -> MeshInstance3D:
	if not enabled() or parent == null or radius <= 0.0:
		return null
	var existing := parent.get_node_or_null("PlaytestDisc") as MeshInstance3D
	if existing != null:
		existing.queue_free()
	var mi := MeshInstance3D.new()
	mi.name = "PlaytestDisc"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.06
	mesh.radial_segments = 32
	mi.mesh = mesh
	mi.material_override = unshaded_mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, y_offset, 0.0)
	parent.add_child(mi)
	return mi


## Short-lived sphere (grenade blast, repulse pulse). Not rollback state.
func flash_sphere(
		tree: SceneTree, world_pos: Vector3, radius: float, color: Color,
		duration_s: float = 0.35
) -> void:
	if not enabled() or tree == null or radius <= 0.0:
		return
	var host := Node3D.new()
	host.name = "PlaytestFlash"
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(host)
	host.global_position = world_pos
	attach_sphere(host, radius, color, 0.0)
	tree.create_timer(duration_s).timeout.connect(host.queue_free)


## Hitscan tracer (view-only).
func flash_line(
		tree: SceneTree, from: Vector3, to: Vector3, color: Color,
		duration_s: float = 0.08
) -> void:
	if not enabled() or tree == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "PlaytestTracer"
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	im.surface_end()
	mi.mesh = im
	var mat := unshaded_mat(color)
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	parent.add_child(mi)
	tree.create_timer(duration_s).timeout.connect(mi.queue_free)
