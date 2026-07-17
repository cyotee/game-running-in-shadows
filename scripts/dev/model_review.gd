# Model Review Grid
# Loads GLBs from models/placeholders and lays them out by pack for art review.
# Run: scenes/dev/model_review.tscn
extends Node3D

const ROOT := "res://models/placeholders"
const CELL := 3.5
const ROW_GAP := 6.0

@onready var camera: Camera3D = $Camera3D
@onready var label: Label = $CanvasLayer/InfoLabel
@onready var light: DirectionalLight3D = $DirectionalLight3D

var yaw: float = 0.0
var pitch: float = -0.35
var distance: float = 14.0
var focus := Vector3(8, 1.2, 8)
var pack_centers: Array[Vector3] = []
var pack_names: Array[String] = []
var pack_index: int = 0
var mouse_captured: bool = true


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_grid()
	_update_camera()
	_update_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch - event.relative.y * 0.004, -1.2, 0.2)
		_update_camera()
	if event.is_action_pressed("ui_cancel"):
		mouse_captured = not mouse_captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_focus_pack(-1)
			KEY_E:
				_focus_pack(1)
			KEY_R:
				_clear_models()
				_build_grid()
				_update_label()
			KEY_EQUAL, KEY_KP_ADD:
				distance = clampf(distance - 1.5, 4.0, 40.0)
				_update_camera()
			KEY_MINUS, KEY_KP_SUBTRACT:
				distance = clampf(distance + 1.5, 4.0, 40.0)
				_update_camera()


func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_key_pressed(KEY_SPACE):
		move.y += 1.0
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C):
		move.y -= 1.0
	if move != Vector3.ZERO:
		var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0))
		focus += basis * move.normalized() * 8.0 * delta
		_update_camera()


func _focus_pack(delta_idx: int) -> void:
	if pack_centers.is_empty():
		return
	pack_index = (pack_index + delta_idx) % pack_centers.size()
	if pack_index < 0:
		pack_index += pack_centers.size()
	focus = pack_centers[pack_index] + Vector3(0, 1.2, 0)
	_update_camera()
	_update_label()


func _update_camera() -> void:
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	) * distance
	camera.global_position = focus - offset
	camera.look_at(focus, Vector3.UP)


func _update_label() -> void:
	var pack := pack_names[pack_index] if pack_names.size() > 0 else "(none)"
	label.text = (
		"Placeholder model review\n"
		+ "Pack %d/%d: %s\n" % [pack_index + 1, max(pack_names.size(), 1), pack]
		+ "WASD move · Mouse look · Q/E pack · +/- zoom · R reload · Esc mouse"
	)


func _clear_models() -> void:
	for child in $Models.get_children():
		child.queue_free()
	pack_centers.clear()
	pack_names.clear()
	pack_index = 0


func _build_grid() -> void:
	var packs := _discover_packs(ROOT)
	packs.sort()
	var row := 0
	for pack_path in packs:
		var files := _list_glbs(pack_path)
		if files.is_empty():
			continue
		var rel := pack_path.replace(ROOT + "/", "")
		pack_names.append(rel)
		var col := 0
		var row_origin := Vector3(0, 0, row * ROW_GAP)
		var sum_x := 0.0
		for file_path in files:
			var node := _load_glb(file_path)
			if node == null:
				continue
			$Models.add_child(node)
			var pos := row_origin + Vector3(col * CELL, 0, 0)
			node.global_position = pos
			_normalize_scale_and_ground(node)
			sum_x += pos.x
			col += 1
		if col > 0:
			pack_centers.append(Vector3(sum_x / float(col), 0, row_origin.z))
			_add_pack_label(rel, Vector3(sum_x / float(col), 2.4, row_origin.z))
			row += 1
	if not pack_centers.is_empty():
		focus = pack_centers[0] + Vector3(0, 1.2, 0)


func _discover_packs(root: String) -> Array[String]:
	var result: Array[String] = []
	_walk_dirs(root, result)
	return result


func _walk_dirs(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	var has_glb := false
	dir.list_dir_begin()
	var name := dir.get_next()
	var subdirs: Array[String] = []
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			subdirs.append(full)
		elif name.to_lower().ends_with(".glb"):
			has_glb = true
		name = dir.get_next()
	dir.list_dir_end()
	if has_glb:
		out.append(path)
	for sub in subdirs:
		_walk_dirs(sub, out)


func _list_glbs(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.to_lower().ends_with(".glb"):
			files.append(path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
	files.sort()
	return files


func _load_glb(path: String) -> Node3D:
	# Prefer Godot-imported scene if available (after editor import).
	var import_path := path + ".tscn" # not how godot stores it
	# Runtime load via GLTFDocument works without waiting on .import in many cases.
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		push_warning("Failed to load %s (err %s)" % [path, err])
		return null
	var root: Node = doc.generate_scene(state)
	if root == null:
		return null
	if root is Node3D:
		return root as Node3D
	var wrapper := Node3D.new()
	wrapper.name = path.get_file().get_basename()
	wrapper.add_child(root)
	return wrapper


func _normalize_scale_and_ground(node: Node3D) -> void:
	# Fit each model into roughly a 2m cell so scale mismatches are visible but browsable.
	var aabb := _combined_aabb(node)
	if aabb.size == Vector3.ZERO:
		return
	var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	if max_dim <= 0.001:
		return
	var target := 2.0
	var s := target / max_dim
	# Don't explode tiny props too much or crush huge mechs completely.
	s = clampf(s, 0.15, 8.0)
	node.scale = Vector3.ONE * s
	# Recompute after scale and ground the feet.
	aabb = _combined_aabb(node)
	node.global_position.y -= aabb.position.y


func _combined_aabb(node: Node3D) -> AABB:
	var acc := AABB()
	var first := true
	for child in _find_visual_instances(node):
		var xf: Transform3D = child.global_transform
		var local: AABB = child.get_aabb()
		var corners := [
			xf * local.position,
			xf * (local.position + Vector3(local.size.x, 0, 0)),
			xf * (local.position + Vector3(0, local.size.y, 0)),
			xf * (local.position + Vector3(0, 0, local.size.z)),
			xf * (local.position + Vector3(local.size.x, local.size.y, 0)),
			xf * (local.position + Vector3(local.size.x, 0, local.size.z)),
			xf * (local.position + Vector3(0, local.size.y, local.size.z)),
			xf * (local.position + local.size),
		]
		for c in corners:
			if first:
				acc = AABB(c, Vector3.ZERO)
				first = false
			else:
				acc = acc.expand(c)
	return acc


func _find_visual_instances(node: Node) -> Array[VisualInstance3D]:
	var out: Array[VisualInstance3D] = []
	if node is VisualInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_visual_instances(child))
	return out


func _add_pack_label(text: String, pos: Vector3) -> void:
	var label_3d := Label3D.new()
	label_3d.text = text
	label_3d.font_size = 48
	label_3d.modulate = Color(0.85, 0.95, 1.0)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.position = pos
	$Models.add_child(label_3d)
