# Resume Here — CounterSpell Implementation Progress

**Last updated:** 2026-07-20 (G6 merged to main; queue advanced to G7)
**Goal being executed:** Implement the entire master plan
(`docs/superpowers/plans/2026-07-17-master-implementation-plan.md`) — every
subsystem plan, all tests passing. Milestones advance on quality gates.

---

## TL;DR for the next agent

1. **You are on `main`.** G6 (corpse system) is **merged** (`main` head is the
   `Merge feat/corpse-system` commit). Git tree is clean.
2. **The prior "drag test failure" is RESOLVED — it was a test-isolation leak,
   not load flakiness and not a production bug.** `_spawn_corpse_near` parents
   the corpse under `host.get_parent()`, which for the CONTROLLER_SCENE loot
   tests is the runner's container (a *sibling* of the scene the runner frees
   in `after_test`) — so those corpses survived and piled up in the global
   `corpses` group. The arena drag test then found a leaked loot-test corpse at
   x=1.0, closer than its own x=1.5 corpse, and `FPSController._nearest_corpse`
   selected the leaked one, so the intended corpse never moved. The same leak is
   why one run reported only 6 of 7 tests. Fixed by freeing all `corpses` in
   `after_test` (commit `3393474`). **Verified green:** corpse suite 7/7, full
   suite **117/117** (exit 0, at loadavg ~10), three-peer E2E `net_smoke` PASS.
3. **Machine-load caveat still applies:** timing-sensitive tests can flake and
   the full suite can abort mid-run under extreme sustained CPU load. Check
   `sysctl -n vm.loadavg` before trusting a red result and rerun when low.
4. **First action on resume: start G7 (ping system)** — the next queue item.
   Brainstorm → write a plan under `docs/superpowers/plans/` → branch
   `feat/ping-system` → TDD. Then **G5 Wave 3** (Reclaim now unblocked by G6;
   Familiar needs G7).

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

`main` head: the `Merge feat/corpse-system` commit. Full suite **117/117** green
on main. Completed & merged, in order:

- **Milestone A** (predicted core): netfox integration, native controller
  support, Resonance system, weapon system (5 guns), Combat Blade / melee.
- **Milestone B** (networked loop): Steam lobbies & sessions (GodotSteam
  4.20.1, `SessionManager`, lobby browser, 16-player match session,
  join-in-progress spectators — **live two-machine Steam verification still
  pending the owner**); match flow & Arena/TDM + crouch (G1+G2); economy &
  loadouts (G3); core HUD (G4). CI workflow (G0) at `.github/workflows/tests.yml`.
- **Milestone C so far:** G5 Wave 1 (Slip, Wraith, Grenades), G5 Wave 2
  (Lifebloom, Tangle, Null Charge), **G6 Corpse system** (persistence, per-owner
  limit, inventory/looting, dragging).

Each plan lives in `docs/superpowers/plans/` with a `Status: EXECUTED` footer.
The master plan's queue tables and Gap Backlog are marked ✅ per item.

## What is code-complete but NOT merged

- *(nothing — G6 merged 2026-07-20. Next work starts fresh on `feat/ping-system`.)*

## What remains in the queue (Milestone C, then D)

Order per the master plan §Milestone C / Gap Backlog:
1. **G7 — Ping system** (aimed ping: world point + enemy tag; minimal comms
   wheel). Prerequisite for Familiar. *Next up after the G6 merge.*
2. **G5 Wave 3** — Reclaim (needs G6 corpses ✅), Familiar (needs G7 ping),
   Pulse Sight, Smart Rig (forced view tracking), Overclock Rig (grace-period
   HP drain). Write one plan per wave-ish; framework rules in MECHANICS_REFERENCE §4.A.
3. **G8 — CTF + variable objective item** (on the G2 match framework).
4. **G9 — two polished maps** (greybox then art; placeholder Quaternius CC0).
5. **G10 — True host migration** — SPIKE FIRST (`docs/superpowers/plans/SPIKE-host-migration.md`).
6. **G11 — Anti-cheat Layer-1 audit** (dedicated pass; input-trace logging).
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
