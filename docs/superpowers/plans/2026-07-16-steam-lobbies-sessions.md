# Steam Lobbies & Sessions (Milestone B, Part 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Steam-backed multiplayer sessions: GodotSteam 4.20 upgrade, lobby create/invite/browse/join (friends + public browser), SteamMultiplayerPeer wiring under netfox, 16-player spawning, and join-in-progress (spectate → enter at next tick of match flow). True host migration is a SEPARATE follow-up plan gated on a spike (see final task).

**Architecture:** A `SessionManager` autoload owns the session lifecycle (lobby ↔ peer ↔ scene) as a small state machine, wrapping GodotSteam lobby calls and handing the resulting `SteamMultiplayerPeer` to `multiplayer.multiplayer_peer` — netfox sits on top unchanged (NetworkEvents auto-starts NetworkTime when a peer appears). The ENet/NetworkSimulator dev path stays for headless E2E; Steam paths get logic-level GdUnit tests (session state machine with injected fake Steam responses) plus manual two-machine verification, since the Steam client cannot run in CI.

**Tech Stack:** Godot 4.7.1, GodotSteam **4.20** GDExtension (upgrade from 4.19.1), netfox v1.35.3, GdUnit4.

**PREREQUISITES (in order):** netfox plan → Resonance plan → weapons plan → melee plan. (Mechanics don't strictly block sessions, but this order keeps one integration frontier at a time.)

## Global Constraints

- Test command (after every task): `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode` → exit 0.
- Steam-dependent behavior must degrade gracefully headless (no Steam client): `SessionManager` reports capability via `steam_available: bool` and every Steam call is guarded — CI must stay green with no Steam running.
- Decided design (PRD §5/§7 v0.6, do not re-litigate): friends + invites + public browser; join-in-progress = spectate → buy in at next round; 16-player cap via MatchConfig; GodotSteam built-in MultiplayerPeer (expressobits fallback only if it fails in practice).
- All tunables via MatchConfig (`session.max_players: 16.0` added in Task 2).
- UI is functional/debug-grade (Godot Control nodes, default theme) — visual design is a later pass.
- GDScript typed, tabs; `.scratch/` for temp files; commits end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## File Structure

- `addons/godotsteam/` — REPLACE with 4.20 release (Task 1)
- `scripts/config/match_config.gd` — MODIFY: session keys (Task 2)
- `scripts/session/session_manager.gd` — NEW autoload: lobby/session state machine (Task 2)
- `scripts/session/steam_lobby.gd` — NEW: thin GodotSteam lobby wrapper, injectable for tests (Task 2)
- `scenes/ui/main_menu.tscn` + `scripts/ui/main_menu.gd` — REWORK: Host / Browse / Friends-invite / Quit (Task 4)
- `scenes/ui/lobby_browser.tscn` + `scripts/ui/lobby_browser.gd` — NEW (Task 4)
- `scenes/session/match_session.tscn` + `scripts/session/match_session.gd` — NEW: networked match scene (spawner, 16 spawn points, spectator flow) (Tasks 3, 5)
- Tests: `tests/session/test_session_manager.gd`, `tests/session/test_match_session.gd`
- Docs final task.

---

### Task 1: GodotSteam 4.20 upgrade

**Files:** Replace `addons/godotsteam/`; `project.godot` untouched (autoload + `[steam]` section carry over).

- [ ] **Step 1:** Download the GodotSteam 4.20 GDExtension release zip into `.scratch/godotsteam-420/` (from https://github.com/GodotSteam/GodotSteam/releases — asset name pattern `godotsteam-gdextension-4.20*.zip`; verify exact name via `gh api repos/GodotSteam/GodotSteam/releases/latest --jq '.assets[].name'`).
- [ ] **Step 2:** `git rm -r addons/godotsteam && cp -R .scratch/godotsteam-420/addons/godotsteam addons/` (keep our `steam_appid.txt` untouched at root). Diff the new `godotsteam.gdextension` for macOS binary paths.
- [ ] **Step 3:** Reimport + boot check: `--headless --import --quit`, then `--quit-after 30`, expect the SteamManager init warning (no client headless) and **no** GDExtension load errors. With the Steam client running locally, run once non-headless and confirm `✅ Steam initialized` plus `print(ClassDB.class_exists("SteamMultiplayerPeer"))` → true (via MCP eval).
- [ ] **Step 4:** Full GdUnit suite green. Commit `chore: upgrade GodotSteam to 4.20 (built-in SteamMultiplayerPeer)`.

---

### Task 2: SessionManager state machine + injectable Steam lobby wrapper

**Files:**
- Create: `scripts/session/session_manager.gd` (autoload `SessionManager`, registered in `project.godot` after `MatchConfig`), `scripts/session/steam_lobby.gd`
- Modify: `scripts/config/match_config.gd` (`"session.max_players": 16.0`)
- Test: `tests/session/test_session_manager.gd`

**Interfaces:**
- `class_name SteamLobbyService extends RefCounted` (`steam_lobby.gd`): wraps GodotSteam calls behind an interface the tests can fake: `is_available() -> bool` (Steam initialized), `create_lobby(visibility: int, max_members: int)`, `join_lobby(lobby_id: int)`, `leave_lobby()`, `request_list(filters: Dictionary)`, `open_invite_overlay()`, `set_lobby_data(key, value)`, `get_lobby_data(lobby_id, key)`; signals `lobby_created(lobby_id: int)`, `lobby_joined(lobby_id: int)`, `lobby_list(entries: Array[Dictionary])`, `lobby_join_failed(reason: String)`. Visibility constants `VIS_FRIENDS`, `VIS_PUBLIC`.
- `SessionManager` (autoload): states `IDLE / HOSTING_LOBBY / IN_LOBBY / CONNECTING / IN_MATCH`; API `host(visibility: int) -> void`, `join(lobby_id: int) -> void`, `browse(filters := {}) -> void`, `leave() -> void`; signals `state_changed(state: int)`, `lobby_list_ready(entries: Array)`, `session_error(message: String)`. On successful lobby: host creates `SteamMultiplayerPeer` as host, joiners as client (Steam ID from lobby owner), assigns `multiplayer.multiplayer_peer`, transitions to `IN_MATCH`, and loads `match_session.tscn`. `var lobby_service: SteamLobbyService` is assignable (tests inject a fake). Lobby data keys: `game` = `"counterspell"`, `version` = project version, `mode`, `player_count` — browser filters on `game` + `version` (App ID 480 is shared with other test projects; filtering is mandatory).

- [ ] **Step 1: Failing tests** (`tests/session/test_session_manager.gd`) using a `FakeLobbyService` inner class extending `SteamLobbyService` that records calls and emits signals on demand:

```gdscript
class_name TestSessionManager
extends GdUnitTestSuite


class FakeLobbyService:
	extends SteamLobbyService
	var created := false
	var joined_id := 0

	func is_available() -> bool:
		return true

	func create_lobby(_visibility: int, _max_members: int) -> void:
		created = true

	func join_lobby(lobby_id: int) -> void:
		joined_id = lobby_id


var fake: FakeLobbyService


func before_test() -> void:
	fake = FakeLobbyService.new()
	SessionManager.lobby_service = fake
	SessionManager._reset_for_tests()


func test_host_requests_lobby_then_becomes_host_on_created() -> void:
	SessionManager.host(SteamLobbyService.VIS_PUBLIC)
	assert_bool(fake.created).is_true()
	assert_int(SessionManager.state).is_equal(SessionManager.HOSTING_LOBBY)

	fake.lobby_created.emit(123456)
	assert_int(SessionManager.state).is_equal(SessionManager.IN_LOBBY)
	assert_int(SessionManager.current_lobby_id).is_equal(123456)


func test_join_flow_reaches_connecting() -> void:
	SessionManager.join(999)
	assert_int(fake.joined_id).is_equal(999)
	fake.lobby_joined.emit(999)
	assert_int(SessionManager.state).is_equal(SessionManager.CONNECTING)


func test_join_failure_returns_to_idle_with_error() -> void:
	var errors: Array = []
	SessionManager.session_error.connect(func(m): errors.append(m))
	SessionManager.join(999)
	fake.lobby_join_failed.emit("full")
	assert_int(SessionManager.state).is_equal(SessionManager.IDLE)
	assert_array(errors).has_size(1)
```

(The peer-creation step is factored into an overridable `_start_networking(as_host: bool)` that the fake path skips when `OS.has_feature("editor")` tests set `SessionManager.skip_peer_for_tests = true` in `_reset_for_tests()`.)

- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement both scripts per the interfaces (state machine with guarded transitions; every Steam call routed through `lobby_service`; real `SteamLobbyService` implementation calls `Steam.createLobby`, `Steam.joinLobby`, `Steam.requestLobbyList` + `Steam.addRequestLobbyListStringFilter` for `game`/`version`, `Steam.activateGameOverlayInviteDialog`, wiring GodotSteam signals `lobby_created`, `lobby_joined`, `lobby_match_list`). Register autoload. Add MatchConfig key.
- [ ] **Step 4:** Suite green (headless: real service reports `is_available() == false`, manager surfaces `session_error("Steam unavailable")` — covered by one more small test). **Step 5:** Commit `feat: session manager with injectable Steam lobby service`.

---

### Task 3: Match session scene — networked spawning for 16 players

**Files:**
- Create: `scenes/session/match_session.tscn`, `scripts/session/match_session.gd`
- Test: `tests/session/test_match_session.gd`

**Interfaces:**
- `match_session.tscn`: arena geometry (reuse test_arena's floor/walls via inheritance or duplication), `Players` node + `MultiplayerSpawner` (same pattern as `net_test.gd` from the netfox plan), 16 `Marker3D` spawn points under `SpawnPoints`, and a `SpectatorCamera` (Camera3D on a slow orbit, `current = false`).
- `match_session.gd`: on host — spawns a player per connected peer at `SpawnPoints.get_child(peer_index % 16)`; respects `MatchConfig.get_value("session.max_players")` by rejecting excess peers (host disconnects them with a reason via RPC before spawn); `_spawn_player(peer_id)` sets Input authority exactly as `net_test.gd` does. Exposes `is_spectator(peer_id) -> bool` — true when the peer connected after match start (rollback: for THIS plan, spectators spawn no body and watch `SpectatorCamera`; the buy-in-at-round-boundary handoff completes in the round-flow/economy plan, which owns rounds — see Interfaces note below).
- **Interface note for the round-flow plan:** `match_session.gd` emits `late_joiner_waiting(peer_id: int)` and provides `promote_spectator(peer_id: int) -> void` (spawns their body at the next free spawn point). The round-flow plan calls `promote_spectator` at round boundaries. Until then, a debug key on the host (registered `dev_promote` action, physical F9) promotes all waiting spectators — making the flow fully testable now.

- [ ] **Step 1: Failing tests:** scene loads headless; `SpawnPoints` has 16 children; with no multiplayer peer, `_ready` spawns exactly one local player (offline single-player path keeps working); `is_spectator` false for peer 1; after `late_joiner_waiting` + `promote_spectator(x)`, a player node named `str(x)` exists.

```gdscript
class_name TestMatchSession
extends GdUnitTestSuite


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()


func test_offline_boot_spawns_single_local_player() -> void:
	var runner := scene_runner("res://scenes/session/match_session.tscn")
	await runner.simulate_frames(5)
	var session: Node = runner.scene()

	assert_int(session.get_node("SpawnPoints").get_child_count()).is_equal(16)
	assert_int(session.get_node("Players").get_child_count()).is_equal(2)  # spawner + player 1
	assert_bool(session.is_spectator(1)).is_false()


func test_promote_spectator_spawns_body() -> void:
	var runner := scene_runner("res://scenes/session/match_session.tscn")
	await runner.simulate_frames(5)
	var session: Node = runner.scene()

	session._register_late_joiner(42)
	assert_bool(session.is_spectator(42)).is_true()
	session.promote_spectator(42)
	await runner.simulate_frames(2)

	assert_object(session.get_node_or_null("Players/42")).is_not_null()
	assert_bool(session.is_spectator(42)).is_false()
```

- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement scene + script (spawn/spectator bookkeeping in a `_spectators: Dictionary` set; offline path: no peer or OfflineMultiplayerPeer → `NetworkTime.start()` + spawn local player 1, mirroring `test_arena.gd`).
- [ ] **Step 4:** Suite green. **Step 5:** Commit `feat: 16-player match session with spectator bookkeeping`.

---

### Task 4: Menu + lobby browser UI

**Files:**
- Create: `scenes/ui/lobby_browser.tscn` + `scripts/ui/lobby_browser.gd`
- Rework: `scenes/main_menu.tscn` (move to `scenes/ui/`, update `project.godot` main scene decision: main scene becomes the menu; test arena stays reachable via a Dev button and `--scene` flag)
- Test: additions to `tests/session/test_session_manager.gd` (browser view-model only)

**Interfaces:**
- Main menu buttons: `Host (Friends)` → `SessionManager.host(VIS_FRIENDS)`; `Host (Public)` → `host(VIS_PUBLIC)`; `Browse` → opens lobby browser; `Invite Friends` (enabled only `IN_LOBBY+`) → `lobby_service.open_invite_overlay()`; `Test Arena (dev)`; `Quit`. Steam-unavailable → Host/Browse disabled with a status label (offline dev still reaches the arena).
- Lobby browser: calls `SessionManager.browse()`, renders `lobby_list_ready` entries (name, players `n/16`, mode) in an `ItemList`, double-click/Join button → `SessionManager.join(id)`. Refresh button. Entries filtered upstream by `game`/`version` lobby data (Task 2).
- Accepting a Steam invite / join-request: `SteamLobbyService` handles GodotSteam's `join_requested` signal → `SessionManager.join(lobby_id)` — works from overlay regardless of current screen.

- [ ] **Step 1:** Failing test: a `LobbyBrowserModel` (plain RefCounted in `lobby_browser.gd`) formats raw entries: `{id, name, count, max, mode}` → display string `"Rooftop Run — arena — 3/16"`; malformed entries skipped.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement model + UI scenes; set `run/main_scene` to the menu.
- [ ] **Step 4:** Suite green; headless boot check shows the menu scene loading without errors. **Step 5:** Commit `feat: main menu and public lobby browser`.

---

### Task 5: Live verification (manual, Steam required) + E2E guard

- [ ] **Step 1 (manual, needs Steam client + a second machine or account):** Run non-headless: Host (Public) → lobby appears; second machine: Browse → lobby visible with correct `n/16` → Join → both load `match_session`, two bodies, movement replicates, Repulse+Glide combo works over Steam relay. Then: third account joins mid-session → spectator camera → host presses F9 → body spawns. Record results (latency feel, any drops) in `docs/ABILITY_TUNING_SHEET.md` misc notes.
- [ ] **Step 2 (automated guard):** the ENet E2E (`tests/e2e/net_smoke.py`) still passes — sessions must not have broken the dev transport. Add a 16-player headless spawn smoke: extend `net_smoke.py` with a third instance joining and asserting three player nodes on the host.
- [ ] **Step 3:** Full suite green. Commit `feat: verified Steam session flow; extended E2E to three peers`.

---

### Task 6: Docs + host-migration spike scheduling

- [ ] `docs/TESTING.md`: Steam-dependent testing policy (logic via injected fakes in CI; live flows manual with Steam running; ENet E2E as the automated transport guard).
- [ ] `CLAUDE.md`: SessionManager owns all lobby/peer lifecycle — gameplay code never touches `multiplayer.multiplayer_peer` directly; Steam calls only via `SteamLobbyService`.
- [ ] `docs/PRD.md`: Milestone B progress notes.
- [ ] **Create `docs/superpowers/plans/SPIKE-host-migration.md`** — a spike brief (not an implementation plan): questions to answer — (1) can a surviving peer re-host with netfox state continuity (NetworkTime restart semantics, RollbackSynchronizer re-`process_settings` after authority swap, state re-seed from last received snapshot)? (2) Steam lobby owner change → new SteamMultiplayerPeer host + all peers reconnect: timing and failure modes? (3) resume mid-round vs restart-round-preserving-economy? Deliverable: findings + the real implementation plan. Timebox: 2 sessions.
- [ ] cspell pass; full suite green; commit `docs: session architecture notes and host-migration spike brief`.

---

## Known risks & notes (for the executor)

- **GodotSteam 4.20 asset names/paths may differ** from 4.19.1's layout — verify `godotsteam.gdextension` library paths before overwriting; keep the old addon in `.scratch/godotsteam-419-backup/` until boot check passes.
- **App ID 480 lobby pollution:** the public browser WILL show other developers' Spacewar lobbies unless the `game`/`version` string filters work — they are mandatory, not optional (Task 2).
- **SteamMultiplayerPeer + netfox is unproven in this codebase** until Task 5 Step 1. If replication misbehaves over Steam messages (channel/ordering semantics), the documented fallback is expressobits/steam-multiplayer-peer (Steam Sockets, ENet-like semantics) — swap inside `SessionManager._start_networking` only; nothing else changes.
- **16 players is a cap, not a promise:** host upload at 60 tps with our state footprint is unmeasured. If Task 5 playtests stutter, the tuning order is: reduce non-authority full-state broadcast (`enable_input_broadcast = false`), lower tickrate for state sync, then lower the cap — record findings in the tuning sheet.
- **Spectator promotion is intentionally half-finished here** — the round-flow/economy plan owns round boundaries and will replace the F9 debug promotion with `promote_spectator` at round end. The signal/method interface is the contract.
