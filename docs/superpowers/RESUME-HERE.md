# Resume Here — CounterSpell Implementation Progress

**Last updated:** 2026-07-20 (Familiar shipped on `feat/familiar` — ready for human playtest / merge)
**Goal being executed:** Implement the entire master plan
(`docs/superpowers/plans/2026-07-17-master-implementation-plan.md`) — every
subsystem plan, all tests passing. Milestones advance on quality gates.

---

## TL;DR for the next agent

1. **Branch:** `feat/familiar` (from `main`). **G6**, **G7**, **Reclaim**, and
   **Familiar** are implemented. Familiar: 13/13 GdUnit green; live InputMap
   `familiar` (N / D-pad Right) verified twice in `test_arena` via MCP TCP.
   Full suite: 139 cases; only known load-flaky `test_tangle_drags_enemy_toward_center`
   red under sustained load — not a Familiar regression.
2. **Familiar shipped (G5 W3 ability 2):** rollback combat minion
   (`scripts/abilities/familiar.gd` + `scenes/abilities/familiar.tscn`) —
   FOLLOW / GUARD (aim ground) / HUNT overlay via `PingService.latest_enemy_tag`,
   melee vs players + enemy Familiars, Null + Dwarf + shootable counters, dies
   with caster, 4 Resonance held. Spawn via `ProjectileSpawner.spawn_familiar`.
   Cast: `_cast_familiar` on press-tick; re-mode via `queue_set_mode` plain-pending.
3. **Input:** `familiar` press-tick in `PlayerInput` + `project.godot` (N / joy 14).
4. **CRITICAL test-harness lesson (offline netfox):** only the local-authority
   runner scene is simulated — see `tests/abilities/test_reclaim.gd` /
   `test_familiar.gd` static-prop pattern.
5. **Machine-load caveat still applies** — re-run known flaky suites alone at low
   load before treating red as product failure.
6. **First action on resume after merge:** remaining G5 W3 — **Pulse Sight**,
   Smart Rig, Overclock Rig; then G8 CTF, G9 maps, G10 host-migration SPIKE, G11.

---

## How to run things (macOS, Godot 4.7.1)

```bash
cd /Users/cyotee/Development/github-cyotee/game-running-in-shadows

# Full headless test suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import --quit
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode

# Familiar only
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/abilities/test_familiar.gd --ignoreHeadlessMode

# Live arena + MCP (127.0.0.1:9090) — press N to summon Familiar
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/levels/test_arena.tscn
```

## What is DONE and merged / ready

- Milestone A/B and Milestone C: G5 W1–W2, G6, G7, Reclaim ✅ (on `main`).
- **Familiar** ✅ on `feat/familiar` — merge when ready (`--no-ff`).

## What remains (Milestone C, then D)

1. **G5 Wave 3 (continued)** — Reclaim ✅, Familiar ✅. Remaining: Pulse Sight,
   Smart Rig, Overclock Rig.
2. **G8 — CTF** · **G9 — maps** · **G10 — host migration SPIKE** · **G11 — anti-cheat**.
3. **Milestone D** — Steam polish, EAC/EOS, store page; strip MCP from release.

## Hard-won conventions

See CLAUDE.md. Familiar follows PlacedField lifecycle (free in `_process`, flat
spawn data, MatchConfig-only numbers, press-tick inputs).
