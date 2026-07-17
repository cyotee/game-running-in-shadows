# Netfox Integration (Milestone A: Predicted Core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the FPS controller on netfox's predicted tick loop so all future mechanics are network-ready, verified by unit tests and a two-instance simulated-latency E2E test.

**Architecture:** netfox v1.35.3 (vendored addon) provides a network tick loop (`NetworkTime`), rollback simulation (`NetworkRollback` + `RollbackSynchronizer`), and display smoothing (`TickInterpolator`). The FPS controller's movement and abilities move from `_physics_process`/`_input` into `_rollback_tick(delta, tick, is_fresh)`, consuming input from a new `PlayerInput` node (a netfox `BaseNetInput`). All timing becomes tick-based (no wall-clock). A dev scene using netfox's `NetworkSimulator` runs host + client instances on localhost with injected latency for E2E verification via the godot-mcp TCP protocol.

**Tech Stack:** Godot 4.7.1 (GDScript), netfox v1.35.3 (netfox + netfox.internals + netfox.extras), GdUnit4 v6.1.3, godot-mcp interaction server (TCP JSON), Python 3 (E2E driver).

## Global Constraints

- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (4.7.1). All headless commands use `--path .` from the repo root `/Users/cyotee/Development/github-cyotee/game-running-in-shadows`.
- netfox version: **v1.35.3 exactly** (verified API below). Vendor into `addons/`; committed (MIT license).
- Test command (run after every task):
  `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode`
  Expected on success: `Exit code: 0` and `0 errors | 0 failures`.
- **Tick-based gameplay rule (enforced from this plan onward):** gameplay code must never use `Time.get_unix_time_from_system()` or frame-based `is_action_just_pressed` inside simulation; durations are tick counts; per-tick state lives in properties registered with `RollbackSynchronizer`.
- GDScript style: typed declarations (`:=`, typed params/returns), tabs for indentation (match existing files).
- IP terms: use project vocabulary only (Resonance, Manifestations, Augments, Repulse, Glide) — never Shadowrun terminology.
- Commits end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- `@export` tunables must keep their names/semantics where possible (they are referenced by `docs/ABILITY_TUNING_SHEET.md`).

## Verified netfox v1.35.3 API facts (do not re-derive; verified 2026-07-15 against release zips)

- Release assets: `netfox.v1.35.3.zip` (core), `netfox.extras.v1.35.3.zip` (bundles core + `netfox.internals` + `netfox.extras`). Both unzip to a versioned folder containing `addons/`.
- Autoloads (added manually to `project.godot`; the editor plugin adds these same five when enabled via UI): `NetworkTime` → `res://addons/netfox/network-time.gd`, `NetworkTimeSynchronizer` → `res://addons/netfox/network-time-synchronizer.gd`, `NetworkRollback` → `res://addons/netfox/rollback/network-rollback.gd`, `NetworkEvents` → `res://addons/netfox/network-events.gd`, `NetworkPerformance` → `res://addons/netfox/network-performance.gd` — **in that order**.
- `RollbackSynchronizer` (`res://addons/netfox/rollback/rollback-synchronizer.gd`): exports `root: Node`, `enable_prediction: bool = false`, `state_properties: Array[String]`, `input_properties: Array[String]`, `enable_input_broadcast: bool = true`. Call `process_settings()` after changing authority.
- Rollback calls `_rollback_tick(delta: float, tick: int, is_fresh: bool)` on nodes under `root` that have the method.
- `TickInterpolator` (`res://addons/netfox/tick-interpolator.gd`): exports `root: Node`, `enabled := true`, `properties: Array[String]`, `record_first_state := true`, `enable_recording := true`.
- `BaseNetInput` (`res://addons/netfox.extras/base-net-input.gd`): `class_name BaseNetInput extends Node`; override `_gather()`; it runs on `NetworkTime.before_tick_loop` only when `is_multiplayer_authority()`.
- `NetworkTime`: `start()`, `stop()`, `tickrate` (from project setting `netfox/time/tickrate`, default 30), read-only `physics_factor`, signals `before_tick_loop`, `on_tick(delta, tick)`, `after_tick_loop`.
- CharacterBody3D pattern (from netfox docs, encoded in `network-time.gd` comments): multiply `velocity` by `NetworkTime.physics_factor` before `move_and_slide()`, divide after; force-update `is_on_floor()` at tick start by running `move_and_slide()` with zero velocity.
- `NetworkSimulator` (`res://addons/netfox.extras/network-simulator.gd`, extends Node, **no class_name**): in `_ready` it (1) disables itself when `not OS.has_feature("editor")` — running via the editor binary, including `--headless`, keeps this feature ON; (2) overwrites its vars from ProjectSettings: `netfox/autoconnect/enabled` (bool, default false), `netfox/autoconnect/host`, `netfox/autoconnect/port` (default 9999), `netfox/autoconnect/use_compression`, `netfox/autoconnect/simulated_latency_ms`; (3) self-disables when env `CI`, `NETFOX_CI`, or `NETFOX_NO_AUTOCONNECT` is non-empty; (4) tries to host on the port, and if `ERR_CANT_CREATE` (port taken) joins as client instead — first instance hosts, later instances join. Latency > 0 runs a UDP proxy on `port + 1`. Signals: `server_created`, `client_connected`.
- Configure `NetworkSimulator` **via `ProjectSettings.set_setting()` in the parent scene root's `_enter_tree()`** (runs before the child's `_ready` reads the settings). Runtime `set_setting` affects only that process — do not persist these to `project.godot`.

## File Structure

- `addons/netfox/`, `addons/netfox.internals/`, `addons/netfox.extras/` — vendored netfox (Task 1)
- `project.godot` — netfox autoloads, plugin enables, `netfox/time/tickrate` (Task 1)
- `scripts/player/player_input.gd` — NEW: `PlayerInput` (BaseNetInput); gathers per-tick input (Task 2)
- `scripts/player/fps_controller.gd` — REWRITE: `_rollback_tick`-driven movement + abilities (Tasks 3–4)
- `scenes/player/fps_controller.tscn` — add `Input`, `RollbackSynchronizer`, `TickInterpolator` nodes (Task 3)
- `scenes/levels/test_arena.tscn` + `scripts/levels/test_arena.gd` — NEW root script: offline `NetworkTime.start()` (Task 5)
- `scripts/dev/mcp_interaction_server.gd` — MODIFY: port from `GODOT_MCP_PORT` env (Task 6)
- `scenes/dev/net_test.tscn` + `scripts/dev/net_test.gd` — NEW: two-instance latency harness (Task 7)
- `tests/player/test_player_input.gd` — NEW (Task 2)
- `tests/player/test_fps_controller.gd` — REWRITE tick-based (Tasks 3–4)
- `tests/e2e/net_smoke.py` — NEW: E2E driver (Task 7)
- `docs/TESTING.md`, `CLAUDE.md`, `docs/PRD.md`, `docs/ABILITY_TUNING_SHEET.md`, `.cspell/custom-dictionary.txt` — docs pass (Task 8)

---

### Task 1: Vendor netfox v1.35.3 and wire project configuration

**Files:**
- Create: `addons/netfox/`, `addons/netfox.internals/`, `addons/netfox.extras/` (vendored)
- Modify: `project.godot` (autoload section, editor_plugins, netfox settings)

**Interfaces:**
- Produces: `NetworkTime`, `NetworkRollback` etc. autoloads available at `/root/NetworkTime`, ...; `RollbackSynchronizer`, `TickInterpolator`, `BaseNetInput` classes usable from scripts/scenes. Tick rate = 60.

- [ ] **Step 1: Download and extract both release zips**

```bash
cd /Users/cyotee/Development/github-cyotee/game-running-in-shadows
rm -rf .scratch/netfox-vendor && mkdir -p .scratch/netfox-vendor && cd .scratch/netfox-vendor
curl -sL -O https://github.com/foxssake/netfox/releases/download/v1.35.3/netfox.v1.35.3.zip
curl -sL -O https://github.com/foxssake/netfox/releases/download/v1.35.3/netfox.extras.v1.35.3.zip
unzip -q netfox.v1.35.3.zip && unzip -q netfox.extras.v1.35.3.zip
ls netfox.v1.35.3/addons netfox.extras.v1.35.3/addons
```

(`.scratch/` is the repo-local scratch space, gitignored — use it instead of `/tmp` for all temporary files.)

Expected: `netfox.v1.35.3/addons` contains `netfox`; `netfox.extras.v1.35.3/addons` contains `netfox`, `netfox.extras`, `netfox.internals`.

- [ ] **Step 2: Copy the three addons into the project**

```bash
cd /Users/cyotee/Development/github-cyotee/game-running-in-shadows
cp -R .scratch/netfox-vendor/netfox.v1.35.3/addons/netfox addons/
cp -R .scratch/netfox-vendor/netfox.extras.v1.35.3/addons/netfox.internals addons/
cp -R .scratch/netfox-vendor/netfox.extras.v1.35.3/addons/netfox.extras addons/
ls addons/
```

Expected: `addons/` now lists `gdUnit4  godotsteam  netfox  netfox.extras  netfox.internals`.

- [ ] **Step 3: Edit `project.godot`**

In the `[autoload]` section, append after the existing entries (order matters — NetworkTime first):

```ini
NetworkTime="*res://addons/netfox/network-time.gd"
NetworkTimeSynchronizer="*res://addons/netfox/network-time-synchronizer.gd"
NetworkRollback="*res://addons/netfox/rollback/network-rollback.gd"
NetworkEvents="*res://addons/netfox/network-events.gd"
NetworkPerformance="*res://addons/netfox/network-performance.gd"
```

Change the `[editor_plugins]` line to include all three netfox plugins:

```ini
enabled=PackedStringArray("res://addons/godotsteam/plugin.cfg", "res://addons/gdUnit4/plugin.cfg", "res://addons/netfox.internals/plugin.cfg", "res://addons/netfox/plugin.cfg", "res://addons/netfox.extras/plugin.cfg")
```

Add a new section (60 tps for FPS responsiveness; default is 30):

```ini
[netfox]

time/tickrate=60
```

- [ ] **Step 4: Reimport and boot-check headless**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import --quit 2>&1 | grep -icE 'SCRIPT ERROR|Parse Error' || true
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 30 2>&1 | grep -iE 'error|netfox' | head -20
```

Expected: `0` from the first command; second command shows no `SCRIPT ERROR` lines (Steam init warning is normal; netfox logger lines are fine).

- [ ] **Step 5: Verify autoloads exist at runtime**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120 2>&1 >/dev/null &
sleep 4
python3 - <<'EOF'
import socket, json
s = socket.create_connection(("127.0.0.1", 9090), timeout=5); f = s.makefile("r")
s.sendall((json.dumps({"id":1,"command":"eval","params":{"code":"return [get_tree().root.has_node('NetworkTime'), get_tree().root.has_node('NetworkRollback'), NetworkTime.tickrate]"}})+"\n").encode())
print(json.loads(f.readline())); s.close()
EOF
```

Expected: `'result': [True, True, 60.0]` (or `60`), `'success': True`.

- [ ] **Step 6: Run the existing test suite (must stay green — old controller untouched)**

Run the Global Constraints test command. Expected: `5 test cases | 0 errors | 0 failures`, `Exit code: 0`.

- [ ] **Step 7: Commit**

```bash
git add addons/netfox addons/netfox.internals addons/netfox.extras project.godot
git commit -m "feat: vendor netfox v1.35.3 and register autoloads at 60 tps

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: PlayerInput node (per-tick input gathering)

**Files:**
- Create: `scripts/player/player_input.gd`
- Test: `tests/player/test_player_input.gd`

**Interfaces:**
- Consumes: `BaseNetInput` (Task 1), input actions from `project.godot` (`move_*`, `jump`, `sprint`, `fire_primary`, `repulse`, `glide`, `toggle_mouse`).
- Produces: `class_name PlayerInput extends BaseNetInput` with networked per-tick properties `movement: Vector2`, `aim_yaw: float`, `aim_pitch: float`, `jump: bool`, `sprint: bool`, `repulse: bool`, `glide: bool`, `fire: bool`; local-only `local_yaw: float`, `local_pitch: float`, `mouse_sensitivity: float`. Tasks 3–4 read these from `_rollback_tick`; the scene registers them as `Input:<name>` input properties.

- [ ] **Step 1: Write the failing test**

Create `tests/player/test_player_input.gd`:

```gdscript
# GdUnit4 test suite for PlayerInput (netfox BaseNetInput).
class_name TestPlayerInput
extends GdUnitTestSuite

var _input: PlayerInput


func before_test() -> void:
	_input = auto_free(PlayerInput.new())
	add_child(_input)
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()


func test_gathers_movement_and_sprint() -> void:
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await await_millis(100)

	assert_float(_input.movement.y).is_less(0.0)
	assert_bool(_input.sprint).is_true()

	Input.action_release("move_forward")
	Input.action_release("sprint")


func test_latches_edge_actions_until_next_tick() -> void:
	Input.action_press("glide")
	Input.action_release("glide")
	await await_millis(100)
	# The press happened between ticks; the latch must have delivered it
	# on exactly one subsequent tick, then cleared.
	assert_bool(_input.glide).is_false()

	Input.action_press("repulse")
	await await_millis(100)
	Input.action_release("repulse")
	assert_bool(_input._pending_repulse).is_false()


func test_gather_snapshots_local_aim() -> void:
	_input.local_yaw = 1.5
	_input.local_pitch = -0.8
	await await_millis(100)

	assert_float(_input.aim_yaw).is_equal_approx(1.5, 0.001)
	assert_float(_input.aim_pitch).is_equal_approx(-0.8, 0.001)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/player/test_player_input.gd --ignoreHeadlessMode
```

Expected: FAIL — parse error / unknown class `PlayerInput`.

- [ ] **Step 3: Write the implementation**

Create `scripts/player/player_input.gd`:

```gdscript
# Per-tick input gathering for the FPS controller (netfox BaseNetInput).
# Networked properties below are registered as RollbackSynchronizer
# input_properties ("Input:<name>") in fps_controller.tscn.
# Edge-triggered actions are latched in _process so presses between network
# ticks are never lost, and consumed on exactly one tick by _gather().
class_name PlayerInput
extends BaseNetInput

@export var mouse_sensitivity: float = 0.0025

# --- Networked per-tick input ---
var movement: Vector2 = Vector2.ZERO
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0
var jump: bool = false
var sprint: bool = false
var repulse: bool = false
var glide: bool = false
var fire: bool = false

# --- Local-only view state (never rolled back) ---
var local_yaw: float = 0.0
var local_pitch: float = 0.0

var _pending_jump: bool = false
var _pending_repulse: bool = false
var _pending_glide: bool = false
var _pending_fire: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		local_yaw = wrapf(local_yaw - event.relative.x * mouse_sensitivity, -PI, PI)
		local_pitch = clampf(local_pitch - event.relative.y * mouse_sensitivity, -PI / 2.0, PI / 2.0)
	if event.is_action_pressed("toggle_mouse"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_pending_jump = _pending_jump or Input.is_action_just_pressed("jump")
	_pending_repulse = _pending_repulse or Input.is_action_just_pressed("repulse")
	_pending_glide = _pending_glide or Input.is_action_just_pressed("glide")
	_pending_fire = _pending_fire or Input.is_action_just_pressed("fire_primary")


func _gather() -> void:
	movement = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	sprint = Input.is_action_pressed("sprint")
	aim_yaw = local_yaw
	aim_pitch = local_pitch
	jump = _pending_jump
	repulse = _pending_repulse
	glide = _pending_glide
	fire = _pending_fire
	_pending_jump = false
	_pending_repulse = false
	_pending_glide = false
	_pending_fire = false
```

- [ ] **Step 4: Run test to verify it passes**

Same command as Step 2. Expected: `3 test cases | 0 errors | 0 failures`, `Exit code: 0`.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/player_input.gd tests/player/test_player_input.gd
git commit -m "feat: add PlayerInput tick-based input gathering node

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: FPS controller movement on the rollback tick

**Files:**
- Modify: `scripts/player/fps_controller.gd` (full rewrite)
- Modify: `scenes/player/fps_controller.tscn` (add Input / RollbackSynchronizer / TickInterpolator)
- Modify: `tests/player/test_fps_controller.gd` (full rewrite; ability tests return in Task 4)

**Interfaces:**
- Consumes: `PlayerInput` (Task 2, exact property names), netfox `RollbackSynchronizer`/`TickInterpolator` (Task 1).
- Produces: `FPSController` with `_rollback_tick(delta: float, tick: int, is_fresh: bool)`; members `input: PlayerInput` (`$Input`), `camera: Camera3D`, rollback state `is_gliding: bool`, `glide_ticks_remaining: int`, `last_down_repulse_tick: int`; methods `_cast_repulse(tick: int, is_fresh: bool)` and `_try_deploy_glide(tick: int)` are **stubs in this task** (empty bodies) — Task 4 fills them. Scene node names: `Input`, `Camera3D`, `RollbackSynchronizer`, `TickInterpolator`, `CollisionShape3D`, `Camera3D/WeaponSocket`.

- [ ] **Step 1: Rewrite the test suite for tick-based movement (failing first)**

Replace the entire contents of `tests/player/test_fps_controller.gd` with:

```gdscript
# GdUnit4 test suite for FPSController (netfox rollback tick version).
# NetworkTime runs during each test; effects land on network ticks, so tests
# await real frames after injecting input.
class_name TestFPSController
extends GdUnitTestSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"

const PITCH_DOWN := -0.8
const PITCH_LEVEL := 0.0


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()


func _spawn_controller() -> GdUnitSceneRunner:
	var runner := scene_runner(CONTROLLER_SCENE)
	return runner


func test_spawns_with_defaults() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	assert_bool(controller.is_gliding).is_false()
	assert_float(controller.walk_speed).is_greater(0.0)
	assert_float(controller.combo_launch_velocity).is_greater(controller.jump_velocity)


func test_moves_forward_on_input() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	var start_z := controller.global_position.z

	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(30)
	runner.simulate_action_release("move_forward")

	assert_float(controller.global_position.z).is_less(start_z - 0.2)


func test_sprint_is_faster_than_walk() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(30)
	var walk_dz := absf(controller.global_position.z)

	controller.global_position = Vector3.ZERO
	controller.velocity = Vector3.ZERO
	runner.simulate_action_press("sprint")
	await runner.simulate_frames(30)
	runner.simulate_action_release("sprint")
	runner.simulate_action_release("move_forward")

	assert_float(absf(controller.global_position.z)).is_greater(walk_dz)


func test_yaw_input_rotates_body() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	controller.input.local_yaw = 0.9
	await runner.simulate_frames(5)

	assert_float(controller.rotation.y).is_equal_approx(0.9, 0.05)
```

- [ ] **Step 2: Run to verify it fails**

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/player/test_fps_controller.gd --ignoreHeadlessMode
```

Expected: FAIL (controller has no `input` member; movement not tick-driven).

- [ ] **Step 3: Rewrite `scripts/player/fps_controller.gd`**

Replace the entire file with:

```gdscript
# FPSController — netfox predicted movement.
# All simulation runs in _rollback_tick; input comes from the PlayerInput
# child node; per-tick state is registered in RollbackSynchronizer
# (see fps_controller.tscn). Values are tunable via @export for the
# Ability Tuning Sheet.
class_name FPSController
extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 7.5
@export var acceleration: float = 20.0

# --- Repulse & Glide (tuning sheet values) ---
@export var repulse_strength: float = 22.0
@export var repulse_range: float = 10.0
@export var glide_duration: float = 4.0
@export var glide_gravity_mult: float = 0.25
@export var glide_speed: float = 4.0
@export var glide_air_control: float = 30.0
@export var combo_launch_velocity: float = 28.0
@export var combo_window: float = 0.7

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Rollback state (registered as state_properties) ---
var is_gliding: bool = false
var glide_ticks_remaining: int = 0
var last_down_repulse_tick: int = -(1 << 30)

@onready var input: PlayerInput = $Input
@onready var camera: Camera3D = $Camera3D
@onready var rollback_synchronizer: RollbackSynchronizer = $RollbackSynchronizer


func _ready() -> void:
	# Input authority may have been reassigned by a spawner before _ready.
	rollback_synchronizer.process_settings()
	var is_local := input.is_multiplayer_authority()
	camera.current = is_local
	if is_local and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	# Camera pitch is view-only (never rolled back); yaw is applied to the
	# body in _rollback_tick from recorded input.
	if input.is_multiplayer_authority():
		camera.rotation.x = input.local_pitch


func _rollback_tick(delta: float, tick: int, is_fresh: bool) -> void:
	transform.basis = Basis(Vector3.UP, input.aim_yaw)
	_force_update_is_on_floor()

	if input.repulse:
		_cast_repulse(tick, is_fresh)
	if input.glide and not is_gliding:
		_try_deploy_glide(tick)

	var speed := sprint_speed if input.sprint else walk_speed
	var direction := (transform.basis * Vector3(input.movement.x, 0, input.movement.y)).normalized()

	if is_gliding:
		glide_ticks_remaining -= 1
		# Cancel when landing (not while launching upward off the ground).
		if glide_ticks_remaining <= 0 or (is_on_floor() and velocity.y <= 0.01):
			is_gliding = false
		else:
			velocity.y -= gravity * delta * glide_gravity_mult
			if direction:
				velocity.x = move_toward(velocity.x, direction.x * glide_speed, glide_air_control * delta)
				velocity.z = move_toward(velocity.z, direction.z * glide_speed, glide_air_control * delta)
			velocity.y = maxf(velocity.y, -6.0)
			if input.jump:
				velocity.y = maxf(velocity.y + 9.0, 9.0)
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta
		if input.jump and is_on_floor():
			velocity.y = jump_velocity
		var target := direction * speed
		velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	if input.fire and is_fresh:
		_try_shoot()

	# netfox CharacterBody3D pattern: move_and_slide assumes engine delta.
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor


# move_and_slide is what updates is_on_floor; run it with zero velocity so
# floor state is correct at the start of each (re-)simulated tick.
func _force_update_is_on_floor() -> void:
	var old_velocity := velocity
	velocity = Vector3.ZERO
	move_and_slide()
	velocity = old_velocity


func _try_shoot() -> void:
	var space_state := get_world_3d().direct_space_state
	var from := camera.global_position
	var aim := Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)
	var to := from + (aim * Vector3.FORWARD) * 100.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)

	if result:
		print("Hit: ", result.collider.name if result.collider else "something", " at ", result.position)
	else:
		print("Shot fired (miss)")


# --- Abilities (implemented in Task 4) ---

func _cast_repulse(_tick: int, _is_fresh: bool) -> void:
	pass


func _try_deploy_glide(_tick: int) -> void:
	pass
```

- [ ] **Step 4: Rewrite `scenes/player/fps_controller.tscn`**

Replace the entire file with:

```
[gd_scene load_steps=6 format=3 uid="uid://fpscontrollerstub"]

[ext_resource type="Script" path="res://scripts/player/fps_controller.gd" id="1_stub"]
[ext_resource type="Script" path="res://scripts/player/player_input.gd" id="2_input"]
[ext_resource type="Script" path="res://addons/netfox/rollback/rollback-synchronizer.gd" id="3_rbs"]
[ext_resource type="Script" path="res://addons/netfox/tick-interpolator.gd" id="4_ti"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_1"]
height = 1.8
radius = 0.4

[node name="FPSController" type="CharacterBody3D"]
script = ExtResource("1_stub")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("CapsuleShape3D_1")

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.6, 0)

[node name="WeaponSocket" type="Node3D" parent="Camera3D"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.3, -0.3, -0.8)

[node name="Input" type="Node" parent="."]
script = ExtResource("2_input")

[node name="RollbackSynchronizer" type="Node" parent="."]
script = ExtResource("3_rbs")
root = NodePath("..")
state_properties = Array[String]([":transform", ":velocity", ":is_gliding", ":glide_ticks_remaining", ":last_down_repulse_tick"])
input_properties = Array[String](["Input:movement", "Input:aim_yaw", "Input:aim_pitch", "Input:jump", "Input:sprint", "Input:repulse", "Input:glide", "Input:fire"])

[node name="TickInterpolator" type="Node" parent="."]
script = ExtResource("4_ti")
root = NodePath("..")
properties = Array[String]([":transform"])
```

- [ ] **Step 5: Run the movement tests**

Same command as Step 2. Expected: `4 test cases | 0 errors | 0 failures`, `Exit code: 0`.
If `test_moves_forward_on_input` fails with zero movement, debug order: (1) confirm `NetworkTime` ticks (add `print(NetworkTime.tick)` temporarily), (2) confirm `_gather` ran (input authority is 1 offline), (3) confirm `_rollback_tick` is invoked (RollbackSynchronizer `root` path).

- [ ] **Step 6: Run the FULL suite (PlayerInput suite must stay green)**

Run the Global Constraints test command. Expected: `7 test cases | 0 errors | 0 failures` (4 controller + 3 input), `Exit code: 0`.

- [ ] **Step 7: Commit**

```bash
git add scripts/player/fps_controller.gd scenes/player/fps_controller.tscn tests/player/test_fps_controller.gd
git commit -m "feat: rebuild FPS controller movement on netfox rollback tick

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Tick-based Repulse, Glide, and the launch combo

**Files:**
- Modify: `scripts/player/fps_controller.gd` (fill `_cast_repulse` / `_try_deploy_glide`)
- Modify: `tests/player/test_fps_controller.gd` (append ability tests)

**Interfaces:**
- Consumes: Task 3's controller (`input.aim_pitch`, `input.aim_yaw`, state vars, `_rollback_tick` call sites already in place).
- Produces: working `_cast_repulse(tick: int, is_fresh: bool)` and `_try_deploy_glide(tick: int)`; combo semantics: down-aimed (`aim_pitch < -0.65`) Repulse records `last_down_repulse_tick`; Glide within `combo_window` seconds worth of ticks while aiming below `-0.4` sets `velocity.y = combo_launch_velocity`.

- [ ] **Step 1: Append the failing ability tests**

Append to `tests/player/test_fps_controller.gd`:

```gdscript
func test_glide_without_combo_gives_no_launch() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.input.local_pitch = PITCH_DOWN

	runner.simulate_action_press("glide")
	await runner.simulate_frames(5)

	assert_bool(controller.is_gliding).is_true()
	assert_float(controller.velocity.y).is_less(controller.combo_launch_velocity * 0.5)


func test_down_repulse_then_glide_triggers_combo_launch() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.input.local_pitch = PITCH_DOWN

	runner.simulate_action_press("repulse")
	await runner.simulate_frames(5)
	runner.simulate_action_press("glide")
	await runner.simulate_frames(3)

	assert_bool(controller.is_gliding).is_true()
	# A few ticks of reduced glide gravity may have shaved a little off.
	assert_float(controller.velocity.y).is_greater(controller.combo_launch_velocity * 0.7)


func test_combo_launch_keeps_glide_active_while_rising() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.input.local_pitch = PITCH_DOWN

	runner.simulate_action_press("repulse")
	await runner.simulate_frames(5)
	runner.simulate_action_press("glide")
	await runner.simulate_frames(20)

	# Still rising or floating mid-launch: glide must not self-cancel.
	assert_bool(controller.is_gliding).is_true()


func test_level_repulse_does_not_arm_combo() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.input.local_pitch = PITCH_LEVEL

	runner.simulate_action_press("repulse")
	await runner.simulate_frames(5)
	controller.input.local_pitch = PITCH_DOWN
	runner.simulate_action_press("glide")
	await runner.simulate_frames(3)

	assert_bool(controller.is_gliding).is_true()
	assert_float(controller.velocity.y).is_less(controller.combo_launch_velocity * 0.5)


func test_combo_expires_after_window() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.input.local_pitch = PITCH_DOWN

	runner.simulate_action_press("repulse")
	await runner.simulate_frames(5)
	await await_millis(int(controller.combo_window * 1000) + 300)
	runner.simulate_action_press("glide")
	await runner.simulate_frames(3)

	assert_bool(controller.is_gliding).is_true()
	assert_float(controller.velocity.y).is_less(controller.combo_launch_velocity * 0.5)
```

- [ ] **Step 2: Run to verify the new tests fail**

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/player/test_fps_controller.gd --ignoreHeadlessMode
```

Expected: FAIL — `is_gliding` stays false (stubs are empty).

- [ ] **Step 3: Implement the abilities**

In `scripts/player/fps_controller.gd`, replace the two stubs with:

```gdscript
func _cast_repulse(tick: int, is_fresh: bool) -> void:
	var looking_down := input.aim_pitch < -0.65
	if looking_down:
		last_down_repulse_tick = tick

	var aim := Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)
	var cast_dir := aim * Vector3.FORWARD

	# Self push (predicted; velocity is rollback state).
	velocity += cast_dir * (repulse_strength * 0.4)
	if looking_down:
		velocity.y -= 6.0

	# World side effects run once, on fresh ticks only — never re-applied
	# during rollback re-simulation.
	if is_fresh:
		_push_nearby_bodies(cast_dir)
		print("Repulse cast (downward=%s, tick=%d)" % [looking_down, tick])


func _push_nearby_bodies(cast_dir: Vector3) -> void:
	var space_state := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = repulse_range

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = global_transform.translated(cast_dir * 4.0)
	query.collide_with_bodies = true

	var results := space_state.intersect_shape(query)
	for res in results:
		var body = res["collider"]
		if body and body != self:
			var push_dir = (body.global_position - global_position).normalized()
			if body is CharacterBody3D:
				body.velocity += push_dir * repulse_strength + Vector3(0, 4, 0)
			elif body is RigidBody3D:
				body.apply_central_impulse(push_dir * repulse_strength * 3.0)


func _try_deploy_glide(tick: int) -> void:
	var window_ticks := int(roundf(combo_window * NetworkTime.tickrate))
	var is_combo := (tick - last_down_repulse_tick <= window_ticks) and input.aim_pitch < -0.4

	is_gliding = true
	glide_ticks_remaining = int(roundf(glide_duration * NetworkTime.tickrate))

	if is_combo:
		velocity.y = combo_launch_velocity
		print(">>> GLIDE LAUNCH COMBO! (tick=%d)" % tick)
	else:
		if not is_on_floor():
			velocity.y = maxf(velocity.y, 8.0)
		if velocity.y < 0:
			velocity.y *= 0.3
		print("Glide deployed (tick=%d)" % tick)
```

- [ ] **Step 4: Run the full suite**

Run the Global Constraints test command. Expected: `12 test cases | 0 errors | 0 failures`, `Exit code: 0`.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/fps_controller.gd tests/player/test_fps_controller.gd
git commit -m "feat: tick-based Repulse + Glide with rollback-safe combo window

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Offline bootstrap for the test arena + live verification

**Files:**
- Create: `scripts/levels/test_arena.gd`
- Modify: `scenes/levels/test_arena.tscn` (attach script to root)

**Interfaces:**
- Consumes: `NetworkTime.start()` (Task 1).
- Produces: `test_arena.tscn` playable offline (F5 / headless) with the predicted controller.

- [ ] **Step 1: Create `scripts/levels/test_arena.gd`**

```gdscript
# Offline bootstrap: netfox's tick loop must be started explicitly when no
# multiplayer session exists (NetworkEvents handles the networked case).
extends Node3D


func _ready() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer:
		NetworkTime.start()
```

- [ ] **Step 2: Attach it to the arena root**

In `scenes/levels/test_arena.tscn`: add to the `[ext_resource]` block and root node:

```
[ext_resource type="Script" path="res://scripts/levels/test_arena.gd" id="3_arena_script"]
```

and change the root node line to:

```
[node name="TestArena" type="Node3D"]
script = ExtResource("3_arena_script")
```

(Also bump the header `load_steps` from 8 to 9.)

- [ ] **Step 3: Live verification via MCP TCP (glide while airborne)**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5000 >/dev/null 2>&1 &
sleep 4
python3 - <<'EOF'
import socket, json, time
s = socket.create_connection(("127.0.0.1", 9090), timeout=5); f = s.makefile("r")
def cmd(c, p=None, i=1):
    s.sendall((json.dumps({"id": i, "command": c, "params": p or {}}) + "\n").encode())
    return json.loads(f.readline())
print(cmd("eval", {"code": "var c := get_tree().root.get_node('TestArena/FPSController') as CharacterBody3D\nc.global_position.y += 12.0\nc.velocity = Vector3.ZERO\nreturn c.global_position.y"}))
print(cmd("key_press", {"key": "g"}, 2))
time.sleep(0.3)
print(cmd("get_property", {"node_path": "/root/TestArena/FPSController", "property": "is_gliding"}, 3))
s.close()
EOF
```

Expected: last response has `'value': True` (glide active under the netfox tick loop in the live game).

- [ ] **Step 4: Full suite still green**

Run the Global Constraints test command. Expected: `12 test cases | 0 errors | 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add scripts/levels/test_arena.gd scenes/levels/test_arena.tscn
git commit -m "feat: start netfox tick loop for offline play in test arena

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Configurable MCP interaction-server port

**Files:**
- Modify: `scripts/dev/mcp_interaction_server.gd` (the `_ready` function, around line 18–27)

**Interfaces:**
- Produces: env var `GODOT_MCP_PORT` overrides the TCP port (default stays 9090). Task 7's E2E driver relies on this to control two instances at once.

- [ ] **Step 1: Edit `_ready` in `scripts/dev/mcp_interaction_server.gd`**

Replace:

```gdscript
	_server = TCPServer.new()
	var err: int = _server.listen(PORT, "127.0.0.1")
	if err != OK:
		push_error("McpInteractionServer: Failed to listen on port %d, error: %d" % [PORT, err])
		return
	print("McpInteractionServer: Listening on 127.0.0.1:%d" % PORT)
```

with:

```gdscript
	# Local divergence from upstream godot-mcp: port override so multiple
	# instances (e.g. netcode E2E tests) can each expose a control server.
	var port := PORT
	var port_env := OS.get_environment("GODOT_MCP_PORT")
	if port_env != "" and port_env.is_valid_int():
		port = int(port_env)
	_server = TCPServer.new()
	var err: int = _server.listen(port, "127.0.0.1")
	if err != OK:
		push_error("McpInteractionServer: Failed to listen on port %d, error: %d" % [port, err])
		return
	print("McpInteractionServer: Listening on 127.0.0.1:%d" % port)
```

- [ ] **Step 2: Verify the override works**

```bash
GODOT_MCP_PORT=9191 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 600 2>&1 | grep "McpInteractionServer: Listening"
```

Expected: `McpInteractionServer: Listening on 127.0.0.1:9191`

- [ ] **Step 3: Commit**

```bash
git add scripts/dev/mcp_interaction_server.gd
git commit -m "feat: allow MCP interaction server port override via GODOT_MCP_PORT

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Two-instance E2E test with simulated latency

**Files:**
- Create: `scripts/dev/net_test.gd`, `scenes/dev/net_test.tscn`
- Create: `tests/e2e/net_smoke.py`

**Interfaces:**
- Consumes: `fps_controller.tscn` (Task 3/4), `GODOT_MCP_PORT` (Task 6), netfox `NetworkSimulator` project settings (`netfox/autoconnect/*`, see verified facts).
- Produces: `net_test.tscn` — launch two instances; first hosts, second joins through a latency proxy; one `FPSController` spawns per peer under `/root/NetTest/Players/<peer_id>`. `tests/e2e/net_smoke.py` — scripted verification. Env knob: `NET_TEST_LATENCY_MS` (default 0).

- [ ] **Step 1: Create `scripts/dev/net_test.gd`**

```gdscript
# Two-instance netcode test harness.
# Launch the scene twice: the first instance hosts on 127.0.0.1:9999, later
# instances auto-join (netfox NetworkSimulator). Latency is injected via the
# NET_TEST_LATENCY_MS env var. One FPSController spawns per peer.
extends Node3D

const PLAYER_SCENE := "res://scenes/player/fps_controller.tscn"

@onready var spawner: MultiplayerSpawner = $Players/MultiplayerSpawner


func _enter_tree() -> void:
	# NetworkSimulator reads these in its _ready (child ready runs before
	# ours), so configure them here. Runtime-only; never persisted.
	ProjectSettings.set_setting("netfox/autoconnect/enabled", true)
	ProjectSettings.set_setting("netfox/autoconnect/host", "127.0.0.1")
	ProjectSettings.set_setting("netfox/autoconnect/port", 9999)
	var latency_env := OS.get_environment("NET_TEST_LATENCY_MS")
	if latency_env != "" and latency_env.is_valid_int():
		ProjectSettings.set_setting("netfox/autoconnect/simulated_latency_ms", int(latency_env))


func _ready() -> void:
	spawner.spawn_function = _spawn_player
	var simulator: Node = $NetworkSimulator
	simulator.server_created.connect(_on_server_created)


func _on_server_created() -> void:
	NetworkTime.start()
	_do_spawn(1)
	multiplayer.peer_connected.connect(_do_spawn)
	multiplayer.peer_disconnected.connect(_despawn)


func _do_spawn(peer_id: int) -> void:
	spawner.spawn(peer_id)


func _despawn(peer_id: int) -> void:
	var node := get_node_or_null("Players/%d" % peer_id)
	if node:
		node.queue_free()


func _spawn_player(peer_id: int) -> Node:
	var player: FPSController = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.name = str(peer_id)
	player.position = Vector3(peer_id * 2.0, 1.5, 0)
	# State stays server-authoritative (node authority = 1); only the input
	# node belongs to the owning peer. Controller _ready re-runs
	# process_settings after this.
	player.get_node("Input").set_multiplayer_authority(peer_id)
	return player
```

- [ ] **Step 2: Create `scenes/dev/net_test.tscn`**

```
[gd_scene load_steps=5 format=3 uid="uid://nettestscene1"]

[ext_resource type="Script" path="res://scripts/dev/net_test.gd" id="1_nettest"]
[ext_resource type="Script" path="res://addons/netfox.extras/network-simulator.gd" id="2_netsim"]

[sub_resource type="BoxMesh" id="BoxMesh_Floor"]
size = Vector3(60, 1, 60)

[sub_resource type="BoxShape3D" id="BoxShape_Floor"]
size = Vector3(60, 1, 60)

[node name="NetTest" type="Node3D"]
script = ExtResource("1_nettest")

[node name="NetworkSimulator" type="Node" parent="."]
script = ExtResource("2_netsim")

[node name="Floor" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.5, 0)

[node name="MeshInstance3D" type="MeshInstance3D" parent="Floor"]
mesh = SubResource("BoxMesh_Floor")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Floor"]
shape = SubResource("BoxShape_Floor")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866025, -0.433013, 0.25, 0, 0.5, 0.866025, -0.5, -0.75, 0.433013, 0, 15, 0)

[node name="Players" type="Node3D" parent="."]

[node name="MultiplayerSpawner" type="MultiplayerSpawner" parent="Players"]
spawn_path = NodePath("..")
```

- [ ] **Step 3: Create `tests/e2e/net_smoke.py`**

```python
#!/usr/bin/env python3
"""Two-instance netcode smoke test.

Launches a host and a client of net_test.tscn with simulated latency,
drives the client's player via the MCP TCP protocol, and asserts the
server sees the client's movement and glide state.

Usage: python3 tests/e2e/net_smoke.py  (from the repo root)
"""
import json
import os
import signal
import socket
import subprocess
import sys
import time

GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
SCENE = "res://scenes/dev/net_test.tscn"
LATENCY_MS = "50"
HOST_MCP, CLIENT_MCP = 9191, 9192


class Instance:
    def __init__(self, mcp_port: int):
        env = os.environ.copy()
        env.update({
            "GODOT_MCP_PORT": str(mcp_port),
            "NET_TEST_LATENCY_MS": LATENCY_MS,
            # NetworkSimulator self-disables when these are non-empty:
            "CI": "", "NETFOX_CI": "", "NETFOX_NO_AUTOCONNECT": "",
        })
        self.proc = subprocess.Popen(
            [GODOT, "--headless", "--path", ".", SCENE],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.sock = None
        self.reader = None
        self._id = 0
        deadline = time.time() + 20
        while time.time() < deadline:
            try:
                self.sock = socket.create_connection(("127.0.0.1", mcp_port), timeout=2)
                self.reader = self.sock.makefile("r")
                return
            except OSError:
                time.sleep(0.5)
        raise RuntimeError(f"MCP port {mcp_port} never came up")

    def cmd(self, command: str, params: dict | None = None) -> dict:
        self._id += 1
        msg = {"id": self._id, "command": command, "params": params or {}}
        self.sock.sendall((json.dumps(msg) + "\n").encode())
        return json.loads(self.reader.readline())

    def stop(self):
        try:
            self.sock.close()
        finally:
            self.proc.send_signal(signal.SIGTERM)


def wait_for(fn, timeout=15.0, interval=0.5, desc="condition"):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if fn():
            return
        time.sleep(interval)
    raise AssertionError(f"Timed out waiting for {desc}")


def main() -> int:
    host = Instance(HOST_MCP)
    client = Instance(CLIENT_MCP)
    try:
        # Both instances must end up with a player node for peer 1 and the
        # client's peer id. Discover the client's peer id from the client.
        wait_for(lambda: client.cmd("eval", {"code": "return multiplayer.get_unique_id()"})
                 .get("result", 1) not in (1, 0), desc="client to get a peer id")
        peer_id = client.cmd("eval", {"code": "return multiplayer.get_unique_id()"})["result"]
        print(f"client peer id: {peer_id}")

        path = f"/root/NetTest/Players/{int(peer_id)}"
        wait_for(lambda: host.cmd("get_property", {"node_path": path, "property": "name"})
                 .get("success", False), desc="host to spawn client player")
        print("host spawned client player")

        # Drive the client forward; its input must replicate through the
        # 50 ms proxy and move the server-side body.
        start = host.cmd("eval", {"code": f"return get_node('{path}').global_position.z"})["result"]
        client.cmd("key_hold", {"key": "w"})
        wait_for(lambda: abs(host.cmd("eval", {"code": f"return get_node('{path}').global_position.z"})
                 ["result"] - start) > 0.5, desc="server-side movement from client input")
        client.cmd("key_release", {"key": "w"})
        print("movement replicated to host")

        # Glide from the client (needs to be airborne: jump first).
        client.cmd("key_press", {"key": "space"})
        time.sleep(0.3)
        client.cmd("key_press", {"key": "g"})
        wait_for(lambda: host.cmd("get_property", {"node_path": path, "property": "is_gliding"})
                 .get("value", False), timeout=5, desc="glide state on host")
        print("glide replicated to host")

        print("E2E NET SMOKE: PASS")
        return 0
    finally:
        host.stop()
        client.stop()


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the E2E test**

```bash
python3 tests/e2e/net_smoke.py
```

Expected output ends with `E2E NET SMOKE: PASS`, exit code 0.
Debugging order if it fails: (1) run one instance non-headless to watch logs (`NET_TEST_LATENCY_MS=0` first, add latency after), (2) check `server_created`/`client_connected` logger lines, (3) verify player nodes exist on both instances via `get_scene_tree`, (4) verify input authority: on the client, `get_node('<path>/Input').get_multiplayer_authority()` must equal the client's peer id.

- [ ] **Step 5: Full GdUnit suite still green**

Run the Global Constraints test command. Expected: `12 test cases | 0 errors | 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add scripts/dev/net_test.gd scenes/dev/net_test.tscn tests/e2e/net_smoke.py
git commit -m "feat: two-instance netcode E2E harness with simulated latency

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Documentation, tuning-sheet note, and spell-check pass

**Files:**
- Modify: `docs/TESTING.md` (netfox testing patterns + E2E how-to)
- Modify: `CLAUDE.md` (tick-based gameplay rules)
- Modify: `docs/PRD.md` (Milestone A progress notes)
- Modify: `docs/ABILITY_TUNING_SHEET.md` (glide floor-cancel semantics change)
- Modify: `.cspell/custom-dictionary.txt` (as flagged)

**Interfaces:**
- Consumes: everything shipped in Tasks 1–7.

- [ ] **Step 1: `docs/TESTING.md`** — append a `## Netcode Testing (netfox)` section documenting: NetworkTime start/stop in `before_test`/`after_test`; effects land on ticks so tests `await runner.simulate_frames(N)` after input; the E2E harness (`python3 tests/e2e/net_smoke.py`, `NET_TEST_LATENCY_MS` knob, two-instance NetworkSimulator autoconnect behavior, CI env caveat: the simulator self-disables when `CI` is non-empty — the E2E driver clears it).

- [ ] **Step 2: `CLAUDE.md`** — in the Testing section add one bullet: gameplay simulation is tick-based under netfox — never use wall-clock time or `_input`-driven state changes in gameplay code; new per-tick state must be registered in `RollbackSynchronizer.state_properties` in `fps_controller.tscn`; new inputs go through `PlayerInput` + `input_properties`.

- [ ] **Step 3: `docs/PRD.md`** — in Phase 0 mark the netcode spike done: change the netfox spike bullet to end with `✅ (see docs/superpowers/plans/2026-07-15-netfox-integration.md)`.

- [ ] **Step 4: `docs/ABILITY_TUNING_SHEET.md`** — add an investigation note (date 2026-07-15): glide now cancels on floor **only when descending** (`velocity.y <= 0.01`), so ground combos keep glide active through the launch — this is a deliberate behavior change from the pre-netfox prototype, where the ground launch silently dropped glide; validate feel in playtests.

- [ ] **Step 5: Spell check and fix**

```bash
npx -y cspell --no-progress docs/ CLAUDE.md README.md 2>&1 | tail -5
```

Expected: `Issues found: 0`. If new words are flagged (likely: `autoconnect`, `netfox` variants), add them to `.cspell/custom-dictionary.txt` (keep alphabetical order) and re-run.

- [ ] **Step 6: Final full verification + commit**

Run the Global Constraints test command (expect `12 test cases`, exit 0) and `python3 tests/e2e/net_smoke.py` (expect PASS), then:

```bash
git add docs/ CLAUDE.md .cspell/custom-dictionary.txt
git commit -m "docs: netfox testing patterns, tick-based gameplay rules, milestone A notes

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Known risks & fallbacks (for the executor)

- **Rollback tick may not run offline without a peer** (Task 3 Step 5 exposes this immediately). If `_rollback_tick` never fires with `OfflineMultiplayerPeer`, fallback: in `test_arena.gd`/tests, create a loopback session instead: `var p := OfflineMultiplayerPeer.new(); multiplayer.multiplayer_peer = p` is the default — if insufficient, use `ENetMultiplayerPeer.create_server(<free port>)` as a single-player host session. Do not silently switch the controller back to `_physics_process`.
- **`simulate_action_press` vs `Input.is_action_just_pressed`**: if the PlayerInput latch misses GdUnit-simulated presses (Task 2 Step 4 failure), switch tests from `runner.simulate_action_press("x")` to `Input.action_press("x")` + `Input.action_release("x")` (already used in Task 2's tests) — the game path is unaffected since real hardware events always reach `Input`.
- **NetworkSimulator project-settings names**: verified against v1.35.3 source (`netfox/autoconnect/*`). If a future netfox bump renames them, re-verify in `addons/netfox.extras/network-simulator.gd::_load_project_settings`.
- **Two `move_and_slide()` calls per tick** (floor refresh + movement) is the documented netfox pattern; if wall collisions feel off, the floor refresh can use `test_move()` instead — only change it with a failing test demonstrating the problem.
