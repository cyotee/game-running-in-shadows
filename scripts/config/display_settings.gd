# Runtime display preferences (window size + UI scale).
# Autoload: DisplayConfig. Persists to user://display_settings.json.
#
# Godot model (official "Multiple resolutions" docs + common desktop pattern):
#   - Project base size (content_scale_size) = design size for 2D/UI layout.
#   - Stretch mode canvas_items + aspect expand → 2D UI scales to the window.
#   - 3D always renders at the real window pixel size (fills the window).
#   - "Resolution" option changes the OS window size only (get_window().size).
#   - "UI scale" is content_scale_factor (extra magnification).
#
# Editor embed: OS window size is locked by the Game dock. Prefs still save;
# turn off Game → Embed Game on Next Play for window resize to work.
extends Node

const SAVE_PATH := "user://display_settings.json"

## Design / stretch base size (matches project.godot viewport). Not the user resolution.
const BASE_SIZE := Vector2i(1920, 1080)

const PRESETS: Array[Dictionary] = [
	{"label": "1280x720 (720p)", "w": 1280, "h": 720},
	{"label": "1600x900", "w": 1600, "h": 900},
	{"label": "1920x1080 (1080p)", "w": 1920, "h": 1080},
	{"label": "2560x1440 (1440p)", "w": 2560, "h": 1440},
	{"label": "2880x1620", "w": 2880, "h": 1620},
	{"label": "3200x1800", "w": 3200, "h": 1800},
	{"label": "3840x2160 (4K)", "w": 3840, "h": 2160},
	{"label": "Native screen", "w": 0, "h": 0},
]

const UI_SCALE_STEPS: Array[float] = [1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

const DEFAULT_WIDTH: int = 1920
const DEFAULT_HEIGHT: int = 1080
const DEFAULT_UI_SCALE: float = 1.5

var width: int = DEFAULT_WIDTH
var height: int = DEFAULT_HEIGHT
var ui_scale: float = DEFAULT_UI_SCALE
var fullscreen: bool = false

var last_apply_message: String = ""
var last_apply_window_locked: bool = false


func _ready() -> void:
	_load()
	_apply_cmdline_user_args()
	_apply_when_ready()


func _apply_when_ready() -> void:
	for _i in 4:
		await get_tree().process_frame
	apply()


func is_embedded() -> bool:
	if Engine.has_method("is_embedded_in_editor"):
		return bool(Engine.call("is_embedded_in_editor"))
	return false


func get_root_window() -> Window:
	return get_tree().root as Window


func apply() -> bool:
	last_apply_window_locked = false
	if DisplayServer.get_name() == "headless":
		last_apply_message = "headless — display apply skipped"
		return false

	var win := get_root_window()
	if win == null:
		last_apply_message = "no root window yet"
		return false

	# 1) Stretch setup: fixed design base + expand → 2D fills window, no letterbox panel.
	#    3D uses real window pixels (always fills).
	_apply_stretch(win)

	var requested := resolve_size()
	var id := win.get_window_id()

	if is_embedded():
		last_apply_window_locked = true
		last_apply_message = (
			"Prefs saved: %dx%d, UI x%s. "
			+ "EDITOR EMBED is ON — the Game dock owns the window size, so "
			+ "resolution cannot change the OS window. "
			+ "In the Game panel menu, set size to Stretch to Fit and turn OFF "
			+ "'Embed Game on Next Play', then press Play again. "
			+ "UI stretch/scale still applied inside the dock."
		) % [requested.x, requested.y, str(ui_scale)]
		push_warning("DisplayConfig: %s" % last_apply_message)
		return false

	if fullscreen:
		win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		await get_tree().process_frame
		_apply_stretch(win)
		var fs := win.size
		last_apply_message = "Exclusive fullscreen %dx%d · UI x%s (stretch base %dx%d)" % [
			fs.x, fs.y, str(ui_scale), BASE_SIZE.x, BASE_SIZE.y]
		print("DisplayConfig: %s" % last_apply_message)
		return true

	# Windowed: leave exclusive/maximized so size sticks.
	if win.mode != Window.MODE_WINDOWED:
		win.mode = Window.MODE_WINDOWED
		await get_tree().process_frame

	win.borderless = false
	win.unresizable = false
	win.min_size = Vector2i(640, 360)

	var screen := win.current_screen
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var target := requested
	var fitted := false
	if target.x > usable.size.x or target.y > usable.size.y:
		var s := minf(
			float(usable.size.x) / float(target.x),
			float(usable.size.y) / float(target.y)
		)
		target = Vector2i(
			maxi(640, int(round(float(target.x) * s))),
			maxi(360, int(round(float(target.y) * s)))
		)
		fitted = true

	# Official/runtime pattern: set Window.size (root Viewport size + OS window).
	# DisplayServer alone is unreliable on some platforms; set both.
	win.size = target
	DisplayServer.window_set_size(target, id)
	await get_tree().process_frame

	var pos := usable.position + (usable.size - win.size) / 2
	pos.x = maxi(usable.position.x, pos.x)
	pos.y = maxi(usable.position.y, pos.y)
	win.position = pos
	DisplayServer.window_set_position(pos, id)

	# Re-apply stretch after size settles.
	_apply_stretch(win)

	var actual := win.size
	last_apply_message = "Window %dx%d (requested %dx%d) · UI x%s · stretch base %dx%d" % [
		actual.x, actual.y, requested.x, requested.y, str(ui_scale),
		BASE_SIZE.x, BASE_SIZE.y]
	if fitted:
		last_apply_message += " — fitted to usable screen"
	elif actual != target:
		last_apply_message += " — OS adjusted size"
	print("DisplayConfig: %s" % last_apply_message)
	return true


func _apply_stretch(win: Window) -> void:
	# Design size stays fixed (1920x1080). Window size is independent.
	# canvas_items + expand: 2D/UI scales to fill the window without black bars.
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = BASE_SIZE
	win.content_scale_factor = clampf(ui_scale, 0.5, 4.0)


func resolve_size() -> Vector2i:
	if width <= 0 or height <= 0:
		if DisplayServer.get_name() == "headless":
			return Vector2i(1920, 1080)
		return DisplayServer.screen_get_usable_rect().size
	return Vector2i(maxi(640, width), maxi(360, height))


func set_resolution(w: int, h: int, persist: bool = true) -> void:
	width = w
	height = h
	if persist:
		save()
	apply()


func set_ui_scale(scale: float, persist: bool = true) -> void:
	ui_scale = clampf(scale, 0.5, 4.0)
	if persist:
		save()
	apply()


func set_fullscreen(enabled: bool, persist: bool = true) -> void:
	fullscreen = enabled
	if persist:
		save()
	apply()


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
	f.close()
	print("DisplayConfig: saved %dx%d UI x%s → %s" % [
		width, height, str(ui_scale), SAVE_PATH])


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("DisplayConfig: no save — defaults %dx%d UI x%s" % [
			width, height, str(ui_scale)])
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		push_warning("DisplayConfig: invalid JSON at %s" % SAVE_PATH)
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
	print("DisplayConfig: loaded %dx%d UI x%s from %s" % [
		width, height, str(ui_scale), SAVE_PATH])


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


func apply_dict_for_test(d: Dictionary) -> void:
	if d.has("width"):
		width = int(d["width"])
	if d.has("height"):
		height = int(d["height"])
	if d.has("ui_scale"):
		ui_scale = float(d["ui_scale"])
	if d.has("fullscreen"):
		fullscreen = bool(d["fullscreen"])
