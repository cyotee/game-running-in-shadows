# Dev-only arsenal / shop for arena kit testing.
# Toggle: F10 (or `dev_arsenal` action). Give money, buy, refund/remove so a
# replacement can be purchased. Uses Economy when present; otherwise creates a
# local offline Economy for peer 1.
# Display row: live window size + UI scale (DisplayConfig, user:// persist).
extends CanvasLayer

const TOGGLE_ACTION := &"dev_arsenal"

var _economy: Economy
var _peer_id: int = 1
var _status: String = ""
var _display_syncing: bool = false

@onready var _root_panel: PanelContainer = $Panel
@onready var _money_label: Label = %MoneyLabel
@onready var _status_label: Label = %StatusLabel
@onready var _item_list: ItemList = %ItemList
@onready var _owned_list: ItemList = %OwnedList
@onready var _res_option: OptionButton = %ResOption
@onready var _scale_option: OptionButton = %ScaleOption
@onready var _fullscreen: CheckButton = %Fullscreen
@onready var _display_info: Label = %DisplayInfo


func _ready() -> void:
	layer = 32
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action(TOGGLE_ACTION):
		InputMap.add_action(TOGGLE_ACTION)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F10
		InputMap.action_add_event(TOGGLE_ACTION, ev)
	_ensure_economy()
	_setup_display_controls()
	_rebuild_catalog()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION):
		visible = not visible
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_sync_display_controls()
			_refresh()
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		_refresh_money_only()


func _ensure_economy() -> void:
	_economy = get_tree().get_first_node_in_group("economy") as Economy
	if _economy != null:
		return
	_economy = Economy.new()
	_economy.name = "DevEconomy"
	_economy.add_to_group("economy")
	add_child(_economy)
	# No MatchState -> try_buy ignores phase (phase check only when MS present).
	_economy.register_player(_peer_id)


func _local_player() -> FPSController:
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as FPSController
		if p != null and p.input.is_multiplayer_authority():
			_peer_id = p.input.get_multiplayer_authority()
			return p
	return null


func _rebuild_catalog() -> void:
	_item_list.clear()
	for key in Economy.CATALOG:
		var price := int(MatchConfig.get_value("price.%s" % key))
		_item_list.add_item("%s  ($%d)" % [key, price])
		_item_list.set_item_metadata(_item_list.item_count - 1, key)


func _selected_catalog_key() -> String:
	var sel := _item_list.get_selected_items()
	if sel.is_empty():
		return ""
	return str(_item_list.get_item_metadata(sel[0]))


func _selected_owned_key() -> String:
	var sel := _owned_list.get_selected_items()
	if sel.is_empty():
		return ""
	return str(_owned_list.get_item_metadata(sel[0]))


func _refresh_money_only() -> void:
	if _economy == null:
		return
	_money_label.text = "Money: $%d   peer %d" % [_economy.money_of(_peer_id), _peer_id]


func _refresh() -> void:
	_local_player()
	if _economy != null and not _economy.money.has(_peer_id):
		_economy.register_player(_peer_id)
	_refresh_money_only()
	_owned_list.clear()
	if _economy == null:
		return
	var bag: Dictionary = _economy.owned.get(_peer_id, {})
	for key in bag.keys():
		var price := int(MatchConfig.get_value("price.%s" % str(key)))
		_owned_list.add_item("%s  (refund $%d)" % [key, price])
		_owned_list.set_item_metadata(_owned_list.item_count - 1, key)
	var p := _local_player()
	var loadout := ""
	if p != null:
		loadout = "Slots: 1=%s  2=%s  |  grenades=%d  null=%d" % [
			p.weapon_rig.slot1 if p.weapon_rig.slot1 != "" else "-",
			p.weapon_rig.slot2 if p.weapon_rig.slot2 != "" else "-",
			p.grenade_stock, p.null_stock]
	_status_label.text = (_status if _status != "" else "F10 close · buy / refund for kit swaps") + "\n" + loadout


func _on_give_1000() -> void:
	_economy.give_money(_peer_id, 1000)
	_status = "Gave $1000"
	_refresh()


func _on_give_5000() -> void:
	_economy.give_money(_peer_id, 5000)
	_status = "Gave $5000"
	_refresh()


func _on_buy() -> void:
	var key := _selected_catalog_key()
	if key == "":
		_status = "Select a catalog item"
		_refresh()
		return
	_local_player()
	if not _economy.money.has(_peer_id):
		_economy.register_player(_peer_id)
	# Arena has no buy phase: ignore_phase.
	if _economy.try_buy(_peer_id, key, true):
		_status = "Bought %s" % key
	else:
		_status = "Buy failed: %s (funds, owned, or cyber slot)" % key
	_refresh()


func _on_refund() -> void:
	var key := _selected_owned_key()
	if key == "":
		key = _selected_catalog_key()
	if key == "":
		_status = "Select an owned item (or catalog item you own)"
		_refresh()
		return
	if _economy.refund(_peer_id, key, true):
		_status = "Refunded %s (can buy replacement)" % key
	else:
		_status = "Refund failed: %s (pistol is permanent free sidearm)" % key
	_refresh()


func _on_refund_no_cash() -> void:
	var key := _selected_owned_key()
	if key == "":
		key = _selected_catalog_key()
	if key == "":
		_status = "Select an owned item"
		_refresh()
		return
	if _economy.refund(_peer_id, key, false):
		_status = "Removed %s (no cash refund)" % key
	else:
		_status = "Remove failed: %s" % key
	_refresh()


func _on_clear_weapons() -> void:
	var p := _local_player()
	if p == null:
		return
	for key in ["smg", "shotgun", "rifle", "sniper", "blade"]:
		if _economy.owns(_peer_id, key):
			_economy.refund(_peer_id, key, true)
		else:
			p.queue_clear_weapon(key)
	_status = "Cleared non-pistol weapons (refunded if owned)"
	_refresh()


# --- Display (resolution / UI scale) ---

func _setup_display_controls() -> void:
	_display_syncing = true
	_res_option.clear()
	for p in DisplayConfig.PRESETS:
		_res_option.add_item(str(p["label"]))
	_scale_option.clear()
	for s in DisplayConfig.UI_SCALE_STEPS:
		_scale_option.add_item("UI x%s" % str(s))
	_display_syncing = false
	_sync_display_controls()


func _sync_display_controls() -> void:
	_display_syncing = true
	var pi := DisplayConfig.preset_index_for_current()
	if pi >= 0:
		_res_option.select(pi)
	else:
		# Custom size: show as first preset text override is awkward; leave
		# selection and surface exact size in the info label.
		pass
	var scale_idx := 0
	var best := 999.0
	for i in DisplayConfig.UI_SCALE_STEPS.size():
		var d := absf(DisplayConfig.UI_SCALE_STEPS[i] - DisplayConfig.ui_scale)
		if d < best:
			best = d
			scale_idx = i
	_scale_option.select(scale_idx)
	_fullscreen.button_pressed = DisplayConfig.fullscreen
	_display_syncing = false
	_refresh_display_info()


func _refresh_display_info() -> void:
	var requested := DisplayConfig.resolve_size()
	var actual := Vector2i.ZERO
	if DisplayServer.get_name() != "headless":
		var root := get_tree().root as Window
		if root != null:
			actual = DisplayServer.window_get_size(root.get_window_id())
	if actual == Vector2i.ZERO:
		_display_info.text = "req %dx%d · UI x%s" % [
			requested.x, requested.y, str(DisplayConfig.ui_scale)]
	else:
		_display_info.text = "%dx%d · UI x%s" % [
			actual.x, actual.y, str(DisplayConfig.ui_scale)]


func _on_res_selected(index: int) -> void:
	if _display_syncing:
		return
	if index < 0 or index >= DisplayConfig.PRESETS.size():
		return
	var p: Dictionary = DisplayConfig.PRESETS[index]
	DisplayConfig.set_resolution(int(p["w"]), int(p["h"]))
	_status = DisplayConfig.last_apply_message
	_refresh_display_info()
	_refresh()


func _on_scale_selected(index: int) -> void:
	if _display_syncing:
		return
	if index < 0 or index >= DisplayConfig.UI_SCALE_STEPS.size():
		return
	var s: float = DisplayConfig.UI_SCALE_STEPS[index]
	DisplayConfig.set_ui_scale(s)
	_status = DisplayConfig.last_apply_message
	_refresh_display_info()
	_refresh()


func _on_fullscreen_toggled(pressed: bool) -> void:
	if _display_syncing:
		return
	DisplayConfig.set_fullscreen(pressed)
	_status = DisplayConfig.last_apply_message
	_refresh_display_info()
	_refresh()
