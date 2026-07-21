# Ping System Implementation Plan (G7, pass 1: aimed ping)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an aimed ping — one button that tags an enemy (a marker tracking that enemy, consumable by Familiar) or marks a world point, shared with teammates as HUD markers with a short lifetime.

**Architecture:** Pings are intel/comms and live entirely OUTSIDE the netfox rollback path — no press-ticks, no `RollbackSynchronizer` state. `PingService` (autoload) is a host-authoritative record store using the `economy.gd`/`match_state.gd` RPC pattern (`is_authority()` + `@rpc(..., "call_remote", ...)`, direct local call when server/offline). `FPSController.try_ping()` raycasts from the camera (reusing the `enemy_under_reticle` query) and classifies enemy-tag vs world-point, then calls `PingService`. The HUD projects visible pings world→screen each frame.

**Tech Stack:** Godot 4.7.1, GDScript (typed), GdUnit4 tests, netfox (only for `NetworkTime.tick` as a monotonic clock — NOT rollback).

## Global Constraints

- IP: original terms only (Resonance, Runners, Grid, Manifestations, Augments, Repulse, Glide) — never Shadowrun trademarks.
- All gameplay numbers come from `MatchConfig.DEFAULTS` — never hard-code a tunable. Baselines recorded in `docs/ABILITY_TUNING_SHEET.md`.
- Typed GDScript (`:=`, typed params/returns), `class_name` for reusable classes.
- Pings are NOT rollback-simulated: no entry in any `RollbackSynchronizer.state_properties`, no `_rollback_tick`, no `NetworkRollback.mutate`, no press-tick input.
- Host-authoritative: the server assigns team and validates; never trust a client's reported team (anti-cheat Layer 1).
- Offline/single-player/headless must work: `multiplayer.multiplayer_peer == null` or `OfflineMultiplayerPeer` counts as authority; the local effect runs in-process with no live RPC.
- Headless runs have no Steam client and no HUD camera consumers; `PingService` logic and `try_ping` classification must be testable headless.
- Tests: GdUnit4 under `tests/` mirroring `scripts/`; headless run must be `0 errors | 0 failures`, exit 0.
- Commits end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

## File Structure

- Create `scripts/abilities/ping_service.gd` — `PingService` autoload: record store, host logic, RPC transport, queries, expiry, reset.
- Modify `project.godot` — register the `PingService` autoload; add the `ping` input action.
- Modify `scripts/config/match_config.gd` — add `ping.*` tuning keys.
- Modify `scripts/player/fps_controller.gd` — `try_ping()` raycast + classify; trigger from `_unhandled_input`.
- Modify `scripts/session/match_session.gd` (line ~25, right after `match_state.setup(self)`) — call `PingService.setup(match_state)` so the host can resolve teams.
- Modify `scripts/ui/player_hud.gd` + `scenes/ui/player_hud.tscn` — render ping markers.
- Create `tests/abilities/test_ping_service.gd` — unit tests for `PingService`.
- Modify `tests/player/test_fps_controller.gd` — behavior test for `try_ping` classification.
- Modify `tests/e2e/net_smoke.py` — assert enemy-tag replication across peers.
- Modify `docs/ABILITY_TUNING_SHEET.md`, `docs/MECHANICS_REFERENCE.md` (§11 D-pad note), `docs/superpowers/plans/2026-07-17-master-implementation-plan.md` (G7 ✅).

---

### Task 1: PingService core (records, host logic, queries, expiry)

**Files:**
- Create: `scripts/abilities/ping_service.gd`
- Modify: `project.godot` (register autoload)
- Test: `tests/abilities/test_ping_service.gd`

**Interfaces:**
- Consumes: `MatchConfig.get_value(key)`, `NetworkTime.tick`, `MatchState.team_of(peer)`.
- Produces:
  - `PingService.WORLD: int = 0`, `PingService.ENEMY: int = 1`
  - `setup(match_state: MatchState) -> void`
  - `is_authority() -> bool`
  - `_apply_ping(owner_peer: int, kind: int, world_pos: Vector3, target_peer: int) -> void` (host seam; tests call directly)
  - `visible_pings(viewer_peer: int) -> Array` (array of ping record Dictionaries)
  - `latest_enemy_tag(owner_peer: int) -> int` (target peer, or 0)
  - `active_count() -> int`
  - `reset() -> void`
  - Record Dictionary keys: `id:int, kind:int, owner_peer:int, team:int, world_pos:Vector3, target_peer:int, expire_tick:int`

- [ ] **Step 1: Write the failing test**

Create `tests/abilities/test_ping_service.gd`:

```gdscript
class_name TestPingService
extends GdUnitTestSuite

var _state: MatchState


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)
	_state = auto_free(MatchState.new())
	add_child(_state)
	_state.assign_team(10)  # team 0
	_state.assign_team(20)  # team 1
	_state.assign_team(30)  # team 0
	PingService.setup(_state)
	PingService.reset()


func after_test() -> void:
	PingService.setup(null)
	PingService.reset()
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func test_world_ping_is_stored_and_visible_to_owner() -> void:
	PingService._apply_ping(10, PingService.WORLD, Vector3(1, 0, 2), 0)
	var pings := PingService.visible_pings(10)
	assert_int(pings.size()).is_equal(1)
	assert_int(pings[0]["kind"]).is_equal(PingService.WORLD)
	assert_vector(pings[0]["world_pos"]).is_equal(Vector3(1, 0, 2))


func test_enemy_ping_records_target_and_feeds_familiar_query() -> void:
	PingService._apply_ping(10, PingService.ENEMY, Vector3.ZERO, 20)
	assert_int(PingService.latest_enemy_tag(10)).is_equal(20)
	# World ping has no enemy tag.
	PingService._apply_ping(30, PingService.WORLD, Vector3(5, 0, 0), 0)
	assert_int(PingService.latest_enemy_tag(30)).is_equal(0)


func test_visibility_is_team_scoped() -> void:
	PingService._apply_ping(10, PingService.WORLD, Vector3(1, 0, 0), 0)  # team 0
	assert_int(PingService.visible_pings(30).size()).is_equal(1)  # 30 is team 0 -> sees it
	assert_int(PingService.visible_pings(20).size()).is_equal(0)  # 20 is team 1 -> hidden


func test_re_ping_replaces_owner_previous_ping() -> void:
	PingService._apply_ping(10, PingService.WORLD, Vector3(1, 0, 0), 0)
	PingService._apply_ping(10, PingService.ENEMY, Vector3.ZERO, 20)
	var pings := PingService.visible_pings(10)
	assert_int(pings.size()).is_equal(1)  # limit 1: replaced, not added
	assert_int(pings[0]["kind"]).is_equal(PingService.ENEMY)


func test_ping_expires_after_duration() -> void:
	PingService._apply_ping(10, PingService.WORLD, Vector3(1, 0, 0), 0)
	var record: Dictionary = PingService.visible_pings(10)[0]
	PingService._cull(record["expire_tick"] + 1)
	assert_int(PingService.active_count()).is_equal(0)
	assert_int(PingService.latest_enemy_tag(10)).is_equal(0)


func test_no_team_falls_back_to_owner_only() -> void:
	PingService.setup(null)  # no MatchState -> team -1
	PingService._apply_ping(10, PingService.WORLD, Vector3(1, 0, 0), 0)
	assert_int(PingService.visible_pings(10).size()).is_equal(1)  # owner sees own
	assert_int(PingService.visible_pings(20).size()).is_equal(0)  # nobody else
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/abilities/test_ping_service.gd --ignoreHeadlessMode
```
Expected: FAIL — `PingService` autoload not registered / methods missing.

- [ ] **Step 3: Write the PingService script**

Create `scripts/abilities/ping_service.gd`:

```gdscript
# Aimed-ping intel service. Pings are comms/intel, NOT rollback-simulated
# gameplay: no press-ticks, no RollbackSynchronizer state. Host-authoritative
# via the economy.gd/match_state.gd RPC pattern; NetworkTime.tick is used only
# as a monotonic clock for expiry. Familiar (G5 W3) reads latest_enemy_tag().
extends Node

const WORLD: int = 0
const ENEMY: int = 1

var _pings: Array[Dictionary] = []
var _next_id: int = 1
var _match_state: MatchState = null


func setup(match_state: MatchState) -> void:
	_match_state = match_state


func reset() -> void:
	_pings.clear()
	_next_id = 1


func is_authority() -> bool:
	return multiplayer.multiplayer_peer == null \
		or multiplayer.multiplayer_peer is OfflineMultiplayerPeer \
		or multiplayer.is_server()


func _process(_delta: float) -> void:
	_cull(NetworkTime.tick)


# --- Request entry point (client -> host) ---

func request_ping(kind: int, world_pos: Vector3, target_peer: int) -> void:
	if is_authority():
		var owner := 1 if multiplayer.multiplayer_peer == null \
			else multiplayer.get_unique_id()
		_apply_ping(owner, kind, world_pos, target_peer)
	else:
		_request_ping_rpc.rpc_id(1, kind, world_pos, target_peer)


@rpc("any_peer", "call_remote", "reliable")
func _request_ping_rpc(kind: int, world_pos: Vector3, target_peer: int) -> void:
	_apply_ping(multiplayer.get_remote_sender_id(), kind, world_pos, target_peer)


# --- Host logic (also the test seam) ---

func _apply_ping(owner_peer: int, kind: int, world_pos: Vector3, target_peer: int) -> void:
	# Per-player limit (1): drop the owner's previous ping first.
	_remove_owned_by(owner_peer)
	var team := _match_state.team_of(owner_peer) if _match_state != null else -1
	var duration_ticks := int(roundf(
		MatchConfig.get_value("ping.duration_s") * NetworkTime.tickrate))
	var record := {
		"id": _next_id,
		"kind": kind,
		"owner_peer": owner_peer,
		"team": team,
		"world_pos": world_pos,
		"target_peer": target_peer,
		"expire_tick": NetworkTime.tick + duration_ticks,
	}
	_next_id += 1
	_pings.append(record)
	if not is_authority():
		return
	# Broadcast to remote peers when networked; local store already updated.
	if multiplayer.multiplayer_peer != null \
			and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_add_ping_rpc.rpc(record["id"], kind, owner_peer, team,
			world_pos, target_peer, record["expire_tick"])


@rpc("authority", "call_remote", "reliable")
func _add_ping_rpc(id: int, kind: int, owner_peer: int, team: int,
		world_pos: Vector3, target_peer: int, expire_tick: int) -> void:
	_remove_owned_by(owner_peer)
	_pings.append({
		"id": id, "kind": kind, "owner_peer": owner_peer, "team": team,
		"world_pos": world_pos, "target_peer": target_peer,
		"expire_tick": expire_tick,
	})


# --- Queries ---

func visible_pings(viewer_peer: int) -> Array:
	var viewer_team := _match_state.team_of(viewer_peer) if _match_state != null else -1
	var out: Array = []
	for record in _pings:
		if record["owner_peer"] == viewer_peer:
			out.append(record)
		elif record["team"] != -1 and record["team"] == viewer_team:
			out.append(record)
	return out


func latest_enemy_tag(owner_peer: int) -> int:
	for record in _pings:
		if record["owner_peer"] == owner_peer and record["kind"] == ENEMY:
			return record["target_peer"]
	return 0


func active_count() -> int:
	return _pings.size()


# --- Internals ---

func _remove_owned_by(owner_peer: int) -> void:
	for i in range(_pings.size() - 1, -1, -1):
		if _pings[i]["owner_peer"] == owner_peer:
			_pings.remove_at(i)


func _cull(now_tick: int) -> void:
	for i in range(_pings.size() - 1, -1, -1):
		if _pings[i]["expire_tick"] <= now_tick:
			_pings.remove_at(i)
```

- [ ] **Step 4: Register the autoload**

In `project.godot`, in the `[autoload]` section, add this line after `NetworkSimulator=...` (so `NetworkTime`/`MatchConfig` load first):

```
PingService="*res://scripts/abilities/ping_service.gd"
```

- [ ] **Step 5: Run the test to verify it passes**

Run:
```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/abilities/test_ping_service.gd --ignoreHeadlessMode
```
Expected: PASS — `6 test cases | 0 errors | 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add scripts/abilities/ping_service.gd tests/abilities/test_ping_service.gd project.godot
git commit -m "$(printf 'feat: PingService core (records, team-scoped queries, expiry)\n\nHost-authoritative ping store outside the rollback path. Enemy-tag\nlatest_enemy_tag() query for Familiar. Unit-tested.\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 2: Ping input + FPSController.try_ping (raycast classify)

**Files:**
- Modify: `project.godot` (add `ping` input action)
- Modify: `scripts/config/match_config.gd` (`ping.*` keys)
- Modify: `scripts/player/fps_controller.gd` (`try_ping`, `_unhandled_input` trigger, `setup` hookup for MatchState if needed)
- Test: `tests/player/test_fps_controller.gd` (classification)

**Interfaces:**
- Consumes: `PingService.request_ping(kind, world_pos, target_peer)`, `PingService.WORLD/ENEMY`, `MatchConfig.get_value("ping.max_range_m")`, camera + `$HitZones` meta `"player"` (same as `enemy_under_reticle`).
- Produces: `FPSController.try_ping() -> void` (raycasts, classifies, calls `PingService.request_ping`).

- [ ] **Step 1: Add the `ping` MatchConfig keys**

In `scripts/config/match_config.gd`, in `DEFAULTS`, after the `corpse.*` block, add:

```gdscript
	"ping.duration_s": 4.0,
	"ping.max_range_m": 120.0,
	"ping.cooldown_s": 0.5,
	"ping.per_player_limit": 1.0,
```

- [ ] **Step 2: Add the `ping` input action to project.godot**

In `project.godot`, in the `[input]` section, add (P key = physical_keycode 80; middle mouse = button_index 3; D-pad Up = joypad button_index 11):

```
ping={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":80,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":3,"canceled":false,"pressed":true,"double_click":false,"script":null)
, Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":11,"pressure":0.0,"pressed":true,"script":null)
]
}
```

- [ ] **Step 3: Write the failing behavior test**

In `tests/player/test_fps_controller.gd`, add (uses the existing `_spawn_controller()` helper in that suite; check its name and reuse it):

```gdscript
func test_ping_aimed_at_wall_makes_world_ping() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	PingService.setup(null)
	PingService.reset()
	# Aim level, no enemy in front -> world ping (max-range point or wall).
	controller.input.local_pitch = 0.0
	await await_ticks(2)

	controller.try_ping()

	assert_int(PingService.active_count()).is_equal(1)
	assert_int(PingService.visible_pings(controller.input.get_multiplayer_authority())[0]["kind"]) \
		.is_equal(PingService.WORLD)
	PingService.reset()
```

(If `test_fps_controller.gd` does not extend `NetSuite`, it already has `await_ticks`/`_spawn_controller`; match its existing pattern. The suite currently uses `_spawn_controller()` and `await_ticks` — confirm at implementation time and mirror them.)

- [ ] **Step 4: Run the test to verify it fails**

Run:
```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/player/test_fps_controller.gd --ignoreHeadlessMode
```
Expected: FAIL — `try_ping` not defined.

- [ ] **Step 5: Implement try_ping + the input trigger**

In `scripts/player/fps_controller.gd`, add `try_ping()` (modeled on `enemy_under_reticle`, lines ~120-140):

```gdscript
func try_ping() -> void:
	var space_state := get_world_3d().direct_space_state
	var from := camera.global_position
	var max_range := MatchConfig.get_value("ping.max_range_m")
	var to := from + (-camera.global_transform.basis.z) * max_range

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0b11  # world (1) + hit zones (2)
	var excludes: Array[RID] = [get_rid()]
	for zone_area: Area3D in $HitZones.get_children():
		excludes.append(zone_area.get_rid())
	query.exclude = excludes
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		PingService.request_ping(PingService.WORLD, to, 0)
		return
	var collider: Object = result.collider
	if collider is Area3D and collider.has_meta("player"):
		var enemy: FPSController = collider.get_meta("player")
		if enemy != self:
			PingService.request_ping(PingService.ENEMY, Vector3.ZERO,
				enemy.input.get_multiplayer_authority())
			return
	PingService.request_ping(PingService.WORLD, result.position, 0)
```

Then add the input trigger. In `_unhandled_input(event)`, after the existing authority guard, add:

```gdscript
	if input.is_multiplayer_authority() and event.is_action_pressed("ping"):
		try_ping()
```

(If `FPSController` has no `_unhandled_input`, add one that early-returns when `not input.is_multiplayer_authority()`, mirroring `PlayerInput._unhandled_input`. Ping detection stays out of `_rollback_tick`.)

Also wire team resolution at runtime: in `scripts/session/match_session.gd`, immediately after `match_state.setup(self)` (line ~25), add:

```gdscript
	PingService.setup(match_state)
```

(This is runtime glue for team-scoped visibility in real matches; unit tests inject `MatchState` directly and don't depend on it.)

- [ ] **Step 6: Run the test to verify it passes**

Run:
```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/player/test_fps_controller.gd --ignoreHeadlessMode
```
Expected: PASS (all existing FPS tests + the new one).

- [ ] **Step 7: Full suite regression + commit**

Run the full suite:
```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode
```
Expected: `0 errors | 0 failures`, exit 0 (check `sysctl -n vm.loadavg` first; rerun a lone red flaky-list suite if needed).

```bash
git add project.godot scripts/config/match_config.gd scripts/player/fps_controller.gd scripts/session/match_session.gd tests/player/test_fps_controller.gd
git commit -m "$(printf 'feat: aimed ping input + try_ping raycast classify\n\nPing action (P / middle-mouse / D-pad Up), MatchConfig ping.* keys,\nFPSController.try_ping classifies enemy-tag vs world-point via the\nenemy_under_reticle raycast, triggered from _unhandled_input (outside\nrollback).\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 3: HUD ping markers

**Files:**
- Modify: `scripts/ui/player_hud.gd`
- Modify: `scenes/ui/player_hud.tscn` (a `PingLayer` Control container)
- Test: `tests/ui/test_player_hud_ping.gd` (create; light projection test)

**Interfaces:**
- Consumes: `PingService.visible_pings(peer)`, the bound local `FPSController` + its `camera`, records' `world_pos`/`kind`/`target_peer`.
- Produces: on-screen marker `Control`s under `PingLayer`; a helper `_ping_screen_target(record) -> Dictionary` returning `{ "visible": bool, "pos": Vector2, "behind": bool, "distance": float }` (the test seam).

- [ ] **Step 1: Add a PingLayer container to the HUD scene**

In `scenes/ui/player_hud.tscn`, add a `Control` node named `PingLayer` (full-rect, mouse-filter Ignore) as a child of the HUD root. It holds marker children created at runtime.

- [ ] **Step 2: Write the failing projection test**

Create `tests/ui/test_player_hud_ping.gd`:

```gdscript
class_name TestPlayerHudPing
extends GdUnitTestSuite

const HUD_SCENE := "res://scenes/ui/player_hud.tscn"
const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)
	PingService.setup(null)
	PingService.reset()


func after_test() -> void:
	PingService.reset()
	NetworkTime.stop()
	MatchConfig.reset_to_defaults()


func test_world_ping_projects_to_a_screen_target() -> void:
	var controller: FPSController = auto_free(
		(load(CONTROLLER_SCENE) as PackedScene).instantiate())
	add_child(controller)
	var hud: PlayerHud = auto_free((load(HUD_SCENE) as PackedScene).instantiate())
	add_child(hud)
	await await_millis(50)
	hud.bind(controller)

	# A point 10m straight ahead of the camera should project on-screen.
	var ahead := controller.camera.global_position \
		- controller.camera.global_transform.basis.z * 10.0
	PingService._apply_ping(controller.input.get_multiplayer_authority(),
		PingService.WORLD, ahead, 0)

	var target: Dictionary = hud._ping_screen_target(
		PingService.visible_pings(controller.input.get_multiplayer_authority())[0])
	assert_bool(target["visible"]).is_true()
	assert_bool(target["behind"]).is_false()
	assert_float(target["distance"]).is_greater(5.0)
```

- [ ] **Step 3: Run the test to verify it fails**

Run:
```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/ui/test_player_hud_ping.gd --ignoreHeadlessMode
```
Expected: FAIL — `_ping_screen_target` not defined.

- [ ] **Step 4: Implement the projection helper + per-frame marker render**

In `scripts/ui/player_hud.gd`, add the bound player field if not present (`_player: FPSController` set in `bind`), a `@onready var ping_layer := %PingLayer` (or `$PingLayer`), and:

```gdscript
func _ping_screen_target(record: Dictionary) -> Dictionary:
	var out := {"visible": false, "pos": Vector2.ZERO, "behind": true, "distance": 0.0}
	if _player == null:
		return out
	var cam := _player.camera
	var world_pos: Vector3 = record["world_pos"]
	if record["kind"] == PingService.ENEMY:
		var enemy := _find_player(record["target_peer"])
		if enemy == null or enemy.is_dead or enemy.is_wraithed:
			return out  # unrenderable this frame
		world_pos = enemy.global_position + Vector3(0.0, 1.5, 0.0)
	out["distance"] = cam.global_position.distance_to(world_pos)
	out["behind"] = cam.is_position_behind(world_pos)
	out["pos"] = cam.unproject_position(world_pos)
	out["visible"] = not out["behind"]
	return out


func _find_player(peer: int) -> FPSController:
	for node in get_tree().get_nodes_in_group("players"):
		var p := node as FPSController
		if p != null and p.input.get_multiplayer_authority() == peer:
			return p
	return null
```

Add a `_process` (or extend the existing one) that rebuilds simple marker labels each frame from `PingService.visible_pings(local_peer)` using `_ping_screen_target` — on-screen markers placed at `pos`, off-screen/behind clamped to the nearest screen edge. Keep it minimal: clear `ping_layer` children and re-add a `Label` per visible ping with the distance (e.g. `"%dm" % int(distance)`) and a `[!]`/`[x]` prefix for ENEMY/WORLD. This render path is view-only and guarded by `_player != null`.

- [ ] **Step 5: Run the test to verify it passes**

Run:
```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/ui/test_player_hud_ping.gd --ignoreHeadlessMode
```
Expected: PASS.

- [ ] **Step 6: Full suite + commit**

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode
```
Expected: `0 errors | 0 failures`, exit 0.

```bash
git add scripts/ui/player_hud.gd scenes/ui/player_hud.tscn tests/ui/test_player_hud_ping.gd
git commit -m "$(printf 'feat: HUD ping markers (world->screen projection + distance)\n\nProjects visible pings each frame; enemy-tag markers track the live\nenemy and hide on death/wraith. Projection helper unit-tested.\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

### Task 4: E2E replication + Familiar-facing verification + docs

**Files:**
- Modify: `tests/e2e/net_smoke.py`
- Modify: `docs/ABILITY_TUNING_SHEET.md`, `docs/MECHANICS_REFERENCE.md`, `docs/superpowers/plans/2026-07-17-master-implementation-plan.md`

**Interfaces:**
- Consumes: the MCP `eval` protocol already used by `net_smoke.py`; `PingService.request_ping` / `latest_enemy_tag`.
- Produces: an E2E assertion that an enemy-tag ping placed by one peer is held host-side and resolvable via `latest_enemy_tag`.

- [ ] **Step 1: Read the current E2E harness**

Open `tests/e2e/net_smoke.py`. Identify how it evals game-side code on host + client peers and how it already asserts "ability input replicated to host". Mirror that structure for the ping assertion (no new transport — reuse the `eval` command).

- [ ] **Step 2: Add the ping replication assertion**

After the existing ability-replication check, add a step that: on the client peer, evals a call that makes the client ping the host's player as an enemy (e.g. eval `get_tree().get_first_node_in_group('players')`-style lookup to find the enemy peer, then `PingService.request_ping(PingService.ENEMY, Vector3.ZERO, <enemy_peer>)`); then on the host, evals `PingService.latest_enemy_tag(<client_peer>)` and asserts it equals the tagged enemy peer. Print `enemy-tag ping replicated to host` on success. Keep the exact eval strings consistent with the file's existing helpers.

- [ ] **Step 3: Run the E2E**

Run:
```bash
pkill -f net_test.tscn; sleep 5; python3 tests/e2e/net_smoke.py
```
Expected: `E2E NET SMOKE: PASS` including the new `enemy-tag ping replicated to host` line. (Under heavy load the MCP server is slow to boot — check `sysctl -n vm.loadavg` and give it time.)

- [ ] **Step 4: Update docs**

- `docs/ABILITY_TUNING_SHEET.md`: add a "Ping (G7)" note recording the baselines — `duration_s 4.0`, `max_range_m 120.0`, `cooldown_s 0.5`, `per_player_limit 1`.
- `docs/MECHANICS_REFERENCE.md` §11: note the first concrete D-pad assignment (D-pad Up = ping/comms) and that PC ping = middle-mouse / P.
- `docs/superpowers/plans/2026-07-17-master-implementation-plan.md`: change the G7 line to ✅ DONE with the branch + gate results; note the comms wheel is a deferred G7 follow-up.
- Append an `EXECUTED` footer to this plan file.

- [ ] **Step 5: cspell + commit docs**

```bash
npx cspell "docs/**/*.md" --no-progress
git add docs/
git commit -m "$(printf 'docs: G7 ping system DONE — E2E, tuning, mechanics, master plan\n\nComms wheel deferred to a G7 follow-up.\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

- [ ] **Step 6: Merge to main**

After the full suite (`0 errors | 0 failures`, exit 0) and E2E both pass:
```bash
git checkout main
git merge --no-ff feat/ping-system -m "$(printf 'Merge feat/ping-system: G7 aimed ping (world + enemy tag)\n\nHost-authoritative team-scoped pings outside the rollback path; HUD\nmarkers; latest_enemy_tag() ready for Familiar (G5 W3). Comms wheel\ndeferred. Full suite green, E2E PASS.\n\nCo-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>')"
```

---

## Self-Review notes

- **Spec coverage:** §3.1 PingService → Task 1; §3.2 try_ping + §3.4 input + §4 tuning → Task 2; §3.3 HUD → Task 3; §6 edge cases covered by tests in Tasks 1/3 (team fallback, expiry, wraith/death skip); §7 tests → Tasks 1-4; Familiar `latest_enemy_tag` → Task 1 (built) + Task 4 (E2E-verified). Comms wheel is explicitly out of scope.
- **Type consistency:** record keys (`id, kind, owner_peer, team, world_pos, target_peer, expire_tick`) and `PingService.WORLD/ENEMY` are identical across all tasks. `request_ping(kind, world_pos, target_peer)` signature matches between `try_ping`, the E2E, and PingService.
- **Verified at plan time:** `test_fps_controller.gd` extends `NetSuite` and has `_spawn_controller()` + `await_ticks`. `player_hud.gd` has `class_name PlayerHud`, a `_player: FPSController` field, and `bind()` sets it. `MatchState`/`Economy` are created in `scripts/session/match_session.gd:25-26` via `.setup(...)` — wire `PingService.setup(match_state)` there. This wiring is runtime glue and does not affect the unit tests.

---

> **Status: EXECUTED 2026-07-20 (feat/ping-system branch).** All 4 tasks landed
> TDD. PingService unit suite 6/6; HUD projection test green; `try_ping`
> behavior test green; three-peer E2E `net_smoke.py` PASS including
> `enemy-tag ping replicated to host`. Full suite green (the lone red in one
> heavy-load run was the documented flaky `test_tangle_drags_enemy_toward_center`,
> which passes in isolation). The `ping.*` MatchConfig keys landed with Task 1
> (PingService reads them) rather than Task 2. Comms wheel deferred to a G7
> follow-up. Learned: pings deliberately live OUTSIDE the netfox rollback path —
> host-authoritative RPC (economy.gd `is_authority()` + `call_remote` pattern),
> with `NetworkTime.tick` used only as a monotonic expiry clock.
