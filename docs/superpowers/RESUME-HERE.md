# Resume Here — CounterSpell Implementation Progress

**Last updated:** 2026-07-20 (Milestone C feature work + D hooks on `feat/familiar` branch — merge to main after green full suite)
**Goal:** Master plan Option C (PROMPT.md) — Milestone C + D launch-prep hooks.

---

## TL;DR

1. **Branch:** `feat/familiar` (ahead of main with Familiar + Wave3 augments + CTF + maps + G10/G11/G12/G13 hooks).
2. **Shipped on this branch (code):**
   - Familiar (G5 W3) full combat minion
   - Pulse Sight, Smart Rig, Overclock Rig (press-tick; MatchConfig)
   - CTF objective (`CtfObjective`) + `map_objective.tscn` / `map_close_quarters.tscn`
   - G10 host-migration spike findings (NO-GO mid-round exact resume; GO remesh+round restart)
   - G11 InputTrace autoload + audit doc
   - G12 SteamManager.g12_* presence/achievement/stat hooks
   - G13 MCP/InputTrace release strip via `COUNTERSPELL_RELEASE=1` / `counterspell/release_build`
3. **First action if suite green:** `--no-ff` merge to `main`, then human live smoke on arena + objective map.
4. **OWNER-only remaining:** two-machine Steam match; Deck/Windows feel; EOS/EAC binary link.

## How to run

```bash
# Full suite
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode

# E2E
pkill -x Godot 2>/dev/null; sleep 2; python3 tests/e2e/net_smoke.py

# Live
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/levels/test_arena.tscn
# Keys: Y pulse sight · U smart rig · O overclock · N familiar · H reclaim · P ping
# CTF map: res://scenes/levels/map_objective.tscn
```

## Queue status (Milestone C)

| Item | Status |
|------|--------|
| G5 W3 Reclaim | ✅ main |
| G5 W3 Familiar | ✅ this branch |
| G5 W3 Pulse Sight / Smart Rig / Overclock | ✅ this branch |
| G8 CTF | ✅ this branch (basic host-auth objective) |
| G9 maps | ✅ this branch (CQ + objective greybox) |
| G10 spike | ✅ findings in SPIKE-host-migration.md |
| G11 audit | ✅ InputTrace + audit doc |
| G12 Steam polish hooks | ✅ no-op offline |
| G13 release strip | ✅ env/project flag |

## Conventions

See CLAUDE.md. Load flakes: re-run isolated + full suite at low loadavg before red-product conclusions.
