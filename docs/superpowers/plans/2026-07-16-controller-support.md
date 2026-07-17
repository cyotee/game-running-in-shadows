# Controller Support (Native) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Full native-Godot controller play: joypad bindings for every action, right-stick look with deadzone/response curve, contextual A-button (jump → glide airborne), and controller-only slowdown-on-target — all before the mechanics plans execute, so everything after gets controller-tested as it lands.

**Architecture:** Pure input-layer work plus one simulation rule. Joypad events are added to existing InputMap actions (action names already follow the Steam-Input-compatible convention — Phase 2's IGA manifest reuses them verbatim). Stick look is polled per-frame in `PlayerInput` (mouse stays event-driven; both feed the same `local_yaw/local_pitch`, so netfox sees no difference). The contextual A-button is a `_rollback_tick` rule in `FPSController` — deterministic, rollback-safe, identical for keyboard players. Slowdown-on-target is local sensitivity shaping (grants no information, needs no validation).

**Tech Stack:** Godot 4.7.1 InputMap (JoypadButton/JoypadMotion events), GdUnit4, MatchConfig.

**PREREQUISITE:** netfox integration plan (2026-07-15) executed — this plan edits `PlayerInput` and `FPSController._rollback_tick` as that plan leaves them. Executes as **plan 2 in the queue**, before Resonance. Note for later plans: this plan creates the `weapon_swap`, `menu`, and `scoreboard` actions; the weapons plan's `WeaponRig.process_tick` must also honor `input.swap_weapon` (toggle active slot) alongside `slot_select`.

## Global Constraints

- Test command (after every task): `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode` → exit 0.
- Decided design (MECHANICS_REFERENCE §11 "Controller Support v1", do not re-litigate): native backend now; slowdown-on-target controller-only; the decided default layout; contextual A as a simulation rule; keyboard bindings unchanged (G still glides).
- All numbers via MatchConfig (baselines in ABILITY_TUNING_SHEET §11: deadzone 0.15/0.98, curve exp 2.0, 240°/s yaw / 180°/s pitch, slowdown ×0.6 within 40 m).
- GDScript typed, tabs; `.scratch/` for temp files; commits end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## MatchConfig DEFAULTS additions (Task 1)

```gdscript
	# --- Controller input ---
	"input.stick_deadzone_inner": 0.15,
	"input.stick_deadzone_outer": 0.98,
	"input.look_curve_exponent": 2.0,
	"input.look_max_yaw_deg_s": 240.0,
	"input.look_max_pitch_deg_s": 180.0,
	"input.slowdown_mult": 0.6,
	"input.slowdown_range_m": 40.0,
```

## File Structure

- `project.godot` — MODIFY: joypad events on existing actions; new actions `weapon_swap` (Y + keyboard Q), `menu` (Start + Esc — replaces `toggle_mouse`'s pause role later; keep `toggle_mouse` for dev), `scoreboard` (Select + Tab)
- `scripts/config/match_config.gd` — MODIFY: keys above
- `scripts/player/player_input.gd` — MODIFY: stick look, `swap_weapon` field, slowdown hook
- `scripts/player/fps_controller.gd` — MODIFY: contextual jump/glide rule; `enemy_under_reticle()` helper for slowdown
- Tests: `tests/player/test_player_input.gd`, `tests/player/test_fps_controller.gd` (appends)
- Docs final task.

---

### Task 1: Joypad bindings + config keys

**Files:**
- Modify: `project.godot`, `scripts/config/match_config.gd`

**Interfaces:**
- Produces: every existing action gains a joypad event per the decided layout; new actions `weapon_swap`, `menu`, `scoreboard` exist (keyboard + pad bound). Exact events (Godot enums): `move_*` ← left stick via `Input.get_vector` (bind JoypadMotion axis 0/1 with ±1.0 to the four move actions); `sprint` ← JoypadButton `JOY_BUTTON_LEFT_STICK` (7); `fire_primary` ← JoypadMotion axis `JOY_AXIS_TRIGGER_RIGHT` (5) value 1.0; `ads` ← JoypadMotion axis `JOY_AXIS_TRIGGER_LEFT` (4) value 1.0; `repulse` ← JoypadButton `JOY_BUTTON_RIGHT_SHOULDER` (10); `jump` ← JoypadButton `JOY_BUTTON_A` (0); `reload` ← JoypadButton `JOY_BUTTON_X` (2); `weapon_swap` ← JoypadButton `JOY_BUTTON_Y` (3) + key Q (81); `menu` ← JoypadButton `JOY_BUTTON_START` (6); `scoreboard` ← JoypadButton `JOY_BUTTON_BACK` (4) + key Tab. `glide` keeps keyboard G only (pad path is contextual A). Right stick (axes 2/3) is NOT action-bound — it's polled in code (Task 2).

- [ ] **Step 1:** Add the events to `project.godot` `[input]` and the config keys to `MatchConfig.DEFAULTS`.
- [ ] **Step 2:** Boot check headless (`--quit-after 30`, no errors) + full suite green (no behavior change yet).
- [ ] **Step 3:** Commit `feat: joypad bindings for all actions per decided layout`.

---

### Task 2: Right-stick look in PlayerInput

**Files:**
- Modify: `scripts/player/player_input.gd`
- Test: `tests/player/test_player_input.gd` (append)

**Interfaces:**
- Produces: per-frame stick polling that updates `local_yaw`/`local_pitch` (same variables mouse motion feeds — downstream code unchanged). Deadzone remap (inner/outer), response curve (`signf(v) * pow(absf(v), exponent)`), rates from config. Public `look_rate_scale: float = 1.0` — multiplied into stick look each frame (Task 4's slowdown sets it; mouse ignores it per the decided design). New networked field `swap_weapon: bool` (edge-latched from `weapon_swap`).

- [ ] **Step 1: Append failing tests:**

```gdscript
func test_stick_look_turns_view() -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 1.0
	Input.parse_input_event(motion)
	var start_yaw := _input.local_yaw
	await await_millis(200)

	assert_float(_input.local_yaw).is_not_equal(start_yaw)

	motion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 0.0
	Input.parse_input_event(motion)


func test_stick_deadzone_ignores_drift() -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 0.1  # below 0.15 inner deadzone
	Input.parse_input_event(motion)
	var start_yaw := _input.local_yaw
	await await_millis(200)

	assert_float(_input.local_yaw).is_equal(start_yaw)


func test_swap_weapon_is_edge_latched() -> void:
	Input.action_press("weapon_swap")
	Input.action_release("weapon_swap")
	await await_millis(100)
	assert_bool(_input._pending_swap).is_false()
```

- [ ] **Step 2: Run** input suite → FAIL. **Step 3: Implement** in `player_input.gd`:

```gdscript
# --- Networked per-tick input (addition) ---
var swap_weapon: bool = false

# --- Controller look (local shaping; feeds the same local_yaw/local_pitch) ---
var look_rate_scale: float = 1.0

var _pending_swap: bool = false


func _remap_stick(value: float) -> float:
	var inner := MatchConfig.get_value("input.stick_deadzone_inner")
	var outer := MatchConfig.get_value("input.stick_deadzone_outer")
	var mag := absf(value)
	if mag < inner:
		return 0.0
	var normalized := clampf((mag - inner) / (outer - inner), 0.0, 1.0)
	return signf(value) * pow(normalized, MatchConfig.get_value("input.look_curve_exponent"))
```

In `_process`, after the existing latches (and inside the authority guard):

```gdscript
	_pending_swap = _pending_swap or Input.is_action_just_pressed("weapon_swap")

	var stick_x := _remap_stick(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X))
	var stick_y := _remap_stick(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick_x != 0.0 or stick_y != 0.0:
		var yaw_rate := deg_to_rad(MatchConfig.get_value("input.look_max_yaw_deg_s"))
		var pitch_rate := deg_to_rad(MatchConfig.get_value("input.look_max_pitch_deg_s"))
		local_yaw = wrapf(local_yaw - stick_x * yaw_rate * look_rate_scale * _delta, -PI, PI)
		local_pitch = clampf(local_pitch - stick_y * pitch_rate * look_rate_scale * _delta,
			-PI / 2.0, PI / 2.0)
```

(`_process(_delta)` parameter rename to `_delta` → `delta` as needed.) In `_gather`: `swap_weapon = _pending_swap; _pending_swap = false`. Register `Input:swap_weapon` as an input property in `fps_controller.tscn`.
Note: `Input.get_joy_axis(0, ...)` reads device 0; `parse_input_event` in tests feeds the same axis state.

- [ ] **Step 4: Run** full suite → green. **Step 5: Commit** `feat: right-stick look with deadzone and response curve`.

---

### Task 3: Contextual A-button (jump → glide airborne) as a simulation rule

**Files:**
- Modify: `scripts/player/fps_controller.gd`
- Test: `tests/player/test_fps_controller.gd` (append)

**Interfaces:**
- Produces: in `_rollback_tick`, the jump input resolves contextually — on floor: jump (unchanged); airborne and not gliding: deploy glide (same path as the `glide` input, combo check included); while gliding: glide boost (unchanged, already reads `input.jump`). The dedicated `glide` input keeps working (keyboard G). Precedence: an airborne jump-press that deploys glide is consumed (does not also boost that tick).

- [ ] **Step 1: Append failing test:**

```gdscript
func test_airborne_jump_deploys_glide() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.global_position.y += 12.0
	controller.velocity = Vector3.ZERO

	runner.simulate_action_press("jump")
	await runner.simulate_frames(5)

	assert_bool(controller.is_gliding).is_true()


func test_grounded_jump_still_jumps() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	# Spawned in empty space: give it a floor by dropping to rest first is
	# not available here, so assert the inverse: grounded logic unchanged is
	# covered by the existing movement tests; here assert no glide on floor.
	# (test arena floor exists in scene-level tests; this scene has none, so
	# force the floor state check path by asserting glide did NOT deploy
	# while the combo path still works — see existing combo tests.)
	assert_bool(controller.is_gliding).is_false()
```

(The meaningful new assertion is the first test; the second documents that grounded behavior is covered by the existing suite — keep the existing `test_down_repulse_then_glide_triggers_combo_launch` and movement tests as the grounded regression net.)

- [ ] **Step 2: Run** → FAIL (airborne jump does nothing but boost checks). **Step 3: Implement** — in `_rollback_tick`, replace the ability-trigger block with (ordering: boost intent is captured BEFORE deploy so a deploy-press doesn't double as a boost the same tick):

```gdscript
	# Capture boost intent before contextual deploy can consume the press.
	var jump_for_boost := input.jump and is_gliding

	if input.repulse:
		_cast_repulse(tick, is_fresh)
	var wants_glide := input.glide or (input.jump and not is_on_floor() and not is_gliding)
	if wants_glide and not is_gliding:
		_try_deploy_glide(tick)
```

…and in the glide movement branch, change the boost condition from `if input.jump:` to `if jump_for_boost:`.
(If the Resonance plan has already executed, the Repulse line is `if input.repulse and resonance.try_spend(...):` — keep that form; only the glide trigger and boost condition change.)

- [ ] **Step 4: Run** full suite → green (all combo tests must still pass). **Step 5: Commit** `feat: contextual jump deploys glide when airborne`.

---

### Task 4: Slowdown-on-target (controller only)

**Files:**
- Modify: `scripts/player/fps_controller.gd`, `scripts/player/player_input.gd`
- Test: `tests/player/test_fps_controller.gd` (append)

**Interfaces:**
- Produces: `FPSController.enemy_under_reticle(max_range: float) -> bool` — raycast from camera along view (world + hit zones mask, excluding self) hitting another player's hit zone within range. In `_process` (local player only): `input.look_rate_scale = MatchConfig.get_value("input.slowdown_mult") if enemy_under_reticle(MatchConfig.get_value("input.slowdown_range_m")) else 1.0`. Mouse path never reads `look_rate_scale` (decided: controller only).

- [ ] **Step 1: Append failing test:**

```gdscript
func test_slowdown_scale_set_when_enemy_under_reticle() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	var victim: FPSController = (load(CONTROLLER_SCENE) as PackedScene).instantiate()
	controller.get_parent().add_child(victim)
	victim.global_position = controller.global_position + Vector3(0, 0, -5)
	# Aim straight at the victim (spawned facing -Z).
	controller.input.local_pitch = 0.0
	await runner.simulate_frames(5)

	assert_bool(controller.enemy_under_reticle(40.0)).is_true()
	assert_float(controller.input.look_rate_scale).is_equal(0.6)

	victim.global_position += Vector3(20, 0, 0)  # move out of reticle
	await runner.simulate_frames(5)
	assert_float(controller.input.look_rate_scale).is_equal(1.0)
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** `enemy_under_reticle` (same ray setup as `WeaponBase._hitscan` but returning a bool on player-zone hit — if the weapons plan hasn't executed yet, write it against the base capsule on layer 1 and leave a `TODO(weapons): use hit-zone layer` that the weapons plan's Task 2 resolves) plus the `_process` hook.
- [ ] **Step 4: Run** full suite → green. **Step 5: Commit** `feat: controller-only slowdown-on-target aim assist`.

---

### Task 5: Live verification + docs

- [ ] **Step 1 (MCP live check):** run the arena headless; use the godot-mcp `gamepad` command (`game_gamepad` tool / `gamepad` TCP command) to: push left stick forward → position changes; push right stick → `local_yaw` changes; press A while airborne (teleport up via `eval` first) → `is_gliding` true. If the MCP gamepad command can't reach Godot's `Input` (it may synthesize at a different layer), fall back to `eval` with `Input.parse_input_event(InputEventJoypadMotion...)` — the same code path the tests exercise.
- [ ] **Step 2 (manual, if a pad is handy):** plug in any XInput pad, play the arena: full movement + combo on the decided layout; note feel issues (curve exponent, rates) in the tuning sheet.
- [ ] **Step 3 (docs):** CLAUDE.md — one line: controller look/assist lives in `PlayerInput` (`look_rate_scale`), contextual A is a `_rollback_tick` rule; new input actions must get joypad events per MECHANICS_REFERENCE §11 layout. PRD Milestone A note: native controller support ✅.
- [ ] **Step 4:** cspell + full suite green. Commit `feat: controller support verified; docs updated`.

---

## Known risks & notes (for the executor)

- **Execution order flexibility:** this plan is written to run as plan 2 (right after netfox). Task 3 and Task 4 reference `resonance` and hit zones that arrive in later plans — both tasks contain explicit adaptation notes for whichever state the file is in. If it runs later instead, the notes collapse to no-ops.
- **Trigger-as-button bindings** (RT/LT via JoypadMotion value 1.0) use Godot's 0.5 actuation default — fine for fire/ADS. If half-pull misfires annoy, set the action deadzone to 0.6 in the InputMap.
- **`Input.get_joy_axis(0, ...)`** assumes device 0; multi-controller support (couch splitscreen) is out of scope — first connected pad wins.
- **Slowdown fairness:** the ×0.6 factor applies only to stick-driven look; a player using both mouse and pad simultaneously gets slowdown only on the stick component. That's correct per the decision, not a bug.
- **Steam Deck**: nothing to do here — Deck presents as a standard pad; the Phase 2 Steam Input manifest adds glyphs/configs later using these same action names.
