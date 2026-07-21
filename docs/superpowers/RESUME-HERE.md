# Resume Here — CounterSpell Implementation Progress

**Last updated:** 2026-07-20 (G6 + G7 merged to main; queue advanced to G5 Wave 3)
**Goal being executed:** Implement the entire master plan
(`docs/superpowers/plans/2026-07-17-master-implementation-plan.md`) — every
subsystem plan, all tests passing. Milestones advance on quality gates.

---

## TL;DR for the next agent

1. **You are on `main`.** Both **G6 (corpse system)** and **G7 (ping system)**
   are **merged** (`main` head is the `Merge feat/ping-system` commit + a
   follow-up fix `8c881d9`). Git tree is clean. **Full suite 125/125, exit 0;
   three-peer E2E `net_smoke` PASS (incl. enemy-tag ping replication).**
2. **G7 shipped (pass 1 — aimed ping):** `PingService` autoload
   (`scripts/abilities/ping_service.gd`) — host-authoritative, team-scoped ping
   store **outside** the netfox rollback path (economy.gd `is_authority()` +
   `call_remote` RPC pattern; `NetworkTime.tick` used only as a monotonic expiry
   clock). `FPSController.try_ping` raycasts (reusing `enemy_under_reticle`) and
   classifies enemy-tag vs world-point; HUD markers project world→screen
   (`player_hud._render_pings`). **`PingService.latest_enemy_tag(peer)` is the
   hook Familiar (G5 W3) consumes.** Input: P / middle-mouse / D-pad Up.
   **Comms wheel is a deferred G7 follow-up** (not built).
3. **Watch the commit hygiene lesson from this session:** a `git add a b c
   missing.uid 2>/dev/null` aborted and staged nothing, so a HUD impl commit
   captured only its test file — `main` briefly lacked the implementation until
   fix `8c881d9`. Verify `git show --stat <commit>` after committing.
4. **Machine-load caveat still applies:** timing-sensitive tests can flake and
   the full suite can abort mid-run under extreme sustained CPU load. Check
   `sysctl -n vm.loadavg` before trusting a red result and rerun when low.
   (`test_tangle_drags_enemy_toward_center` flaked in one heavy-load full run
   this session; passed in isolation and in the clean 125/125 run.)
5. **First action on resume: start G5 Wave 3.** Per the master plan: **Reclaim**
   (needs G6 corpses ✅), **Familiar** (needs G7 ping ✅ — consume
   `PingService.latest_enemy_tag`), **Pulse Sight**, **Smart Rig** (forced view
   tracking), **Overclock Rig** (grace-period HP drain). Framework rules in
   MECHANICS_REFERENCE §4.A. Brainstorm → plan → branch `feat/abilities-wave3`
   (or split per ability) → TDD. Then G8 (CTF), G9 (maps), G10 (host-migration
   SPIKE), G11 (anti-cheat audit).

---

## How to run things (macOS, Godot 4.7.1)

```bash
cd /Users/cyotee/Development/github-cyotee/game-running-in-shadows

# Full headless test suite (the gate — expect "0 errors | 0 failures", exit 0)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import --quit   # warm cache on fresh checkout
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode

# Two/three-instance netcode E2E (run ONCE from a clean state; kill stragglers first)
pkill -f net_test.tscn; sleep 5; python3 tests/e2e/net_smoke.py    # expect "E2E NET SMOKE: PASS"

# Live driving of the running game (arena is NOT the main scene — launch it directly):
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/levels/test_arena.tscn --quit-after 9000 &
#   then connect to the MCP TCP server on 127.0.0.1:9090 (JSON lines: {"id","command":"eval","params":{"code":...}})
#   NOTE: under heavy load the MCP server takes >7s to come up; sleep longer before connecting.
```

**Run reports** land in `reports/report_N/results.xml`. To list failures:
```bash
LATEST=$(ls reports | sort -t_ -k2 -n | tail -1); python3 -c "
import re; xml=open('reports/$LATEST/results.xml').read()
for m in re.finditer(r'<testcase name=\"([^\"]+)\"[^>]*>(.*?)</testcase>',xml,re.S):
    n,b=m.groups()
    if '<failure' in b: print('FAIL',n)"
```

## Known load-flaky tests (pass in isolation / at low load — NOT real bugs)
- `test_moves_forward_on_input`, `test_gathers_movement_and_sprint`,
  `test_crouch_slows_movement` — use real `Input.action_press` (movement is a
  level input, not a press-tick, so it can't use the deterministic injection).
- `test_ads_zoom_applies_to_camera`, `test_blade_switches_to_third_person_camera`
  — assert on `_process` view logic (FOV lerp / camera swap), frame-driven.
- `test_tangle_drags_enemy_toward_center` — occasionally flakes under extreme load.
If one of these is the ONLY failure, rerun that suite alone to confirm before
worrying.

> **Not flaky (resolved):** `test_drag_moves_corpse_toward_dragger` was flagged
> as suspected-flaky but turned out to be a deterministic **test-isolation
> leak** — leaked loot-test corpses in the global `corpses` group skewed
> `_nearest_corpse`. Fixed in `after_test` (commit `3393474`). It now passes
> reliably. Lesson: a test that spawns a persistent grouped node beside the
> scene must free that group in `after_test`.

---

## What is DONE and merged to `main`

`main` head: the `Merge feat/ping-system` commit (+ fix `8c881d9`). Full suite
**125/125** green on main. Completed & merged, in order:

- **Milestone A** (predicted core): netfox integration, native controller
  support, Resonance system, weapon system (5 guns), Combat Blade / melee.
- **Milestone B** (networked loop): Steam lobbies & sessions (GodotSteam
  4.20.1, `SessionManager`, lobby browser, 16-player match session,
  join-in-progress spectators — **live two-machine Steam verification still
  pending the owner**); match flow & Arena/TDM + crouch (G1+G2); economy &
  loadouts (G3); core HUD (G4). CI workflow (G0) at `.github/workflows/tests.yml`.
- **Milestone C so far:** G5 Wave 1 (Slip, Wraith, Grenades), G5 Wave 2
  (Lifebloom, Tangle, Null Charge), **G6 Corpse system** (persistence, per-owner
  limit, inventory/looting, dragging), **G7 Ping system** (aimed ping: world
  point + enemy tag; team-scoped HUD markers; `latest_enemy_tag` for Familiar —
  comms wheel deferred).

Each plan lives in `docs/superpowers/plans/` with a `Status: EXECUTED` footer.
The master plan's queue tables and Gap Backlog are marked ✅ per item.

## What is code-complete but NOT merged

- *(nothing — G7 merged 2026-07-20. Next work starts fresh on `feat/abilities-wave3`.)*

## What remains in the queue (Milestone C, then D)

Order per the master plan §Milestone C / Gap Backlog:
1. **G5 Wave 3** — Reclaim (needs G6 corpses ✅), Familiar (needs G7 ping ✅ —
   consume `PingService.latest_enemy_tag`), Pulse Sight, Smart Rig (forced view
   tracking), Overclock Rig (grace-period HP drain). Write one plan per wave-ish;
   framework rules in MECHANICS_REFERENCE §4.A. *Next up.*
2. **G8 — CTF + variable objective item** (on the G2 match framework).
3. **G9 — two polished maps** (greybox then art; placeholder Quaternius CC0).
4. **G10 — True host migration** — SPIKE FIRST (`docs/superpowers/plans/SPIKE-host-migration.md`).
5. **G11 — Anti-cheat Layer-1 audit** (dedicated pass; input-trace logging).
Then **Milestone D** (Steam achievements/cloud/rich-presence G12, EAC/EOS G13 +
release-build stripping of `McpInteractionServer`/ENet dev path, store page).

---

## Hard-won conventions (also in CLAUDE.md — read it, it's the source of truth)

- **Tick-based only:** no wall-clock, no `is_action_just_pressed` in simulation.
  Durations are tick counts. All per-tick state registered in
  `RollbackSynchronizer.state_properties` in `fps_controller.tscn`.
- **Edge inputs are press-tick ints** (`<action>_press_tick`), never latched
  bools — netfox reuses the last gathered input across a catch-up batch, so a
  bool press multi-fires. Level inputs (movement, `*_held`) stay bools.
- **Out-of-band writes to rollback state are discarded** by the state restore.
  In tests: apply damage via `queue_damage()` (in-tick), switch weapons via
  `select_slot()`, NOT by writing `health`/`active_slot` directly mid-test.
  (Writes made synchronously right after spawn, before the first tick, DO stick.)
- **Spawned rollback entities** (grenade, placed fields, corpse) get their own
  `RollbackSynchronizer`, spawn through `scripts/weapons/projectile_spawner.gd`
  (custom spawn-data must be **flat primitives** — `MultiplayerSpawner.spawn()`
  serializes it), and **free themselves in `_process`** once terminal (never
  during the rollback tick).
- **All gameplay numbers via `MatchConfig`** (`scripts/config/match_config.gd`);
  no constants in code. Baselines recorded in `docs/ABILITY_TUNING_SHEET.md`.
- **Test injection:** `tests/helpers/net_suite.gd` `NetSuite` base — `await_ticks(n)`
  (not frames), `press(input, &"action")`, `select_slot(input, n)`. Suites that
  drive simulation extend `NetSuite`.
- **Abilities are currently always-castable** (no ownership gating) matching the
  Repulse/Glide prototype precedent; a unified ability-ownership/buy pass is
  deliberately deferred until it can cover all Manifestations uniformly.
- **IP:** original terms only (Resonance, Runners, Grid, Manifestations,
  Augments, Repulse, Glide) — never Shadowrun trademarks.
- Commits end with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
  (earlier commits used `Claude Fable 5`; either is fine).

## Working style that has worked here
Branch per plan (`feat/<plan>`), TDD task-by-task, headless suite green after
every task, commit per task, then a docs pass + `npx cspell` + E2E, then
`--no-ff` merge to main and tick the master-plan queue. Use the `TaskCreate`/
`TaskUpdate` tools to track the per-plan task list.
