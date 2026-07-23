# Runtime display preferences for playtesting (window size, mode, UI scale).
# Autoload singleton name: DisplayConfig (registered in project.godot).
# No class_name — avoids "hides an autoload singleton" / analyzer conflicts.
# Persists to user://display_settings.json.
# Cmdline user args: --window-size=1920x1080  --ui-scale=1.5  --fullscreen  --windowed
extends Node

const SAVE_PATH := "user://display_settings.json"

## Named window sizes. w/h of 0 means "usable screen size" (native).
const PRESETS: Array[Dictionary] = [
	{"label": "1280x720", "w": 1280, "h": 720},
	{"label": "1600x900", "w": 1600, "h": 900},
	{"label": "1920x1080", "w": 1920, "h": 1080},
	{"label": "2560x1440", "w": 2560, "h": 1440},
	{"label": "2880x1620", "w": 2880, "h": 1620},
	{"label": "Native screen", "w": 0, "h": 0},
]

const UI_SCALE_STEPS: Array[float] = [1.0, 1.25, 1.5, 1.75, 2.0, 2.5]

# Default is 1920x1080 + 50% (playtest readability).
var width: int = 2880
var height: int = 1620
var ui_scale: float = 1.25
var fullscreen: bool = false

## Last human-readable apply result (for Dev Arsenal status).
var last_apply_message: String = ""


func _ready() -> void:
	_load()
	_apply_cmdline_user_args()
	# Window may not be ready on the first frame in the editor.
	call_deferred("apply")


func is_embedded() -> bool:
	if Engine.has_method("is_embedded_in_editor"):
		return bool(Engine.call("is_embedded_in_editor"))
	return false


func apply() -> bool:
	if DisplayServer.get_name() == "headless":
		last_apply_message = "headless — display apply skipped"
		return false

	# Embedded Game tab cannot change OS window size; only UI scale works.
	if is_embedded():
		var root_emb := get_tree().root as Window
		if root_emb != null:
			_apply_ui_scale_only(root_emb)
		last_apply_message = (
			"Game is embedded in the editor — window size locked. "
			+ "Turn off Game > Embed Game on Next Play, or run outside the editor. "
			+ "UI scale still applied (x%s)." % str(ui_scale)
		)
		push_warning("DisplayConfig: %s" % last_apply_message)
		return false

	var root := get_tree().root as Window
	if root == null:
		last_apply_message = "no root window"
		return false

	var size := resolve_size()
	var id := root.get_window_id()

	# DisplayServer signatures (Godot 4): size/position FIRST, optional window_id last.
	# window_set_size(size: Vector2i, window_id: int = 0)
	# window_set_position(position: Vector2i, window_id: int = 0)
	# window_set_mode(mode: WindowMode, window_id: int = 0)
	if fullscreen:
		# Exclusive fullscreen uses the monitor's native mode; size is N/A.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN, id)
		_apply_ui_scale_only(root)
		var actual_fs := DisplayServer.window_get_size(id)
		last_apply_message = "Fullscreen (display %dx%d, UI x%s)" % [
			actual_fs.x, actual_fs.y, str(ui_scale)]
		return true

	# Size is ignored while maximized/fullscreen — leave those modes first.
	var mode := DisplayServer.window_get_mode(id)
	if mode != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, id)
	root.borderless = false
	root.unresizable = false

	# DisplayServer is the reliable path across platforms; also set Window.size.
	DisplayServer.window_set_size(size, id)
	root.size = size

	# Center on the current screen so a smaller res is not stuck off-screen.
	var screen := root.current_screen
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var pos := usable.position + (usable.size - size) / 2
	pos.x = maxi(usable.position.x, pos.x)
	pos.y = maxi(usable.position.y, pos.y)
	DisplayServer.window_set_position(pos, id)

	# Base content size = chosen resolution; factor scales UI/HUD on top.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = size
	root.content_scale_factor = clampf(ui_scale, 0.5, 4.0)

	# Read back what the OS actually applied (clamped by min size / DPI).
	var actual := DisplayServer.window_get_size(id)
	last_apply_message = "Window %dx%d (requested %dx%d), UI x%s" % [
		actual.x, actual.y, size.x, size.y, str(ui_scale)]
	if actual != size:
		last_apply_message += " — OS adjusted size (DPI / min constraints)"
	return true


func _apply_ui_scale_only(root: Window) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if root.content_scale_size == Vector2i.ZERO:
		root.content_scale_size = resolve_size()
	root.content_scale_factor = clampf(ui_scale, 0.5, 4.0)


func resolve_size() -> Vector2i:
	if width <= 0 or height <= 0:
		if DisplayServer.get_name() == "headless":
			return Vector2i(1920, 1080)
		return DisplayServer.screen_get_usable_rect().size
	return Vector2i(maxi(640, width), maxi(360, height))


func set_resolution(w: int, h: int, persist: bool = true) -> bool:
	width = w
	height = h
	if persist:
		save()
	return apply()


func set_ui_scale(scale: float, persist: bool = true) -> bool:
	ui_scale = clampf(scale, 0.5, 4.0)
	if persist:
		save()
	return apply()


func set_fullscreen(enabled: bool, persist: bool = true) -> bool:
	fullscreen = enabled
	if persist:
		save()
	return apply()


func cycle_ui_scale(delta_steps: int = 1) -> void:
	var idx := 0
	var best_dist := 999.0
	for i in UI_SCALE_STEPS.size():
		var d := absf(UI_SCALE_STEPS[i] - ui_scale)
		if d < best_dist:
			best_dist = d
			idx = i
	idx = clampi(idx + delta_steps, 0, UI_SCALE_STEPS.size() - 1)
	set_ui_scale(UI_SCALE_STEPS[idx])


func preset_index_for_current() -> int:
	for i in PRESETS.size():
		var p: Dictionary = PRESETS[i]
		if int(p["w"]) == width and int(p["h"]) == height:
			return i
	return -1


func save() -> void:
	var data := {
		"width": width,
		"height": height,
		"ui_scale": ui_scale,
		"fullscreen": fullscreen,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("DisplayConfig: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data, "\t"))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is not Dictionary:
		return
	var d: Dictionary = parsed
	if d.has("width"):
		width = int(d["width"])
	if d.has("height"):
		height = int(d["height"])
	if d.has("ui_scale"):
		ui_scale = float(d["ui_scale"])
	if d.has("fullscreen"):
		fullscreen = bool(d["fullscreen"])


func _apply_cmdline_user_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--window-size="):
			var spec := arg.trim_prefix("--window-size=").to_lower()
			if spec == "native":
				width = 0
				height = 0
				continue
			var parts := spec.split("x")
			if parts.size() == 2:
				width = int(parts[0])
				height = int(parts[1])
		elif arg.begins_with("--ui-scale="):
			ui_scale = float(arg.trim_prefix("--ui-scale="))
		elif arg == "--fullscreen":
			fullscreen = true
		elif arg == "--windowed":
			fullscreen = false


## Test helper: apply a dict without touching the real save file.
func apply_dict_for_test(d: Dictionary) -> void:
	if d.has("width"):
		width = int(d["width"])
	if d.has("height"):
		height = int(d["height"])
	if d.has("ui_scale"):
		ui_scale = float(d["ui_scale"])
	if d.has("fullscreen"):
		fullscreen = bool(d["fullscreen"])
