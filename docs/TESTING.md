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

## Netcode Testing (netfox)

Gameplay simulation runs on netfox's tick loop, which changes how tests are
written:

- **Start/stop the loop per test:** `NetworkTime.start()` in `before_test`,
  `NetworkTime.stop()` in `after_test` (see `tests/player/`). The "offline
  peer" warning is expected in tests.
- **Effects land on network ticks, not frames.** After injecting input,
  `await runner.simulate_frames(N)` (or `await_millis`) before asserting.
- **Edge-triggered input in tests:** use `Input.action_press("x")`, hold it
  across a few simulated frames, then `Input.action_release("x")`. A press
  released after a single frame can slip between the scene's `_process`
  callbacks and never be observed. (`PlayerInput` latches edges from polled
  state transitions, not `is_action_just_pressed`, for the same reason.)
- **Rollback state resists external mutation:** `transform`/`velocity` etc.
  are restored from recorded state each tick, so `game_eval` teleports are
  overwritten. Drive the game through inputs instead (jump, then glide).
  Exception: mutations made synchronously right after spawning a scene (before
  its first tick) stick — the first recorded state captures them. Tests rely
  on this for archetype/health setup.
- **Config-driven mechanics:** override tunables with
  `MatchConfig.set_value(...)` inside the test and call
  `MatchConfig.reset_to_defaults()` in `after_test`.
- **Edge inputs are press-tick ints** (`<action>_press_tick`), not bools —
  see CLAUDE.md. In tests, hold `Input.action_press(...)` across a few
  simulated frames before releasing so `PlayerInput._process` observes the
  transition.
- **MCP input:** prefer the action form of `key_press`
  (`{"action": "glide", "pressed": true/false}`) — raw key events are
  auto-released after one frame and can collapse into a single buffered
  flush that gameplay code never sees.

### Two-instance E2E (simulated latency)

```bash
python3 tests/e2e/net_smoke.py                    # 50 ms latency default
NET_TEST_LATENCY_MS=100 python3 tests/e2e/net_smoke.py
```

The driver launches `scenes/dev/net_test.tscn` twice: the first instance
hosts on 127.0.0.1:9999 (netfox `NetworkSimulator` autoconnect), the second
joins through a UDP latency proxy on port 10000. Each instance exposes an
MCP control server (`GODOT_MCP_PORT` 9191/9192); the driver moves and glides
the client's player and asserts the host observes it. Caveats:

- The `NetworkSimulator` self-disables when `CI`, `NETFOX_CI`, or
  `NETFOX_NO_AUTOCONNECT` is non-empty — the driver clears them for its
  child processes. Keep them cleared in any CI job that runs the E2E.
- The netfox.extras plugin re-registers the `NetworkSimulator` autoload on
  every editor load, so that autoload is THE simulator — never add a second
  `NetworkSimulator` node to a scene. Two simulators in one process race for
  the host port and the loser overwrites `multiplayer.multiplayer_peer` with
  a dangling client peer. `net_test.gd` configures the autoload via
  `ProjectSettings.set_setting()` in `_enter_tree` and connects its signals.
- `net_test.gd` connects `server_created` deferred: the simulator emits it
  before assigning `multiplayer.multiplayer_peer`.
