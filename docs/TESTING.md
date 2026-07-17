# Testing Strategy & Tooling Reference

**Project:** CounterSpell
**Date researched:** 2026-07-14
**Status:** GdUnit4 v6.1.3 INSTALLED (`addons/gdUnit4/`, enabled in `project.godot`);
first suite passing at `tests/player/test_fps_controller.gd`. godot-mcp
(tugcantopaloglu fork) INSTALLED for live-game interaction (see MCP section).

## Framework Survey (GDScript, Godot 4)

### GdUnit4 — CHOSEN
- Repo: https://github.com/godot-gdunit-labs/gdUnit4
- Godot 4.3+ only. Embedded test inspector in the editor, automatic test
  discovery, mocking + spying, JUnit XML and HTML reports.
- **SceneRunner** (the reason we chose it): loads a scene inside a test and
  drives it with simulated input — `simulate_action_press("glide")`,
  `simulate_key_pressed`, mouse move/click helpers, physics frame stepping,
  `await_input_processed()`.
  - Actions docs: https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/scene_runner/actions/
  - Mouse docs: https://mikeschulze.github.io/gdUnit4/advanced_testing/scene_runner/mouse/
- Ideal for timing-sensitive mechanics like the Repulse + Glide launch combo:
  load `fps_controller.tscn`, simulate down-aimed `repulse` then `glide`
  within `combo_window`, step frames, assert `velocity.y`.

### GUT (Godot Unit Test) — runner-up
- Repo: https://github.com/bitwes/Gut (9.x targets Godot 4.x)
- Lighter weight. Doubles/stubs/spies, `InputSender` for input simulation,
  JUnit XML output. Fine choice, but GdUnit4's SceneRunner and editor
  integration won for this project.

### Others (not adopted)
- **GodotTestDriver** — integration-test driver API (simulate input, await
  frames, UI interaction): https://github.com/derkork/godot-test-driver
- **C# only** (irrelevant while we are GDScript-only): gdUnit4Net,
  Chickensoft GoDotTest, GodotXUnit.
- **WAT** — effectively abandoned; do not use.

## Running Tests

```bash
# 1. Warm the import cache (required on fresh checkouts / CI)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import --quit

# 2. Run the GdUnit4 suite headless (GODOT_BIN is required by the CLI tool)
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode

# Run a single suite: pass the file instead of the directory
#   ... GdUnitCmdTool.gd -a ./tests/player/test_fps_controller.gd --ignoreHeadlessMode

# Or run from the editor: GdUnit4 inspector panel (bottom dock) > Run.
```

Reports land in `reports/` (gitignored): JUnit XML + HTML per run.

Notes:
- Tests live in `tests/`, mirroring `scripts/` structure
  (e.g. `tests/player/test_fps_controller.gd`).
- Headless runs have no Steam client; anything touching `SteamManager` must
  tolerate failed Steam init (the autoload already degrades gracefully).
- Gameplay/physics simulates fine headless — no rendering required.
- CI pattern (GitHub Actions): import step, then headless test step.
  References: https://saltares.com/run-automated-tests-for-your-godot-game-on-ci/
  and https://helpmetest.com/blog/godot-ci-cd-testing/

## Live-Game Interaction (MCP servers)

Lets AI tooling (Claude Code etc.) launch the editor/game, feed inputs, read
errors, and inspect state while the game runs.

- **tugcantopaloglu/godot-mcp — INSTALLED**:
  https://github.com/tugcantopaloglu/godot-mcp (free, MIT, Godot 4.4+,
  tested through 4.7). 157 tools including full runtime game interaction:
  `game_key_press`, `game_click`, `game_input_action`, `game_eval` (arbitrary
  GDScript in the running game), `game_get/set_property`, `game_call_method`,
  `game_screenshot`, `game_pause`, `game_wait`.
  - **Server**: vendored (gitignored) at `tools/godot-mcp/`; rebuild with
    `cd tools/godot-mcp && npm install && npm run build` (Node >= 18).
  - **Godot side**: `scripts/dev/mcp_interaction_server.gd` (copied from
    `tools/godot-mcp/build/scripts/`, committed) is registered as the
    `McpInteractionServer` autoload. It opens a TCP command server on
    `127.0.0.1:9090` while the game runs.
  - **Claude Code**: configured at project scope in `.mcp.json`
    (`node tools/godot-mcp/build/index.js`, `GODOT_PATH` env set).
  - TODO before any public/release build: strip or feature-flag the
    `McpInteractionServer` autoload — it is dev tooling and must not ship.
- **GDAI MCP plugin — considered, not adopted**: https://gdaimcp.com/
  Polished editor plugin with runtime input, but paid ($19 one-time) and
  covered by the free option above.
- **PurpleJelly Godot-MCP — deferred**: https://purplejelly.itch.io/godot-mcp
  No runtime input, but adds true breakpoints and step debugging
  (pay-what-you-want, Godot 4.3+). Adopt if we need interactive debugging
  beyond `game_eval`/property inspection.
- Also surveyed: https://github.com/Coding-Solo/godot-mcp (the original:
  run project, capture debug output; no runtime input).

Fallback without MCP: run the game from a shell, capture stdout (scripts
`print` hits, Repulse casts, combo launches), kill after a timeout.
