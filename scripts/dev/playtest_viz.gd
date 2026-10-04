# Minimal playtest visualization: translucent spheres/discs/lines scaled from
# MatchConfig radii so effect ranges are readable without real art.
# Autoload singleton name: PlaytestViz (no class_name — avoids cache/LSP races).
# View-only — never touch rollback state. Toggle: MatchConfig debug.playtest_viz.
#
# Materials are cached by (variant, color). Reusing instances avoids per-shot
# allocation churn and keeps ShaderPrewarm on the exact same resources gameplay
# draws (GL Compatibility compiles on first real draw of a variant).
extends Node

# "a:<rgba>" = unshaded alpha aura; "t:<rgba>" = same + vertex color (tracers).
var _mat_cache: Dictionary = {}
## Ephemeral FX nodes (tracers, muzzle, hit markers, etc.) — oldest-first eviction.
var _active_fx: Array[Node] = []


func enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if _release_mode():
		return false
	# Host-forced session policy (PlaytestFxBus) overrides local MatchConfig.
	var bus := get_node_or_null("/root/PlaytestFxBus")
	if bus != null and bus.has_method("session_active") and bus.session_active():
		return bus.session_viz_on()
	return MatchConfig.get_value("debug.playtest_viz") > 0.5


func _release_mode() -> bool:
	return OS.get_environment("COUNTERSPELL_RELEASE") == "1" \
		or bool(ProjectSettings.get_setting("counterspell/release_build", false))


## Unshaded alpha material (spheres, discs, body mesh, flash spheres).
func unshaded_mat(color: Color) -> StandardMaterial3D:
	var key := _mat_key("a", color)
	if _mat_cache.has(key):
		return _mat_cache[key] as StandardMaterial3D
	var m := _make_unshaded(color)
	_mat_cache[key] = m
	return m


## Tracer material: unshaded alpha + vertex color as albedo (ImmediateMesh lines).
## Never mutate unshaded_mat() results — that would poison the aura cache.
func tracer_mat(color: Color) -> StandardMaterial3D:
	var key := _mat_key("t", color)
	if _mat_cache.has(key):
		return _mat_cache[key] as StandardMaterial3D
	var m := _make_unshaded(color)
	m.vertex_color_use_as_albedo = true
	_mat_cache[key] = m
	return m


## Materials used by common fire/ability paths — prewarm should draw these.
func gameplay_materials() -> Array:
	return [
		unshaded_mat(Color(1.0, 1.0, 1.0, 0.25)),
		unshaded_mat(Color(0.35, 0.55, 0.85, 0.85)),  # body
		unshaded_mat(Color(0.2, 0.2, 0.22, 1.0)),  # viewmodel
		unshaded_mat(Color(0.35, 0.75, 1.0, 0.28)),  # repulse flash
		unshaded_mat(Color(0.55, 0.9, 1.0, 0.4)),  # slip ghost
		tracer_mat(zone_tracer_color("body", true)),  # hitscan body
		tracer_mat(zone_tracer_color("head", true)),  # hitscan head
		tracer_mat(zone_tracer_color("limbs", true)),  # hitscan limbs
		tracer_mat(zone_tracer_color("", false)),  # hitscan miss
	]


func cache_size() -> int:
	return _mat_cache.size()


func _mat_key(prefix: String, color: Color) -> String:
	return "%s:%.3f,%.3f,%.3f,%.3f" % [prefix, color.r, color.g, color.b, color.a]


func _make_unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m


## Hitscan tracer palette: miss / limb / body / head (four distinct hues).
func zone_tracer_color(zone: String, hit_player: bool) -> Color:
	if not hit_player:
		return Color(0.7, 0.75, 0.85, 0.55)
	match zone:
		"head":
			return Color(1.0, 0.2, 0.85, 0.95)
		"limbs":
			return Color(0.35, 0.55, 1.0, 0.9)
		_:
			return Color(1.0, 0.9, 0.2, 0.9)


## Default tracer lifetime from MatchConfig (flash_line default uses this).
func tracer_duration() -> float:
	return MatchConfig.get_value("debug.viz.tracer_duration_s")


## Stable peer→color mapping for multi-caster field attribution.
func owner_color(peer_id: int) -> Color:
	var h := fmod(float(absi(peer_id)) * 0.6180339887, 1.0)
	return Color.from_hsv(h, 0.55, 0.95, 0.35)


func active_fx_count() -> int:
	_prune_invalid_fx()
	return _active_fx.size()


## Track an ephemeral FX node; oldest-first eviction at max_active_fx.
func register_fx_node(node: Node) -> void:
	if node == null:
		return
	_prune_invalid_fx()
	_active_fx.append(node)
	var cap := int(MatchConfig.get_value("debug.viz.max_active_fx"))
	if cap < 1:
		cap = 1
	while _active_fx.size() > cap:
		var old: Node = _active_fx.pop_front()
		_free_fx(old)


## Free all tracked FX and clear the pool (tests / scene change).
func clear_fx_pool() -> void:
	var snapshot: Array = _active_fx.duplicate()
	_active_fx.clear()
	for n in snapshot:
		_free_fx(n)


func _prune_invalid_fx() -> void:
	var i := 0
	while i < _active_fx.size():
		if not is_instance_valid(_active_fx[i]):
			_active_fx.remove_at(i)
		else:
			i += 1


## Accepts Variant so previously-freed refs do not trip typed param checks.
func _free_fx(node: Variant) -> void:
	if node == null or not is_instance_valid(node):
		return
	var n := node as Node
	if n == null:
		return
	# Immediate free when not in tree (tests / pre-add); queue otherwise.
	if n.is_inside_tree():
		n.queue_free()
	else:
		n.free()


func _track_fx(node: Node, tree: SceneTree, duration_s: float) -> void:
	register_fx_node(node)
	if tree == null or duration_s <= 0.0:
		return
	tree.create_timer(duration_s).timeout.connect(func() -> void:
		_active_fx.erase(node)
		_free_fx(node)
	)


func _fx_parent(tree: SceneTree) -> Node:
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root


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
	_fx_parent(tree).add_child(host)
	host.global_position = world_pos
	attach_sphere(host, radius, color, 0.0)
	_track_fx(host, tree, duration_s)


## Hitscan tracer (view-only). duration_s < 0 → MatchConfig tracer_duration.
func flash_line(
		tree: SceneTree, from: Vector3, to: Vector3, color: Color,
		duration_s: float = -1.0
) -> void:
	if not enabled() or tree == null:
		return
	if duration_s < 0.0:
		duration_s = tracer_duration()
	var mi := MeshInstance3D.new()
	mi.name = "PlaytestTracer"
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	im.surface_end()
	mi.mesh = im
	mi.material_override = tracer_mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx_parent(tree).add_child(mi)
	_track_fx(mi, tree, duration_s)


## Muzzle flash stub at fire origin.
func flash_muzzle(
		tree: SceneTree, origin: Vector3, color: Color = Color(1.0, 1.0, 1.0, 0.9)
) -> void:
	if not enabled() or tree == null:
		return
	var r := 0.12
	flash_sphere(
		tree, origin, r, color, MatchConfig.get_value("debug.viz.muzzle_duration_s")
	)


## World-space hit marker (cross) + optional damage pip at impact.
func flash_hit_marker(
		tree: SceneTree, pos: Vector3, damage: float, zone: String
) -> void:
	if not enabled() or tree == null:
		return
	var dur: float = MatchConfig.get_value("debug.viz.hit_marker_duration_s")
	var col := zone_tracer_color(zone, true)
	var host := Node3D.new()
	host.name = "PlaytestHitMarker"
	_fx_parent(tree).add_child(host)
	host.global_position = pos

	var arm := 0.12
	_add_marker_line(host, Vector3(-arm, 0.0, 0.0), Vector3(arm, 0.0, 0.0), col)
	_add_marker_line(host, Vector3(0.0, -arm, 0.0), Vector3(0.0, arm, 0.0), col)

	if MatchConfig.get_value("debug.viz.show_damage_pips") > 0.5:
		_spawn_damage_label(host, damage, col)

	_track_fx(host, tree, dur)


## Slip destination ghost sphere (short-lived).
func flash_slip_ghost(tree: SceneTree, pos: Vector3) -> void:
	if not enabled() or tree == null:
		return
	if MatchConfig.get_value("debug.viz.show_slip_ghost") <= 0.5:
		return
	var col := Color(0.55, 0.9, 1.0, 0.4)
	flash_sphere(tree, pos, 0.45, col, 0.35)


func _add_marker_line(parent: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	im.surface_end()
	mi.mesh = im
	mi.material_override = tracer_mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _spawn_damage_label(parent: Node3D, damage: float, color: Color) -> void:
	var label := Label3D.new()
	label.name = "DamagePip"
	label.text = str(int(round(damage)))
	label.font_size = 48
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, 0.2, 0.0)
	parent.add_child(label)
