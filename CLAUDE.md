# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**CounterSpell** — a multiplayer FPS built in Godot 4.7.1 (pinned) with GDScript, distributed via Steam. It is an original-IP *spiritual successor* to the 2007 Shadowrun FPS (guns + magic + cyberware). Current phase: single-player FPS prototype + Steam integration verification; multiplayer (Steam P2P via SteamMultiplayerPeer) comes next.

**IP constraint (critical):** Never use Shadowrun trademarks or protected terminology (no "Shadowrun", "Essence", canonical megacorp names, etc.) in code, docs, or assets. Use this project's original terms: **Resonance** (the core resource), **Runners**, **the Grid**, **Manifestations** (magic), **Augments** (cyber/tech), **Repulse**/**Glide** (signature movement combo). See `docs/PRD.md` §2 and `docs/MECHANICS_REFERENCE.md`.

## Running the Project

There is no build step or linter — the project runs through the Godot editor/binary. On macOS, launch from the app bundle to get full logs:

```bash
# Run the project (main scene: scenes/levels/test_arena.tscn)
/Applications/Godot.app/Contents/MacOS/Godot --path .

# Verbose logs (useful for GDExtension/Steam init issues)
/Applications/Godot.app/Contents/MacOS/Godot --verbose --path .

# Run a specific scene (e.g. the model review grid)
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/dev/model_review.tscn

# Open the editor
/Applications/Godot.app/Contents/MacOS/Godot --editor --path .
```

Steam prerequisites: the Steam client must be running, and `steam_appid.txt` (gitignored, contains `480` — the Spacewar dev App ID) must exist in the project root. The editor must be restarted after installing/updating any GDExtension. If the window crashes on launch, suspect the GodotSteam GDExtension first (try recovery mode, or the `godot-development` skill's debugging workflow).

Spell checking uses cspell (`cspell.config.yaml`); add project-specific terms to `.cspell/custom-dictionary.txt`.

## Scratch Space

Use `.scratch/` (repo-local, gitignored) for all temporary files — downloads, extracted archives, experiment output. Do not use `/tmp` or session scratchpad directories outside the repo; they trigger permission prompts for the user.

## Testing

Tests use **GdUnit4** (`addons/gdUnit4/`) and live in `tests/`, mirroring the `scripts/` layout. See `docs/TESTING.md` for the full reference.

```bash
# Import first on fresh checkouts, then run the suite headless:
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import --quit
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode

# Single suite: pass the test file to -a instead of ./tests
```

- Use **SceneRunner** (`scene_runner(...)` + `simulate_action_press` / `await_input_processed`) for gameplay behavior — see `tests/player/test_fps_controller.gd` for the pattern (it verifies the Repulse + Glide combo via simulated input).
- Gameplay simulation is tick-based under netfox: never use wall-clock time (`Time.get_unix_time_from_system()`) or `_input`-driven state changes in gameplay code — simulation runs in `_rollback_tick`, durations are tick counts. New per-tick state must be registered in `RollbackSynchronizer.state_properties` in `fps_controller.tscn`; new inputs go through `PlayerInput` (`scripts/player/player_input.gd`) and `input_properties`. Two-instance latency E2E: `python3 tests/e2e/net_smoke.py`.
- Controller support is native InputMap: stick look and aim-assist live in `PlayerInput` (`look_rate_scale`); the contextual A button (jump → glide airborne) is a `_rollback_tick` rule in `FPSController`. New input actions must also get joypad events per the MECHANICS_REFERENCE §11 layout.
- All gameplay numbers come from the `MatchConfig` autoload (`scripts/config/match_config.gd`) — never hard-code a tunable. Add new keys to `DEFAULTS` and record baselines in `docs/ABILITY_TUNING_SHEET.md`. Host overrides: `user://match_config.json` or `--match-config=<path>`.
- Edge-triggered inputs are **press-tick ints**, never latched bools: netfox reuses the last gathered input for every tick in a catch-up batch, so a bool press multi-fires. Stamp `<action>_press_tick = NetworkTime.tick` in `PlayerInput._gather` and compare `input.<action>_press_tick == tick` in simulation.
- Weapons follow the `WeaponBase` pipeline (`scripts/weapons/`): a `RewindableAction` child decides firing in `_rollback_tick`; behavior differences go in the `_wants_fire`/`_shot_directions`/`_weapon_tick`/`_on_fire_tick` overrides. A new weapon = new script + scene node under `WeaponRig` (+ `FireAction` child) + MatchConfig `weapon.<key>.*` keys + state-property registration in `fps_controller.tscn`. Simulation randomness is always seeded per (tick, peer, index) — never `randf()`. Collision layers: 1 world, 2 hit zones, 4 player bodies; weapon rays use mask 1|2.
- Headless runs have no Steam client; tests must tolerate failed Steam init.
- Reports go to `reports/` (gitignored). Exit code is non-zero on failure.
- The `godot` MCP server (`.mcp.json`, project scope) provides live-game interaction: run the project, then use `game_input_action` / `game_key_press` / `game_eval` / `game_get_property` / `game_screenshot` etc. to drive and inspect it. The game-side half is the `McpInteractionServer` autoload (`scripts/dev/mcp_interaction_server.gd`, TCP on 127.0.0.1:9090 — dev only, must not ship in release builds). The Node server is vendored gitignored at `tools/godot-mcp/`; rebuild with `npm install && npm run build` there. See `docs/TESTING.md`.

## Architecture

- **`scripts/steamworks.gd`** — the `SteamManager` autoload (registered in `project.godot`). The GodotSteam GDExtension (`addons/godotsteam/`) auto-registers the global `Steam` class; this autoload only wraps initialization (`steamInitEx(480)`, status 0 = success), pumps `Steam.run_callbacks()` every frame, and exposes helpers (rich presence, achievements). Other code reaches it via `/root/SteamManager` and the `steam_initialized(success, response)` signal — see `scenes/levels/steam_status.gd` for the pattern. Steam auto-init is disabled in `project.godot` (`[steam]` section); the autoload has explicit control.
- **`scripts/player/fps_controller.gd`** — `FPSController` (CharacterBody3D + Camera3D child). Written local-first but already gated on `is_multiplayer_authority()` everywhere in preparation for multiplayer; keep new player code following that pattern. Implements movement, hitscan fire, and the signature **Repulse + Glide launch combo** (down-aimed Repulse followed by Glide within `combo_window` triggers a vertical launch).
- **`scenes/dev/` + `scripts/dev/`** — dev-only tooling (e.g. `model_review.tscn` lays out the placeholder GLBs in `models/placeholders/` for art review). `models/placeholders/` is temporary CC0 Quaternius art; keep `ATTRIBUTION.md` accurate if models change.
- Input actions (`move_*`, `jump`, `sprint`, `fire_primary`, `repulse`, `glide`, `toggle_mouse`) are defined in `project.godot`. Renderer is GL Compatibility.

## Docs Workflow

Gameplay numbers flow through a defined pipeline — respect it when changing tuning values:

0. **`docs/ideas/`** — future-consideration designs, one file per idea (owner spec + system interactions + research notes). Not commitments; promote to MECHANICS_REFERENCE via owner decisions.
1. **`docs/ABILITY_TUNING_SHEET.md`** — active scratch pad; experiment and record playtest notes here.
2. **`docs/MECHANICS_REFERENCE.md`** — promoted, team-decided design (add a Promotion Log entry when promoting values from the tuning sheet).
3. **`docs/PRD.md`** — vision, roadmap, phases; update only when scope/vision changes.

Ability values in code are `@export` variables (see `FPSController`) specifically so they can be tuned against the tuning sheet — keep new abilities tunable the same way.

## Conventions

- GDScript with typed declarations (`:=`, typed params/returns) and `class_name` for reusable classes.
- Never commit `steam_appid.txt` or `.godot/`; `exports/` is gitignored build output.
- Docs standardize on Godot 4.7.1 (pinned); if the pinned engine version changes, update `docs/SETUP.md`.
