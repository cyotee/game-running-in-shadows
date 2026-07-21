# CounterSpell

Fast-paced cyber-fantasy first-person shooter: guns, Manifestations, Augments, and the Grid — an original-IP *spiritual successor* to the 2007 Shadowrun FPS (not affiliated with that IP).

**Engine:** Godot **4.7.1** (pinned) · **Language:** GDScript · **Netcode:** netfox · **Distribution:** Steam (GodotSteam)

> Product vision and roadmap: [docs/PRD.md](docs/PRD.md) · Mechanics: [docs/MECHANICS_REFERENCE.md](docs/MECHANICS_REFERENCE.md) · Tuning: [docs/ABILITY_TUNING_SHEET.md](docs/ABILITY_TUNING_SHEET.md) · Agent resume: [docs/superpowers/RESUME-HERE.md](docs/superpowers/RESUME-HERE.md)

---

## Prerequisites

1. **Godot 4.7.1** (editor). See [docs/SETUP.md](docs/SETUP.md) if present.
2. **Steam client running** for full Steam features (lobbies, etc.). Offline arena still runs without Steam.
3. Optional: `steam_appid.txt` in the project root containing only:
   ```
   480
   ```
   (Spacewar dev App ID; **gitignored — never commit**.)
4. After installing/updating any **GDExtension** (e.g. GodotSteam): **restart the editor**.

On macOS, prefer launching from the app bundle for full logs:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --editor --path .
```

---

## Running the game in the Godot Editor

### Keyboard shortcuts in the editor

| Shortcut | Action |
|----------|--------|
| **F5** | Run main scene (`project.godot` → Application → Run → Main Scene) |
| **F6** | Run **currently open** scene |
| **F8** | Stop |

**Default main scene:** `scenes/levels/test_arena.tscn` (FPS prototype arena).

### Scene cheat sheet

| What you want to test | Open this scene | Run with |
|----------------------|-----------------|----------|
| **FPS sandbox** (movement, guns, abilities) | `scenes/levels/test_arena.tscn` | F5 or F6 |
| **CTF greybox** (flag, goals) | `scenes/levels/map_objective.tscn` | F6 |
| **Close-quarters map** | `scenes/levels/map_close_quarters.tscn` | F6 |
| **Full match session** (spawn, MatchState, economy hooks) | `scenes/session/match_session.tscn` | F6 |
| **Main menu / lobby UI** | `scenes/ui/main_menu.tscn`, `scenes/ui/lobby_browser.tscn` | F6 |
| **Two-instance netcode** (latency) | `scenes/dev/net_test.tscn` | Prefer shell E2E (below) |
| **Placeholder art review** | `scenes/dev/model_review.tscn` | F6 |

**Tip:** For day-to-day ability feel, use **test_arena** (F5). For CTF, open **map_objective** and press **F6**.

---

## Default controls (keyboard / mouse)

Bindings live under **Project → Project Settings → Input Map**. Defaults:

### Movement & view

| Action | Default |
|--------|---------|
| Move | **W A S D** (arrows also bound) |
| Jump | **Space** (ground only; mid-air Jump deploys Glide once, not multi-jump) |
| Sprint | **Shift** |
| Crouch | **Ctrl** |
| Look | Mouse |
| Toggle mouse capture | **Esc** |
| Scoreboard | **Tab** |

### Combat

| Action | Default |
|--------|---------|
| Fire | **LMB** |
| ADS | **RMB** |
| Reload | **R** |
| Weapon swap | **Q** |
| Weapon slot 1 / 2 | **1** / **2** |
| Interact (loot / CTF flag) | **T** |

### Manifestations & utility

| Action | Default |
|--------|---------|
| Repulse | **E** |
| Glide | **G** (airborne jump can also deploy glide on controller) |
| Slip | **F** |
| Wraith | **V** |
| Grenade (hold to cook, release to throw) | **C** |
| Lifebloom | **Z** |
| Tangle | **X** |
| Null Charge | **B** |
| Ping (world / enemy tag) | **P** or **middle mouse** |
| Reclaim | **H** |
| Familiar | **N** |
| Pulse Sight | **Y** |
| Smart Rig | **U** |
| Overclock | **O** |

Controller (joypad) events are also bound for many actions — see Input Map for full layout (MECHANICS_REFERENCE §11).

---

## Playtest guides by aspect

### 1. Movement & signature combo

1. Run **test_arena** (F5).
2. Walk, sprint, jump, crouch.
3. **Repulse + Glide launch:** look **down**, press **E** (Repulse), then **G** (Glide) quickly for the vertical launch combo.

### 2. Weapons & melee

1. Fire (**LMB**), ADS (**RMB**), reload (**R**), swap (**Q** / **1** / **2**).
2. If a blade is equipped: switching to it should go third-person; swing with fire / ADS as bound.

### 3. Resonance

1. Cast Repulse (**E**) — spend Resonance; spam until empty and confirm cast deny feedback on the HUD.
2. Watch reserved pips when holding Lifebloom, Familiar, Pulse Sight, Smart Rig, Overclock, etc.

### 4. Wave 1 abilities

| Ability | Key | Try |
|---------|-----|-----|
| Slip | **F** | Blink along velocity / aim; blocked destination should fizzle |
| Wraith | **V** | Phase in/out; weapons locked while phased |
| Grenade | **C** | Hold to cook, release to throw |

### 5. Wave 2 placed fields

| Ability | Key | Try |
|---------|-----|-----|
| Lifebloom | **Z** | Place near self; heal aura |
| Tangle | **X** | Place so enemies are pulled (needs a second body or net instance) |
| Null Charge | **B** | Place; casting should be suppressed inside the field |

### 6. Corpses, ping, Reclaim

1. Die or force a kill path so a **corpse** remains (match flow or damage).
2. **T** near corpse — loot / hold interact to drag (Pistol/SMG only while dragging).
3. **P** / MMB — world ping or enemy tag under reticle.
4. **H** — Reclaim near a dead ally’s corpse (needs a dead ally + corpse in range).

### 7. Wave 3 (Familiar + augments)

| Ability | Key | Try |
|---------|-----|-----|
| Familiar | **N** | Summon minion; aim at ground for GUARD; ping an enemy for HUNT |
| Pulse Sight | **Y** | Short wall-reveal of nearby enemies |
| Smart Rig | **U** | Forced view tracking toward nearest living enemy |
| Overclock | **O** | Overdrive: speed/reload boost; HP drain after ~2 s grace |

### 8. CTF (Capture the Flag)

1. Open `scenes/levels/map_objective.tscn` → **F6**.
2. Flag starts near the origin; team goals are at the map ends.
3. **T** (interact) near the flag to pick it up.
4. Carry to **your team’s goal** to score (host-authoritative objective).
5. On death, the flag should drop and eventually return home.

### 9. Match session / multiplayer shell

1. Open `scenes/session/match_session.tscn` → **F6** (offline: local peer + MatchState).
2. Or use **main menu** / **lobby browser** scenes if testing Steam lobby UI.
3. Full Steam two-machine match: both clients on Steam, same build, host create lobby / join — **owner playtest** (not fully automated).

### 10. Network latency smoke (two instances)

Prefer the automated E2E (no editor required):

```bash
# From repo root; kills stragglers first if needed
python3 tests/e2e/net_smoke.py
# Expect: E2E NET SMOKE: PASS
```

Or run two Godot instances of `scenes/dev/net_test.tscn` with different `GODOT_MCP_PORT` values if driving MCP manually.

---

## Automated tests (headless)

```bash
# Warm import on fresh clone
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import --quit

# Full suite
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode
```

Reports land under `reports/` (gitignored). Details: [docs/TESTING.md](docs/TESTING.md).

---

## Dev-only tools

| Tool | Notes |
|------|--------|
| **McpInteractionServer** | TCP `127.0.0.1:9090` for AI/tooling live control. Disabled when `COUNTERSPELL_RELEASE=1` or Project Setting `counterspell/release_build`. |
| **InputTrace** | Edge-input ring buffer for anti-cheat audit; same release disable. |
| **MatchConfig** | All gameplay numbers; optional override `user://match_config.json` or `--match-config=<path>`. |

---

## Project layout (high level)

```
scenes/levels/     # test_arena, CTF/CQ maps
scenes/session/    # match_session
scenes/ui/         # menu, lobby, HUD
scenes/player/     # FPS controller
scripts/           # gameplay, match, session, Steam
tests/             # GdUnit4 (mirrors scripts/)
docs/              # PRD, mechanics, plans, RESUME-HERE
addons/            # GodotSteam, netfox, GdUnit4, …
```

---

## Legal

Original IP only. **Not** affiliated with Shadowrun or its rights holders. Use project terms: Resonance, Runners, the Grid, Manifestations, Augments, Repulse, Glide — never Shadowrun trademarks in code, docs, or assets.

---

## Contributing

Prefer small, test-backed changes. Respect netfox tick rules (see `CLAUDE.md` / `docs/superpowers/RESUME-HERE.md`): press-tick inputs, MatchConfig-only tunables, no wall-clock in simulation.

Questions? Open an issue or discussion.
