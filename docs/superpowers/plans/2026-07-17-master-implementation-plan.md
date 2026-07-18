# CounterSpell Master Implementation Plan

> **For agentic workers:** This is the coordinating plan. It does not contain
> bite-sized tasks itself — it sequences the subsystem plans in this directory
> (each of which DOES contain tasks; execute those with
> superpowers:subagent-driven-development or superpowers:executing-plans) and
> scopes the PRD work that has no subsystem plan yet. When starting a work
> session: find the first queue entry below whose status is not DONE, open its
> plan file, and execute it task-by-task. When a queue entry has no plan file
> yet, write one first (superpowers:writing-plans), honoring the scope notes
> and prerequisites recorded here.

**Goal:** Ship CounterSpell's Early Access MVP per `docs/PRD.md` — a predicted-netcode FPS (guns + Manifestations + Augments) with Arena + CTF over Steam P2P — by executing a strictly ordered queue of subsystem plans, each gated on the full GdUnit4 suite and the PRD's milestone quality gates.

**Architecture:** Every gameplay mechanic is built netfox-rollback-native from day one (PRD §7 committed decision — prediction is never retrofitted). One integration frontier at a time: the queue order below is dependency-driven and already encoded in each plan's PREREQUISITE header. All gameplay numbers flow MatchConfig → `docs/ABILITY_TUNING_SHEET.md` (scratch) → `docs/MECHANICS_REFERENCE.md` (promoted); no constants in code.

**Tech Stack:** Godot 4.7.1 (GDScript, GL Compatibility), netfox v1.35.3, GodotSteam GDExtension (4.19.1 → 4.20 in the sessions plan), GdUnit4 v6.1.3, godot-mcp (live-game E2E), GitHub Actions (headless CI — to be added, see Gap G0).

---

## 1. Current State (verified 2026-07-17)

| Item | Status | Evidence |
|------|--------|----------|
| Godot 4.7.1 project + GodotSteam + SteamManager autoload | ✅ Done | `project.godot`, `scripts/steamworks.gd` |
| Basic FPS controller with Repulse + Glide combo (unpredicted) | ✅ Done | `scripts/player/fps_controller.gd` (still `_physics_process` + wall-clock — the netfox plan replaces this) |
| GdUnit4 + SceneRunner suite passing | ✅ Done | `tests/player/test_fps_controller.gd` (5 tests) |
| godot-mcp live-game interaction | ✅ Done | `.mcp.json`, `scripts/dev/mcp_interaction_server.gd` |
| Six subsystem plans written | ✅ Done | this directory |
| **Any subsystem plan executed** | ✅ Plan 1 done (2026-07-17) | netfox vendored + autoloads live; controller on `_rollback_tick`; `tests/e2e/net_smoke.py` passes at 50 ms |
| CI (headless test runs) | ❌ Missing | no `.github/workflows/` test job — PRD Phase 0 item, see Gap G0 |

---

## 2. Execution Queue

Execute strictly in order. **Gate for every task in every plan:** the full suite passes headless —

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import --quit   # fresh checkouts
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode
# Expected: 0 errors | 0 failures, exit code 0
```

### Milestone A — Predicted Core (PRD §11 gate: signature combo testable over a network and still feels good)

| # | Plan file | Delivers | Status |
|---|-----------|----------|--------|
| 1 | `2026-07-15-netfox-integration.md` | netfox v1.35.3 vendored; FPS controller rebuilt on `_rollback_tick` + `PlayerInput` (BaseNetInput); tick-based combo; NetworkSimulator dev scene; two-instance simulated-latency E2E | ✅ DONE (2026-07-17) |
| 2 | `2026-07-16-controller-support.md` | Joypad bindings for all actions (+ new `weapon_swap`/`menu`/`scoreboard` actions), stick look, contextual A (jump→glide), slowdown-on-target | ✅ DONE (2026-07-17; MatchConfig pulled forward from plan 3) |
| 3 | `2026-07-16-resonance-system.md` | `MatchConfig` autoload (all tunables); `ResonancePool` as rollback state; costs on Repulse/Glide; health + damage attribution; archetype stats; Dwarf drain; Elf auto-heal | ☐ |
| 4 | `2026-07-16-weapon-system.md` | `WeaponBase`/`WeaponRig`, 2 slots, mags+reserve, hit zones, hybrid recoil, lag-compensated hitscan; Pistol, SMG, Shotgun, Rifle, Sniper | ☐ |
| 5 | `2026-07-16-melee-third-person.md` | Combat Blade: third-person camera, swing/backstab, non-stacking bleed (emergent Elf equilibrium), blade-vs-blade block | ☐ |

**Milestone A exit check (manual, after plan 5):** run the NetworkSimulator dev scene at ≥100 ms injected latency; Repulse+Glide launch, weapon fire, and blade duels must feel responsive on the "client" instance. Record verdict + numbers in `docs/ABILITY_TUNING_SHEET.md` §9 (Investigations & Playtest Tracker).

### Milestone B — Networked Loop (PRD §11 gate: full remote match completes without intervention, incl. a mid-match joiner at a round boundary)

| # | Plan file | Delivers | Status |
|---|-----------|----------|--------|
| 6 | `2026-07-16-steam-lobbies-sessions.md` | GodotSteam 4.20; `SessionManager`; lobby create/invite/browse/join; SteamMultiplayerPeer under netfox; 16-player spawning; join-in-progress spectate; host-migration spike scoped as its final task | ☐ |
| 7 | *(to write — Gap G2)* Match flow & Arena mode | Round state machine, respawn/death, win conditions, results | ☐ |
| 8 | *(to write — Gap G3)* Buy phase, economy & loadouts | Wages, buy menu, shopping-list loadouts, cybernetic slots | ☐ |
| 9 | *(to write — Gap G4)* Core HUD | Resonance pips, health, ammo, scoreboard, kill feed | ☐ |

### Milestone C — Two Modes + Playtests (gate: playtesters return voluntarily; movement/combat feel scores well)

Order within C is flexible except where noted; each item gets its own plan when reached.

- **G5 — Ability framework + remaining roster** (three waves, see Gap G5). Wave 3 blocks on G6/G7.
- **G6 — Corpse system** (persistence, dragging, inventory/looting) — prerequisite for Reclaim.
- **G7 — Ping system** — prerequisite for Familiar; also comms.
- **G8 — CTF + variable objective item**, **G9 — two polished maps**, **G10 — host migration** (spike first — PRD §7), **G11 — anti-cheat Layer-1 audit**.

### Milestone D — EA Launch Prep (gate: vertical slice justifies Steam Direct fee; anti-cheat verified on Windows + Deck/Proton)

Not planned in detail yet — write plans when Milestone C's gate is met: Steam achievements/stats/cloud/rich presence (G12), EAC via EOS + Steamworks game bans (G13), store page/marketing (non-code). Also strip/feature-flag `McpInteractionServer` and the ENet dev path from release builds (tracked as part of G13's release-build task — the TODO lives in `docs/TESTING.md`).

---

## 3. Gap Backlog — work the PRD requires that has no plan file yet

Each entry is the scope brief for a future `writing-plans` session. Decided design is cited so the plan author does not re-litigate it.

### G0 — CI: headless test runs on GitHub Actions *(no prerequisites — can be done immediately, in parallel with plan 1)*

- **Scope:** one workflow (`.github/workflows/tests.yml`) that on push/PR: installs a pinned Linux headless Godot 4.7.1, runs the `--import --quit` warm-up, then the GdUnit4 command-line run above, failing the job on non-zero exit; uploads `reports/` as an artifact.
- **Known risks to verify in that plan:** GodotSteam GDExtension must load (or degrade gracefully) on Linux CI with no Steam client — `SteamManager` already tolerates failed init (TESTING.md), but the extension binary for Linux must be present in `addons/godotsteam/`; if it is macOS-only today, the import step will error and the plan must vendor the Linux binaries.
- **References:** `docs/TESTING.md` "Running Tests" + its two CI links.

### G1 — Crouch *(small; after plan 2)*

- **Scope:** PRD §6 Phase 0 lists crouch as pending and no plan covers it. Add a `crouch` InputMap action (keyboard + the controller layout's reserved slot), a rollback-tick movement rule (reduced speed + collider height change, prediction-safe), and a MatchConfig-tuned speed multiplier. Small enough to fold into the start of the G2 plan if preferred — record the choice here when made.

### G2 — Match flow & Arena/TDM mode *(after plan 6)*

- **Scope:** round state machine as rollback-aware match state (lobby → buy phase stub → round live → round end → results); death/respawn (health exists from plan 3); team assignment; TDM scoring; match end. The buy phase is a timed stub here — G3 fills it.
- **Decided design:** PRD §5 launch modes; join-in-progress enters at round boundaries (PRD §7), so round transitions must expose a "buy-in point" hook the sessions plan's spectator flow can call.
- **Anti-cheat Layer 1 (PRD §6 Phase 1):** authority-side validation rules are written *with* this plan's mechanics (movement caps already live in rollback ticks; add respawn/score authority checks) plus input-trace logging hooks.

### G3 — Buy phase, economy & loadouts *(after G2)*

- **Scope:** wages + performance bonuses with winner compounding (MECHANICS_REFERENCE §7); buy menu (functional/debug-grade UI); weapon/ability purchase; **loadouts as priority-ordered shopping lists** with skip-and-continue semantics (PRD §5 — decided 2026-07-15; skip-vs-stop is an open playtest question, implement skip-and-continue); cybernetic slot exclusivity + permanence (MECHANICS_REFERENCE §4 — Eye / Full Body slots); drop-on-death already handled by the weapons plan.
- **All prices/wages via MatchConfig**; baselines in MECHANICS_REFERENCE §4/§5 tables.

### G4 — Core HUD *(after G2; can interleave with G3)*

- **Scope:** Resonance pips with partial-fill + visually locked reserved pips (MECHANICS_REFERENCE §2 decided semantics), health, ammo (mag + reserve), active-weapon indicator, combat-gating indicator, scoreboard (`scoreboard` action exists after plan 2), kill feed, denial feedback for insufficient-Resonance casts. Functional/debug-grade visuals — art pass is Milestone D.

### G5 — Ability framework + remaining roster *(after Milestone B; waves in order)*

Framework rules are decided (MECHANICS_REFERENCE §4.A — Resonance-only pacing, instant/placement casts, effects die with caster, full friendly fire). Repulse + Glide Harness already exist. Suggested wave split, one plan per wave:

1. **Wave 1 — instant/self abilities:** Slip (velocity blink, safe-fail refund), Wraith (toggle + drain, weapons locked, instant rematerialize), Grenades (cookable fuse, Repulse-able).
2. **Wave 2 — placed/persistent world objects:** Lifebloom, Tangle (pull applied inside each victim's own rollback tick — decided), Null Charge. These are the "persistent networked objects" the PRD flags in §7 — netcode approach per MECHANICS_REFERENCE §10.
3. **Wave 3 — dependent abilities:** Reclaim (needs G6 corpses), Familiar (needs G7 ping), Pulse Sight, Smart Rig (forced view tracking), Overclock Rig (grace-period HP drain).

### G6 — Corpse system *(Milestone C; before Wave 3)*

- **Scope:** full body persistence in all modes, per-player corpse limit, corpse inventory (weapons/ammo/grenades as at death), looting, dragging with Pistol/SMG-only restriction (MECHANICS_REFERENCE §11, decided 2026-07-17).

### G7 — Ping system *(Milestone C; before Familiar)*

- **Scope:** aimed ping (world point + enemy tag), minimal comms wheel; Familiar consumes the enemy-tag ping as its hunt target (MECHANICS_REFERENCE §4.A).

### G8 — CTF + variable objective item *(Milestone C)*

- **Scope:** CTF on the G2 match framework; the flag is a **variable item**, first version replicating source behavior — a powerful melee weapon that disables some abilities while carried (MECHANICS_REFERENCE §11 "Objective Items").

### G9 — Maps *(Milestone C)*

- **Scope:** 2 polished greybox-then-art maps (one close-quarters, one objective-scaled — PRD §5 says 2–4 total for EA; start with 2). Placeholder art stays Quaternius CC0 with `models/placeholders/ATTRIBUTION.md` kept accurate until the commissioned-art budget decision (PRD §9).

### G10 — True host migration *(Milestone C; SPIKE FIRST)*

- PRD §7 (decided): migration requires a **feasibility spike** (netfox authority handoff + peer re-mesh) before its implementation plan is written. Graceful match-end is the interim behavior. The sessions plan's final task scopes the spike.

### G11 — Anti-cheat Layer-1 audit *(end of Milestone C)*

- Layer 1 is written incrementally with each mechanic (movement caps, Resonance costs, no client-reported hits — already constraints inside plans 1–5 and G2). This item is a dedicated audit pass: verify every state-mutating path is authority-validated, and land the structured input-trace logging (PRD §7) if any earlier plan deferred it.

---

## 4. Testing Gates (from `docs/TESTING.md`)

1. **Per task (every plan):** headless GdUnit4 run, exit 0, `0 errors | 0 failures`. Tests live in `tests/` mirroring `scripts/`; SceneRunner for gameplay behavior; everything must tolerate failed Steam init (headless has no Steam client).
2. **Per plan:** each plan's own E2E task — from plan 1 onward that means the NetworkSimulator two-instance simulated-latency run driven via the godot-mcp TCP protocol (fallback: shell-run instances + stdout capture per TESTING.md).
3. **Per milestone:** the PRD §11 quality gate, checked manually and recorded in `docs/ABILITY_TUNING_SHEET.md` §9 before the queue advances to the next milestone. Milestones advance on gates, never on dates.
4. **Continuous (after G0):** CI runs the suite on every push/PR; a red main branch blocks queue progress.
5. **Steam-dependent behavior:** logic-level tests with injected fakes + manual two-machine verification (sessions plan pattern) — CI stays green with no Steam running.

---

## 5. Standing Constraints (bind every plan; copied from CLAUDE.md / plan headers)

- **IP:** original terms only — Resonance, Runners, the Grid, Manifestations, Augments, Repulse, Glide. Never Shadowrun trademarks (PRD §2).
- **Tick-based gameplay:** no wall-clock (`Time.get_unix_time_from_system()`) or frame-based `is_action_just_pressed` inside simulation; durations are tick counts; rollback state registered with `RollbackSynchronizer`; world side effects gated on `is_fresh` / confirmed; simulation randomness seeded per (tick, peer, index).
- **No gameplay constants in code:** all tunables via `MatchConfig` (`@export` only for scene wiring), baselines recorded in `docs/ABILITY_TUNING_SHEET.md`, promoted values logged in `docs/MECHANICS_REFERENCE.md`.
- **Style:** typed GDScript, tabs; temp files in `.scratch/`; commits end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- **Docs pipeline:** ideas → tuning sheet → mechanics reference → PRD (CLAUDE.md "Docs Workflow"). Owner decisions in MECHANICS_REFERENCE/PRD are settled — plans implement, not re-litigate.

## 6. Top Risks (PRD §9, restated as queue checkpoints)

| Risk | Where it gets answered |
|------|------------------------|
| netfox fit for physics-impulse abilities (Repulse) | Plan 1's simulated-latency E2E — if the combo can't be made to feel right, stop the queue and re-evaluate the transport/rollback approach before plans 2–6 |
| Host upload at 16 players × 60 tps | First real playtests after plan 6 — knobs: tickrate, state-property count, `session.max_players` |
| Host migration feasibility | G10 spike (scoped in plan 6's final task) — interim: graceful match-end |
| GodotSteam 4.20 upgrade breakage | Plan 6 Task 1 — expressobits/steam-multiplayer-peer is the documented fallback transport |
| Content production (maps/art/sound) | G9 + Milestone D — placeholder policy until then; do not let art block mechanics plans |
| Scope creep | This queue **is** the scope; anything new goes to `docs/ideas/` first, then MECHANICS_REFERENCE via owner decision, then a plan |

---

**Maintenance:** check off queue entries as their plans complete (all tasks committed + suite green + plan's E2E done). When writing a new plan for a G-item, add its filename to the queue table and delete the corresponding backlog entry's "(to write)" marker. Update `docs/PRD.md` only if scope/vision changes — this file tracks execution, not vision.
