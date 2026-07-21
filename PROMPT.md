# Goal Prompt — Full Master Plan (Option C: Milestone C + D)

Paste everything under **PROMPT START** into the goal command (or give the agent this file as the task instruction).

This is **Option C**: complete the CounterSpell master implementation plan through **Milestone C** (human-testable full feature set) **and continue into Milestone D** (EA launch prep: Steam polish, anti-cheat release path, MCP strip). Stop before non-code store marketing copy unless the owner asks.

---

## PROMPT START

```text
Goal: Execute the CounterSpell MASTER implementation plan through Milestone C
and then Milestone D, until the product is ready for human playtesting of every
design-defined feature AND the EA launch-prep code path is in place.

================================================================
SOURCES OF TRUTH (in order — do not re-litigate decided design)
================================================================
1. docs/superpowers/plans/2026-07-17-master-implementation-plan.md
   — execution queue, gap backlog, per-plan gates
2. docs/superpowers/RESUME-HERE.md
   — current branch, last green state, next action
3. docs/PRD.md
   — vision, milestone quality gates (§11), launch modes
4. docs/MECHANICS_REFERENCE.md
   — decided mechanics; implement as specified
5. docs/ABILITY_TUNING_SHEET.md
   — active baselines / playtest notes for new numbers
6. Existing subsystem plans & specs under:
   docs/superpowers/plans/ and docs/superpowers/specs/
7. CLAUDE.md / project conventions
   — Godot 4.7.1, netfox rollback-only sim, press-tick inputs,
     MatchConfig-only tunables, original IP terms (no Shadowrun marks),
     free-in-_process for rollback entities, flat MultiplayerSpawner data

Always open RESUME-HERE first on every session. Then find the first incomplete
master-plan queue / gap item and work that next. Keep RESUME-HERE and the
master-plan queue checkmarks accurate after every merge.

================================================================
SCOPE BOUNDARY
================================================================

### Phase 1 — Milestone C (must complete before Phase 2)
Human-testable vertical slice of all design-defined gameplay features:

- Merge any unmerged ready work (e.g. feat/familiar) only after its gates pass.
- Finish remaining G5 Wave 3 (one plan/spec per ability; writing-plans first
  if no plan/spec exists):
  - Familiar (if not fully merged + green on main)
  - Pulse Sight
  - Smart Rig (forced view tracking)
  - Overclock Rig (grace-period HP drain)
- G8 — CTF + variable objective item on the existing G2 match framework
  (MECHANICS_REFERENCE §11 objective-item rules).
- G9 — two playable maps (greybox acceptable): one close-quarters, one
  objective-scaled; Quaternius CC0 placeholders OK; keep ATTRIBUTION.md accurate.
- G10 — host-migration SPIKE FIRST (feasibility: netfox authority handoff +
  peer re-mesh). Write findings. Implement full migration only if the spike
  recommends go AND Milestone C schedule still allows it; otherwise document
  interim graceful match-end as the shipped behavior.
- G11 — Layer-1 anti-cheat audit: every state-mutating path authority-validated;
  land structured input-trace logging if any earlier plan deferred it.
- G7 deferred “comms wheel” is NOT required for C unless you complete aimed
  ping regression as part of Familiar/ping smoke.

### Phase 2 — Milestone D (after Phase 1 matrix is green)
EA launch-prep code (write plans when starting each item if none exist):

- G12 — Steam achievements / stats / cloud / rich presence (as scoped in PRD).
- G13 — EAC via EOS + Steamworks game-ban hooks as designed; release-build
  stripping / feature-flag of McpInteractionServer and ENet dev path
  (see docs/TESTING.md TODO). CI and headless tests must still pass with
  Steam init failing gracefully.
- Do NOT write marketing copy, store screenshots campaigns, or pricing page
  content unless the owner explicitly expands scope mid-goal.

### Explicitly OUT OF SCOPE (unless owner amends the goal)
- Re-opening decided design in MECHANICS_REFERENCE / PRD
- Ranged Familiars, multi-Familiar, navmesh pathfinding, polish VFX pass
- Unified ability ownership/buy gating for all Manifestations (deferred design)
- Owner-only two-machine Steam verification on physical hardware (see OWNER
  checklist — agent leaves a runnable checklist, does not claim it done)
- Scope creep: new ideas go to docs/ideas/ only; do not implement without
  promotion to MECHANICS_REFERENCE + a plan

================================================================
WORKING METHOD (mandatory)
================================================================
1. Session start: read RESUME-HERE + master plan queue → pick first incomplete item.
2. If the item has no plan file: run writing-plans (or equivalent) against the
   master-plan gap brief + MECHANICS_REFERENCE; save plan under
   docs/superpowers/plans/; update master plan to reference it.
3. Branch: feat/<subsystem> from main (or continue the named feature branch).
4. TDD task-by-task: real shipped paths only (NetSuite press-ticks, in-tick
   damage, static-prop harness for offline netfox — see test_reclaim /
   test_familiar patterns). No wall-clock in simulation. No latched bool edges.
5. Per subsystem exit before merge:
   a. Targeted GdUnit suite green (exit 0)
   b. Full ./tests GdUnit green (exit 0) — see Hard Gates
   c. net_smoke when networking, spawn, or match-flow surfaces change
   d. Docs + MatchConfig baselines + cspell for touched terms
   e. Commit(s); --no-ff merge to main; update master plan ✅ + RESUME-HERE
6. One subsystem at a time. Do not skip dependencies.
7. Do NOT mark this overall goal complete until Phase 1 AND Phase 2 hard gates
   below are all satisfied and evidence is saved.

================================================================
HARD GATES — block overall completion (no flake waivers)
================================================================

### Gate A — Full automated suite
Full headless GdUnit on ./tests:
  GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s \
    addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode
Must report 0 errors | 0 failures and process exit 0.
Save log: {SCRATCH}/gdunit_full.log (or project reports/ + copy summary to scratch).

If anything fails:
  - Fix product or test, OR
  - If suspected load flake: check sysctl -n vm.loadavg; re-run the failing
    suite alone to PASS; then re-run the FULL suite at low load to PASS.
Overall goal cannot complete with a red full suite. “Known flaky” is not a waiver.

### Gate B — Network E2E
From a clean state (kill straggler Godot/net_test processes first):
  python3 tests/e2e/net_smoke.py
Must print E2E NET SMOKE: PASS.
Save: {SCRATCH}/net_smoke.log

### Gate C — Human Feature Smoke Matrix (live game)
Launch real scenes (test_arena and/or match session). Drive real InputMap
actions via Godot MCP (127.0.0.1:9090) and/or Input.action_press on bound
actions. For EACH row, record PASS with: input used, scene, observation.

Write: {SCRATCH}/human_feature_smoke.md (and optionally promote a copy to
docs/superpowers/ when stable).

Matrix rows (all must be PASS before Phase 1 is done; Phase 2 adds D rows):

Movement & core
- [ ] Walk / sprint / jump / crouch
- [ ] Glide deploy + Repulse + Repulse→Glide combo launch
- [ ] Controller: move, look, fire, jump→glide contextual, critical abilities

Weapons & melee
- [ ] Pistol, SMG, Shotgun, Rifle, Sniper: fire + reload + slot swap
- [ ] Combat Blade: third-person swing; backstab/bleed path if testable in scene

Resonance & archetypes
- [ ] Spend / cast deny on empty; reserved pips show on HUD
- [ ] At least one archetype passive smoke (Elf heal or Dwarf drain) if scene allows

Abilities Wave 1
- [ ] Slip
- [ ] Wraith (enter/exit; weapons locked while phased)
- [ ] Grenade cook + throw

Abilities Wave 2
- [ ] Lifebloom place
- [ ] Tangle place + pull feel
- [ ] Null Charge place + suppress/cast deny inside

Corpse / Reclaim / Ping / Familiar
- [ ] Death leaves corpse; loot; drag restricts to Pistol/SMG
- [ ] Ping world point + enemy tag (HUD markers)
- [ ] Reclaim: revive from in-range corpse; caster-death bleed if feasible
- [ ] Familiar: summon + re-task; FOLLOW or GUARD; HUNT after enemy ping

G5 Wave 3 remainder (once implemented)
- [ ] Pulse Sight
- [ ] Smart Rig
- [ ] Overclock Rig

Match / economy / HUD
- [ ] Buy phase → round live → death/respawn → round end path
- [ ] Buy menu / loadout shopping list path (functional)
- [ ] HUD: health, Resonance, ammo, scoreboard, kill feed, cast deny feedback

CTF + maps (once implemented)
- [ ] CTF: pick up / carry / capture or score / drop objective
- [ ] Map 1 loads and is playable end-to-end
- [ ] Map 2 loads and is playable end-to-end

Milestone D smoke (Phase 2)
- [ ] Rich presence / achievement hook smoke if APIs available offline-tolerant
- [ ] Release or export path builds without McpInteractionServer / ENet dev
      surface enabled (or feature-flagged off)
- [ ] Headless tests still pass with Steam init failure

Owner-only (document checklist; do NOT claim agent-complete)
- [ ] OWNER: two-machine Steam lobby + full match
- [ ] OWNER: Deck/Proton or Windows smoke if required for EA
- [ ] OWNER: latency feel sign-off at ≥100 ms if still open in tuning sheet

### Gate D — Docs & queue hygiene
- Every new tunable in MatchConfig DEFAULTS with baseline note in
  ABILITY_TUNING_SHEET (and MECHANICS_REFERENCE when promoted).
- Key/joypad bindings documented for every new action (MECHANICS §11 layout).
- Master plan queue / gap entries marked ✅ with plan filename + date when done.
- RESUME-HERE updated: what is on main, what is next, how to run suite/E2E/live.
- cspell clean for project terms touched (`.cspell/custom-dictionary.txt` as needed).
- IP: no Shadowrun trademarks in code, docs, or assets.

### Gate E — Git integration state
- main is the integration branch with Milestone C (and D code) merged.
- No long-lived unmerged feature branches at completion except an explicit
  documented exception in RESUME-HERE.
- Commits use project Co-Authored-By convention.
- Ask before force-push or any destructive git operation.

================================================================
EVIDENCE REQUIRED BEFORE update_goal(completed: true)
================================================================
- {SCRATCH}/gdunit_full.log — full suite exit 0
- {SCRATCH}/net_smoke.log — PASS
- {SCRATCH}/human_feature_smoke.md — every non-OWNER matrix row PASS
- Master plan + RESUME-HERE on main reflecting Milestone C complete and
  Milestone D status (complete or precise remaining owner tasks only)
- For D: note how release stripping was verified (script, export preset, or test)

Do NOT flip plan checklist items to [x] until the corresponding observation
exists. Do NOT complete on partial green.

If blocked >1 hour on the same issue: set blocked_reason with exact error,
failing test name, and last green commit. Do not invent “done”.

================================================================
STANDING ENGINEERING CONSTRAINTS
================================================================
- Simulation only in _rollback_tick / entity rollback ticks; durations = ticks.
- Edge inputs = press-tick ints, never latched bools for edge actions.
- Out-of-band rollback writes are discarded; use in-tick apply / plain-pending /
  NetworkRollback.mutate as established patterns.
- Spawned entities: own RollbackSynchronizer; free in _process when terminal.
- Spawn data: flat primitives only through MultiplayerSpawner.
- All gameplay numbers via MatchConfig — no magic constants in ability code.
- Headless must tolerate failed Steam init.
- Temp files in .scratch/ or goal {SCRATCH}; never commit steam_appid.txt / .godot/

================================================================
SUCCESS STATEMENT (what “done” means)
================================================================
A human can boot the game on main, play Arena/TDM and CTF on both maps, exercise
every Manifestation/Augment/weapon/corpse/ping path in the smoke matrix, run
automated suite + net_smoke green, and the release-oriented D work (Steam polish
hooks + MCP/ENet strip path + anti-cheat Layer-1 audit) is implemented or
explicitly documented with only OWNER hardware steps remaining.
```

## PROMPT END

---

## How to use

1. Prefer a **long-running / multi-session goal** — this is the entire remaining master plan, not one PR.
2. Point the agent at this file: e.g. “Execute `PROMPT.md` (Option C) as the goal.”
3. After each session, confirm `docs/superpowers/RESUME-HERE.md` was updated so the next run continues correctly.
4. Owner still owns two-machine Steam and hardware smoke rows marked OWNER.

## Related files

| File | Role |
|------|------|
| `docs/superpowers/plans/2026-07-17-master-implementation-plan.md` | Queue |
| `docs/superpowers/RESUME-HERE.md` | Resume pointer |
| `docs/PRD.md` | Milestone gates |
| `docs/TESTING.md` | Suite / E2E / MCP / release strip notes |
| `CLAUDE.md` | Engineering conventions |
