# Ping System — Design (G7, pass 1: aimed ping)

**Status:** APPROVED 2026-07-20 · **Branch:** `feat/ping-system` ·
**Master plan item:** G7 (Milestone C; prerequisite for Familiar, G5 Wave 3)

## 1. Purpose & scope

Give players an **aimed ping**: press one button and, based on where you are
aiming, either **tag an enemy** (a marker that tracks that specific enemy) or
**mark a world point**. Pings are shared with teammates as HUD markers with a
short lifetime. The enemy-tag ping is the hunt target Familiar will consume in
G5 Wave 3.

**In scope (this pass):**
- One rebindable `ping` input action.
- Aim raycast that classifies the ping as **enemy-tag** or **world-point**.
- Host-authoritative, team-scoped replication of active pings.
- HUD markers (on-screen projection + off-screen edge arrow + distance).
- Enemy-tag markers track the live enemy; hide on Wraith/death.
- A `latest_enemy_tag(owner_peer)` query for Familiar to consume later.
- MatchConfig tuning keys; unit + behavior + HUD + E2E tests.

**Out of scope (deferred, documented):**
- The minimal **comms wheel** (canned messages / radial) — a G7 follow-up.
- Minimap / full-map ping projection.
- Ping reply / acknowledge, ping wheel voice lines.
- Multiple simultaneous pings per player (this pass: 1 per player, re-ping
  replaces).

## 2. Core principle — pings live OUTSIDE rollback

A ping is **intel/comms, not simulated gameplay physics**. It must NOT go
through the netfox rollback path:

- No press-tick input plumbing in `PlayerInput`, no `input_properties`.
- No `RollbackSynchronizer` state, no `_rollback_tick`, no `NetworkRollback.mutate`.
- Networking is **host-authoritative RPC**, mirroring the existing
  `scripts/match/match_state.gd` and `scripts/match/economy.gd` patterns — NOT
  tick simulation.

This keeps pings deterministic-independent (they never affect the rewindable
simulation) and avoids the corpse/field rollback machinery entirely. Expiry uses
`NetworkTime.tick` purely as a **monotonic counter** (not rollback state), which
also honors the project's "no wall-clock in gameplay-adjacent code" convention.

## 3. Components (units)

### 3.1 `PingService` — `scripts/abilities/ping_service.gd` (autoload)

Registered as an autoload (like `MatchConfig`, `SessionManager`). Match-global
store of active pings; reset per match.

**Ping record** (plain Dictionary or small `RefCounted`):

| field         | type    | meaning                                              |
|---------------|---------|------------------------------------------------------|
| `id`          | int     | host-assigned unique id                              |
| `kind`        | int     | `PingService.WORLD` or `PingService.ENEMY`           |
| `owner_peer`  | int     | peer who placed it                                   |
| `team`        | int     | owner's team (`-1` = no team → self-only visibility) |
| `world_pos`   | Vector3 | WORLD: the marked point (unused for ENEMY)           |
| `target_peer` | int     | ENEMY: the tagged enemy's peer (0 for WORLD)         |
| `expire_tick` | int     | `NetworkTime.tick` at which the record is culled     |

**Public API:**
- `request_ping(kind, world_pos, target_peer)` — `@rpc("any_peer")`, runs on the
  host. Validates the sender, applies cooldown + per-player limit (removes the
  sender's previous ping), assigns `id`/`team`/`expire_tick`, stores it, then
  calls `add_ping` on every teammate (including the owner) via
  `@rpc(...).rpc_id(peer, record_fields…)`. RPC args are **flat primitives**
  (same serialization discipline as the spawner) — no nested Dictionaries over
  the wire; pass the fields positionally and rebuild the record on the receiver.
- `add_ping(...)` — `@rpc("authority")`, runs on clients; inserts/replaces the
  record locally.
- `remove_ping(id)` — `@rpc("authority")`; host tells clients to drop a culled
  or replaced ping.
- `visible_pings(viewer_peer) -> Array` — records the viewer may see (own team,
  or own pings when team `-1`). Used by the HUD.
- `latest_enemy_tag(owner_peer) -> int` — the `target_peer` of `owner_peer`'s
  active ENEMY ping, or `0`. **Familiar's hook (G5 W3).**
- `reset()` — clears all records; called on match start.

**Offline / single-player / server dispatch:** reuse the exact pattern in
`economy.gd`/`match_state.gd`. A private `_is_server()` returns true when
`multiplayer.multiplayer_peer == null`, is an `OfflineMultiplayerPeer`, or
`multiplayer.is_server()`. RPCs are declared `@rpc("any_peer", "call_remote",
"reliable")` (host request) and `@rpc("authority", "call_remote", "reliable")`
(client apply); the caller runs the local effect directly in the server/offline
branch and only `rpc`s to remote peers when a real peer is connected. This means
`request_ping` in single-player/headless executes the host logic in-process with
no live RPC — the tests and prototype work unchanged.

**Local upkeep** (`_process`): cull records whose `expire_tick <= NetworkTime.tick`;
on the host, culling a record also broadcasts `remove_ping`. Enemy-tag records
whose `target_peer` is dead or wraithed are treated as **not renderable** by the
HUD (the record can persist until expiry; visibility is a render-time check so
the tag reappears if the enemy un-wraiths within the lifetime).

**Team lookup:** the host resolves `team` by finding `MatchState` in the tree
(group/`_try_autobind` pattern the HUD already uses). If absent (e.g. a bare
controller-scene test), `team = -1`.

**Single-player / loopback:** with one peer, host == client, so RPCs are
loopback — the same code path works; nothing special-cased.

### 3.2 `FPSController.try_ping()` — `scripts/player/fps_controller.gd`

- Triggered from `_unhandled_input` on the **local authority only** (edge is
  natural from the input event; stays outside `_rollback_tick`).
- Raycast from the camera using the same query shape as `enemy_under_reticle()`
  (mask `world | hit zones`, exclude self + own hit zones), out to
  `ping.max_range_m`.
- Classify:
  - Ray hits an `Area3D` with a `"player"` meta that isn't self → **ENEMY**,
    `target_peer = that player's input authority`.
  - Any other hit → **WORLD**, `world_pos = hit point`.
  - No hit → **WORLD**, `world_pos = ray end` (max-range point).
- Enforce the local cooldown as a quick guard (authoritative cooldown still on
  host), then `PingService.request_ping(kind, world_pos, target_peer)` — which
  internally applies the host logic directly when server/offline, or `rpc`s to
  the host when a client (see §3.1 server-dispatch).
- Guard `DisplayServer.get_name() == "headless"` only where it would touch mouse
  capture — ping itself must work headless (tests + dedicated host).

### 3.3 HUD ping markers — `scripts/ui/player_hud.gd` (+ scene nodes)

- Each frame, for `PingService.visible_pings(local_peer)`:
  - Resolve the world position: WORLD → `world_pos`; ENEMY → the tracked player's
    position (skip render if dead/wraithed/not found).
  - Project world→screen via the active `Camera3D`
    (`unproject_position` + `is_position_behind`).
  - On-screen → place a marker (icon differs WORLD vs ENEMY) with a distance
    label. Off-screen/behind → clamp to a screen-edge arrow pointing toward it.
- Markers are pooled/simple `Control` nodes under a `PingLayer`. No per-ping
  scene spawns in the world (HUD-space only for this pass).

### 3.4 Input action — `project.godot`

New rebindable `ping` action:
- PC: middle mouse button + `T`.
- Controller: D-pad Up (comms; the §11 layout reserves the D-pad for
  abilities — ping/comms is the first concrete D-pad assignment; noted for the
  MECHANICS_REFERENCE §11 update).

## 4. Tuning (MatchConfig `DEFAULTS`)

| key                    | baseline | meaning                                  |
|------------------------|----------|------------------------------------------|
| `ping.duration_s`      | 4.0      | lifetime of a ping                       |
| `ping.max_range_m`     | 120.0    | aim raycast length                       |
| `ping.cooldown_s`      | 0.5      | min interval between a player's pings     |
| `ping.per_player_limit`| 1        | active pings per player (re-ping replaces)|

Baselines recorded in `docs/ABILITY_TUNING_SHEET.md`.

## 5. Data flow (happy path)

1. Local authority presses `ping` → `_unhandled_input` → `try_ping()`.
2. Raycast classifies ENEMY vs WORLD; local cooldown guard passes.
3. `request_ping(…)` runs host logic in-process (server/offline) or `rpc`s to
   the host (client) — see §3.1.
4. Host validates, applies cooldown + per-player limit (drops sender's prior
   ping via `remove_ping`), assigns `id`/`team`/`expire_tick`, stores it.
5. Host `add_ping` → each teammate (incl. owner).
6. Clients store the record; HUD renders it each frame.
7. `_process` culls on expiry; host broadcasts `remove_ping`.
8. Later (G5 W3): Familiar calls `PingService.latest_enemy_tag(caster_peer)`.

## 6. Error / edge handling

- **No MatchState / no teams:** `team = -1`, visibility falls back to owner-only.
- **Tagged enemy leaves / dies / wraiths:** record persists to expiry;
  HUD skips rendering while unrenderable; re-appears if the enemy un-wraiths in
  time.
- **Spam:** host-side cooldown is authoritative; per-player limit caps clutter.
- **Headless:** no camera projection consumers in headless tests; `PingService`
  logic and `try_ping` classification are tested without the HUD.
- **Invalid RPC args:** host ignores requests from unknown peers / malformed
  kinds (Layer-1 anti-cheat: server validates, never trusts the client's team).

## 7. Testing

- **Unit — `tests/abilities/test_ping_service.gd`:** request creates a record;
  ENEMY vs WORLD stored correctly; team filtering (`visible_pings` shows
  teammate's, hides enemy's); expiry culls at `expire_tick`; re-ping replaces the
  owner's prior ping (limit=1); `latest_enemy_tag` returns the tagged peer then
  `0` after expiry; `team=-1` fallback is owner-only. Drives `PingService`
  directly (host-side), no rollback.
- **Behavior — `tests/player/test_fps_controller.gd` (or a new ping test):**
  SceneRunner in the arena with a second body; `try_ping()` aimed at the enemy
  yields an ENEMY record with the right `target_peer`; aimed at a wall yields a
  WORLD record. Must tolerate headless (no HUD).
- **HUD — light test:** given one active ping and a camera, the HUD produces a
  marker Control at the projected position (or an edge arrow when behind).
- **E2E — extend `tests/e2e/net_smoke.py`:** peer A pings peer B (enemy); assert
  the host holds an ENEMY record with B's peer and that A's `latest_enemy_tag`
  resolves to B (replication + query verified across peers).

**Gates:** headless suite `0 errors | 0 failures` exit 0 after every task;
three-peer E2E PASS; cspell clean; then `--no-ff` merge to main and tick the
master-plan G7 line.

## 8. Build order (for the implementation plan)

1. `PingService` autoload + records + RPC + queries + `reset` (unit tests first).
2. MatchConfig keys + input action + `FPSController.try_ping` raycast/classify
   (behavior test).
3. HUD markers (projection + edge arrow + distance).
4. Familiar-facing `latest_enemy_tag` verified; E2E extension; docs
   (MECHANICS_REFERENCE §11 D-pad note, tuning sheet, master-plan G7 ✅).
