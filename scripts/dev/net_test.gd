# Two-instance netcode test harness.
# Launch the scene twice: the first instance hosts on 127.0.0.1:9999, later
# instances auto-join (netfox NetworkSimulator). Latency is injected via the
# NET_TEST_LATENCY_MS env var. One FPSController spawns per peer.
extends Node3D

const PLAYER_SCENE := "res://scenes/player/fps_controller.tscn"

@onready var spawner: MultiplayerSpawner = $Players/MultiplayerSpawner


func _enter_tree() -> void:
	# NetworkSimulator reads these in its _ready (child ready runs before
	# ours), so configure them here. Runtime-only; never persisted.
	ProjectSettings.set_setting("netfox/autoconnect/enabled", true)
	ProjectSettings.set_setting("netfox/autoconnect/host", "127.0.0.1")
	ProjectSettings.set_setting("netfox/autoconnect/port", 9999)
	var latency_env := OS.get_environment("NET_TEST_LATENCY_MS")
	if latency_env != "" and latency_env.is_valid_int():
		ProjectSettings.set_setting("netfox/autoconnect/simulated_latency_ms", int(latency_env))


func _ready() -> void:
	spawner.spawn_function = _spawn_player
	# The netfox.extras plugin re-registers the NetworkSimulator autoload on
	# every editor load, so that instance is THE simulator — a scene-local
	# copy would race it for the host port. Deferred: the simulator emits
	# server_created before it assigns multiplayer.multiplayer_peer.
	var simulator: Node = get_node("/root/NetworkSimulator")
	simulator.server_created.connect(_on_server_created, CONNECT_DEFERRED)


func _on_server_created() -> void:
	NetworkTime.start()
	_do_spawn(1)
	multiplayer.peer_connected.connect(_do_spawn)
	multiplayer.peer_disconnected.connect(_despawn)


func _do_spawn(peer_id: int) -> void:
	spawner.spawn(peer_id)


func _despawn(peer_id: int) -> void:
	var node := get_node_or_null("Players/%d" % peer_id)
	if node:
		node.queue_free()


func _spawn_player(peer_id: int) -> Node:
	var player: FPSController = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.name = str(peer_id)
	player.position = Vector3(peer_id * 2.0, 1.5, 0)
	# State stays server-authoritative (node authority = 1); only the input
	# node belongs to the owning peer. Controller _ready re-runs
	# process_settings after this.
	player.get_node("Input").set_multiplayer_authority(peer_id)
	return player
