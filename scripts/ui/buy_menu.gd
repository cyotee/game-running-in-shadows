# Debug-grade buy menu: visible during BUY_PHASE only. Purchases go through
# Economy (locally on the host/offline, by RPC as a client).
extends Panel

const ITEMS: Array[String] = ["smg", "shotgun", "rifle", "sniper", "blade"]

var _economy: Economy
var _match_state: MatchState

@onready var item_list: ItemList = %ItemList


func _ready() -> void:
	var session := get_node("../..")
	_economy = session.get_node("Economy")
	_match_state = session.get_node("MatchState")
	_match_state.phase_changed.connect(_on_phase_changed)
	_economy.money_changed.connect(func(peer_id: int, amount: int) -> void:
		if peer_id == multiplayer.get_unique_id():
			%MoneyLabel.text = "$%d" % amount)
	%BuyButton.pressed.connect(_buy_selected)
	%LoadoutButton.pressed.connect(func() -> void:
		_request(func() -> void:
			_economy.apply_loadout(multiplayer.get_unique_id(), Economy.DEFAULT_LOADOUT),
			func() -> void: _economy.request_loadout.rpc_id(1, Economy.DEFAULT_LOADOUT)))
	for item in ITEMS:
		item_list.add_item("%s — $%d" % [item, int(MatchConfig.get_value("price.%s" % item))])
	visible = _match_state.phase == MatchState.BUY_PHASE
	%MoneyLabel.text = "$%d" % _economy.money_of(multiplayer.get_unique_id())


func _on_phase_changed(phase: int) -> void:
	visible = phase == MatchState.BUY_PHASE
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		%MoneyLabel.text = "$%d" % _economy.money_of(multiplayer.get_unique_id())
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _buy_selected() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	var item := ITEMS[selected[0]]
	_request(func() -> void: _economy.try_buy(multiplayer.get_unique_id(), item),
		func() -> void: _economy.request_buy.rpc_id(1, item))


func _request(local_call: Callable, rpc_call: Callable) -> void:
	if _economy.is_authority():
		local_call.call()
	else:
		rpc_call.call()
