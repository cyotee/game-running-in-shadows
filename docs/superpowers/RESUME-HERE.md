# Resume Here — CounterSpell Implementation Progress

**Last updated:** 2026-07-23 (Controls rebind menu implemented)
**Goal status:** Master plan Option C (PROMPT.md) — code complete for agent scope;
Controls rebind (listen-to-map, multi-bind KBM+pad) shipped.

---

## TL;DR

1. **On `main`.** Familiar, Pulse Sight, Smart Rig, Overclock, CTF objective,
   two greybox maps, G10–G13, plus **Controls rebind** (`InputBindings` + Settings
   UI + pause menu).
2. **Controls:** Main menu → Settings → Controls; in-match Esc/Start → Settings.
   Multi-bind + listen-to-rebind; `user://input_bindings.json`.
3. **OWNER-only remaining:** two-machine Steam match; Deck/Windows feel; EOS/EAC
   SDK link (hooks only in-repo).
4. **Next product work:** loadout-specific bind profiles; Steam Input Phase 2;
   art pass.

## How to run

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode

python3 tests/e2e/net_smoke.py

# Arena
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/levels/test_arena.tscn
# Keys: N familiar · Y pulse sight · U smart rig · O overclock · H reclaim · P ping
# CTF map
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/levels/map_objective.tscn
# Release strip check
COUNTERSPELL_RELEASE=1 /Applications/Godot.app/Contents/MacOS/Godot --path . --quit-after 60
```

## Milestone C / D checklist

| Item | Status |
|------|--------|
| G5 W3 all | ✅ |
| G8 CTF | ✅ basic host-auth flag |
| G9 maps | ✅ CQ + objective greybox |
| G10 spike | ✅ NO-GO mid-round exact; GO remesh later |
| G11 audit + InputTrace | ✅ |
| G12 Steam hooks | ✅ offline-safe |
| G13 release strip | ✅ env/project flag |

See CLAUDE.md for netfox conventions.
