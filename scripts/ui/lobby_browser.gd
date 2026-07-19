# Public lobby browser: renders SessionManager.browse() results.
# LobbyBrowserModel is separable pure logic so the formatting is unit-tested
# without UI or Steam.
extends Control


class LobbyBrowserModel:
	extends RefCounted

	static func format_entry(entry: Dictionary) -> String:
		if not (entry.has("name") and entry.has("mode")
				and entry.has("count") and entry.has("max")):
			return ""
		return "%s — %s — %d/%d" % [entry.name, entry.mode, entry.count, entry.max]

	static func to_rows(entries: Array) -> Array[Dictionary]:
		var rows: Array[Dictionary] = []
		for entry in entries:
			if not (entry is Dictionary and entry.has("id")):
				continue
			var label: String = format_entry(entry)
			if label == "":
				continue
			rows.append({"id": entry.id, "label": label})
		return rows


var _rows: Array[Dictionary] = []

@onready var item_list: ItemList = %LobbyList


func _ready() -> void:
	SessionManager.lobby_list_ready.connect(_on_lobby_list)
	%RefreshButton.pressed.connect(refresh)
	%JoinButton.pressed.connect(_join_selected)
	%CloseButton.pressed.connect(func() -> void: visible = false)
	item_list.item_activated.connect(func(_index: int) -> void: _join_selected())


func refresh() -> void:
	SessionManager.browse()


func _on_lobby_list(entries: Array) -> void:
	_rows = LobbyBrowserModel.to_rows(entries)
	item_list.clear()
	for row in _rows:
		item_list.add_item(row.label)


func _join_selected() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	SessionManager.join(_rows[selected[0]].id)
