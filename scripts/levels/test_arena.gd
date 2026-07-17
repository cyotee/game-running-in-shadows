# Offline bootstrap: netfox's tick loop must be started explicitly when no
# multiplayer session exists (NetworkEvents handles the networked case).
extends Node3D


func _ready() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer:
		NetworkTime.start()
