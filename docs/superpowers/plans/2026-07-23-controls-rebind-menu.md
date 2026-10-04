# Controls Rebind Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In-game Controls settings with **listen-to-rebind** (select command →
press key / mouse / controller to map) and **multiple bindings per command** so
keyboard+mouse and controller can be mapped at the same time. Persist local
profiles to `user://`; never touch netfox/rollback or gameplay action names.

**Architecture:** Thin `InputBindings` autoload owns serialize / apply / listen /
conflict policy over Godot **InputMap** (multi-event per action). UI is a
`ControlsMenu` panel (main menu + pause) that never writes scancodes into
`PlayerInput` — simulation keeps reading named actions only. Sensitivity /
invert / stick feel live on the same page (local prefs + existing
`MatchConfig` `input.*` defaults for factory numbers). Steam Input API is
**out of scope** (Phase 2); action names stay IGA-compatible.

**Tech Stack:** Godot 4.7.1 InputMap, GDScript, GdUnit4, existing UI patterns
(`DisplayConfig`, `DevArsenal`, `MainMenu`).

**Design sources (do not re-litigate):**
- MECHANICS_REFERENCE §11 — Ability Slots & Binding; Input & Accessibility;
  Controller Support v1 (rebindable default layout; native InputMap now).
- Session decisions (2026-07-23): record-to-remap; multi-bind per action;
  KBM + pad simultaneous; steal-on-conflict; dual-device storage.

---

## Global Constraints

- Test command (after every task):
  ```bash
  GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
    /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
    addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode
  ```
  → exit 0.
- **Gameplay / netfox invariant:** rebinding only mutates `InputMap` events and
  local look prefs. Do **not** change `PlayerInput` press-tick semantics, action
  name strings used in sim, or MatchConfig host-synced combat keys for binds.
- **Action names are stable** (Steam IGA later). Never rename `fire_primary`,
  `repulse`, etc.
- Dev-only actions (`dev_promote`, `dev_arsenal` if present) are **hidden** from
  the player-facing list (still in InputMap).
- `toggle_mouse` stays a utility bind (show in System category or hide — prefer
  **System**, not removed).
- Contextual A jump→glide remains a **simulation rule** (not a second rebindable
  “air glide” pad action). Keyboard `glide` stays rebindable.
- GDScript typed, tabs; `.scratch/` for temp files; no IP-violating names.
- Commits end with co-author line per team convention when committing.

---

## Product decisions (locked for this plan)

| Topic | Decision |
|-------|----------|
| Capture UX | Click bind slot / “Add bind” → listen mode → next eligible event maps |
| Multi-bind | Each action holds **N** events; KBM + pad coexist |
| UI model | One row per command; binds shown as removable chips; device tabs filter focus |
| Conflict | New bind **steals** from other actions on same event; toast/status line |
| Cancel listen | Esc / `ui_cancel` / B (when not the event being bound) cancels without apply |
| Persistence | `user://input_bindings.json` (versioned); factory = current `project.godot` |
| Profiles (MVP) | Single active profile `"default"`; multi-profile API stub only if cheap |
| Loadout-specific sets | **Deferred** (P3 later); schema leaves room via `profile` string |
| Sensitivity | Mouse sens, invert Y, stick rates/deadzones/aim-assist on same panel |
| Prompt labels | `InputBindings.action_label(action)` for HUD later (implement in Task 2) |

---

## Rebindable action catalog (player-facing)

Group for UI categories. Order within category is display order.

### Movement
`move_forward`, `move_backward`, `move_left`, `move_right`, `jump`, `sprint`,
`crouch`

### Combat
`fire_primary`, `ads`, `reload`, `weapon_swap`, `weapon_slot_1`, `weapon_slot_2`,
`grenade`, `interact`

### Abilities
`repulse`, `glide`, `slip`, `wraith`, `lifebloom`, `tangle`, `null_charge`,
`reclaim`, `familiar`, `pulse_sight`, `smart_rig`, `overclock`, `ping`

### System
`menu`, `scoreboard`, `toggle_mouse`

### Hidden (not listed in UI)
`dev_promote` (and any future `dev_*`)

**Not InputMap actions (feel controls, same panel):**
- Mouse sensitivity, invert look Y
- Stick look max rates / curve / deadzones (read/write local prefs; seed from
  `MatchConfig` defaults on first run)
- Aim-assist slowdown mult / range (controller-only shaping; local prefs)

**Not rebindable as actions:**
- Mouse look (relative motion)
- Right-stick look axes (polled in `PlayerInput`; document in UI as “Right stick
  = look” fixed for MVP — optional later if needed)

---

## JSON schema (`user://input_bindings.json`)

```json
{
  "version": 1,
  "profile": "default",
  "mouse_sensitivity": 0.0025,
  "invert_y": false,
  "stick": {
    "deadzone_inner": 0.15,
    "deadzone_outer": 0.98,
    "look_curve_exponent": 2.0,
    "look_max_yaw_deg_s": 240.0,
    "look_max_pitch_deg_s": 180.0,
    "slowdown_mult": 0.6,
    "slowdown_range_m": 40.0
  },
  "actions": {
    "fire_primary": [
      { "type": "mouse_button", "button": 1 },
      { "type": "joy_motion", "axis": 5, "axis_value": 1.0 }
    ],
    "repulse": [
      { "type": "key", "keycode": 69 },
      { "type": "joy_button", "button": 10 }
    ]
  }
}
```

Event `type` enum for serialize:
- `key` — physical or keycode (prefer `keycode` + store physical if available)
- `mouse_button` — button index
- `joy_button` — button index
- `joy_motion` — axis + axis_value (±1.0 for digital-as-axis triggers / stick
  directions if present on move_*)

Only events for **catalog actions** are saved. Unknown keys on load are ignored
with a warning. Missing actions after load keep project defaults until explicit
reset.

---

## File Structure

| Path | Role |
|------|------|
| `scripts/config/input_bindings.gd` | **NEW** autoload `InputBindings` |
| `scripts/config/input_bindings.gd.uid` | NEW |
| `scenes/ui/controls_menu.tscn` | **NEW** Controls panel |
| `scripts/ui/controls_menu.gd` | **NEW** UI logic |
| `scripts/ui/controls_menu.gd.uid` | NEW |
| `scenes/ui/settings_menu.tscn` | **NEW** thin Settings shell (tabs: Display / Controls) *or* embed Controls under MainMenu only in Task 4 — prefer Settings shell |
| `scripts/ui/settings_menu.gd` | **NEW** if Settings shell |
| `project.godot` | Register `InputBindings` autoload (after `MatchConfig`) |
| `scripts/player/player_input.gd` | MODIFY: read sens/invert from `InputBindings`; stick feel from prefs |
| `scripts/ui/main_menu.gd` + `.tscn` | MODIFY: Settings button → open Settings/Controls |
| `scenes/levels/test_arena.tscn` / match HUD | MODIFY: pause → Settings (minimal: open Controls on `menu` when not already open) |
| `tests/config/test_input_bindings.gd` | **NEW** |
| `tests/ui/test_controls_menu.gd` | **NEW** (logic-heavy; optional SceneRunner) |
| `docs/MECHANICS_REFERENCE.md` | Note rebind menu shipped |
| `docs/ABILITY_TUNING_SHEET.md` | Local sens defaults reference if needed |
| `docs/superpowers/RESUME-HERE.md` | Progress note |

---

## Tasks

### Task 1: `InputBindings` autoload — model, serialize, apply, defaults

**Files:**
- Create: `scripts/config/input_bindings.gd`
- Modify: `project.godot` (autoload)
- Test: `tests/config/test_input_bindings.gd`

**Interfaces:**

```gdscript
# Autoload name: InputBindings (no class_name — match DisplayConfig convention)
extends Node

const SAVE_PATH := "user://input_bindings.json"
const SCHEMA_VERSION := 1

## Player-facing action names, category -> PackedStringArray
func catalog() -> Dictionary

## Snapshot current InputMap events for catalog actions -> Dictionary
func capture_from_input_map() -> Dictionary

## Replace InputMap events for catalog actions from dict; leave others alone
func apply_actions(actions: Dictionary) -> void

## Load JSON if present; else seed from InputMap; apply feel prefs
func load_or_seed() -> void
func save() -> void
func reset_to_project_defaults() -> void  # re-read project.godot events via InputMap after clear?

## Event encode/decode (Dictionary <-> InputEvent)
func event_to_dict(event: InputEvent) -> Dictionary
func dict_to_event(data: Dictionary) -> InputEvent

## Equality for conflict / steal (same physical control)
func events_equivalent(a: InputEvent, b: InputEvent) -> bool

## Human label for HUD/UI ("E", "LMB", "RB", "RT", …)
func event_label(event: InputEvent) -> String
func action_label(action: StringName) -> String  # joined chips

## Feel prefs (get/set; save on set or explicit save)
var mouse_sensitivity: float
var invert_y: bool
# stick.* fields as needed
```

**Apply rules:**
1. On `_ready`: `load_or_seed()` after `MatchConfig` is ready.
2. `apply_actions`: for each catalog action, `InputMap.action_erase_events` then
   `action_add_event` for each decoded event. Skip invalid dicts.
3. `reset_to_project_defaults`: delete save file **or** overwrite with a
   factory snapshot taken once at first boot before user edits
   (`_factory_snapshot` captured in `_ready` before load). Prefer factory
   snapshot in memory so project.godot remains source of truth for reset
   without restarting the editor.

- [x] **Step 1:** Write failing tests: encode/decode roundtrip for key, mouse,
  joy_button, joy_motion; `events_equivalent`; apply then capture equals;
  reset restores factory; load ignores unknown action keys; catalog hides
  `dev_*`.
- [x] **Step 2:** Implement `InputBindings` + register autoload.
- [x] **Step 3:** Run `./tests/config` (or full suite) → green.
- [x] **Step 4:** Commit `feat: InputBindings autoload — serialize/apply InputMap profiles`.

---

### Task 2: Listen mode, multi-bind, steal-on-conflict

**Files:**
- Modify: `scripts/config/input_bindings.gd`
- Test: `tests/config/test_input_bindings.gd` (append)

**Interfaces:**

```gdscript
signal listen_started(action: StringName)
signal listen_finished(action: StringName, accepted: bool)
signal binding_changed(action: StringName)
signal conflict_resolved(stolen_from: StringName, event_label: String)

enum ListenMode { IDLE, LISTENING }

var listen_mode: int
var listen_action: StringName

func begin_listen(action: StringName) -> void
func cancel_listen() -> void

## Called from ControlsMenu / _input while listening.
## Returns true if the event was consumed (bound or cancelled).
func handle_listen_event(event: InputEvent) -> bool

## Append event to action (multi-bind). Steals from other catalog actions first.
func add_binding(action: StringName, event: InputEvent) -> void

## Remove one binding by index or equivalent event
func remove_binding(action: StringName, event: InputEvent) -> void

## Replace all events for action (optional helper)
func set_bindings(action: StringName, events: Array) -> void
```

**Listen eligibility:**
- Accept: `InputEventKey` (pressed, not echo), `InputEventMouseButton` (pressed),
  `InputEventJoypadButton` (pressed), `InputEventJoypadMotion` with
  `absf(axis_value) >= 0.5` (treat as digital press for triggers / stick dirs).
- Reject while listening: pure mouse motion; noisy axis chatter under threshold.
- Cancel: `ui_cancel` / Escape key **without** binding, unless listen was
  explicitly for rebinding menu (still cancel first).

**Steal policy:**
1. Before add, scan all catalog actions for `events_equivalent`.
2. Remove from those actions.
3. Emit `conflict_resolved`.
4. Append to target action.
5. `save()` (or dirty-flag + save on menu close — **prefer save on each
   successful bind** for crash safety).

**Duplicate on same action:** adding an equivalent event that already exists on
the target is a no-op (no duplicates).

- [x] **Step 1:** Failing tests: add two different device events to one action;
  steal removes from previous action; duplicate no-op; cancel listen; motion
  axis below threshold ignored; trigger axis accepted.
- [x] **Step 2:** Implement listen + multi-bind + steal.
- [x] **Step 3:** Suite green.
- [x] **Step 4:** Commit `feat: InputBindings listen-to-rebind with multi-bind and steal`.

---

### Task 3: Wire feel prefs into `PlayerInput`

**Files:**
- Modify: `scripts/player/player_input.gd`
- Test: `tests/player/test_player_input.gd` (append if needed)

**Behavior:**
- Mouse look: `mouse_sensitivity` from `InputBindings` (not only `@export`);
  apply `invert_y` to mouse and stick pitch.
- Stick look: deadzone / curve / max rates from `InputBindings` stick prefs
  (fallback: `MatchConfig.get_value("input.*")` if unset).
- Aim-assist slowdown already uses MatchConfig — switch to InputBindings stick
  prefs for mult/range so the Controls panel can change them without host
  match config.

Do **not** network these prefs.

- [x] **Step 1:** Tests for invert_y sign and sens scaling if feasible via
  injecting prefs; otherwise lightweight unit tests on a pure helper.
- [x] **Step 2:** Implement reads from `InputBindings`.
- [x] **Step 3:** Suite green.
- [x] **Step 4:** Commit `feat: PlayerInput reads look feel from InputBindings`.

---

### Task 4: Controls menu UI (listen UX + multi-bind chips)

**Files:**
- Create: `scenes/ui/controls_menu.tscn`, `scripts/ui/controls_menu.gd`
- Create: `scenes/ui/settings_menu.tscn`, `scripts/ui/settings_menu.gd`
  (tabs: Controls; stub Display that deep-links existing DisplayConfig controls
  or hosts a minimal duplicate of DevArsenal display row — **minimum:** Controls
  tab only + Back)
- Modify: `scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd` — Settings button
- Test: `tests/ui/test_controls_menu.gd`

**UI structure:**

```
Settings
  [Controls]
    Device filter: [All] [Keyboard+Mouse] [Controller]   (filter chips display only)
    Category: [Movement] [Combat] [Abilities] [System]
    Scroll list:
      Row: "Repulse"   [E] [RB]   [+ Add] 
      … chips clickable → remove (or re-listen replace)
    Feel:
      Mouse sens slider, Invert Y checkbox
      Stick sens / deadzone / aim assist sliders
    [Reset to defaults]  [Back]
```

**Listen UX:**
- Click **+ Add** or empty slot → row shows “Press key, mouse, or controller…”
- `ControlsMenu` sets `process_mode` / uses `_input` at high priority while
  listening; calls `InputBindings.handle_listen_event`.
- Status label shows conflicts: `RT unbound from ADS` (example).
- `process_mode = PROCESS_MODE_ALWAYS` when used under pause later.

**Functional/debug-grade visuals** (same as other menus) — art pass later.

- [x] **Step 1:** Failing tests: catalog row count; `event_label` formatting
  helpers; menu calls `begin_listen` / `add_binding` via doubles if needed.
- [x] **Step 2:** Build scene + script; MainMenu entry.
- [x] **Step 3:** Manual: run main menu, rebind Repulse to another key, confirm
  arena respects it; bind pad button while KBM remains.
- [x] **Step 4:** Suite green; commit `feat: Controls settings menu with listen-to-rebind UI`.

---

### Task 5: In-match pause entry

**Files:**
- Create or extend a minimal pause layer: e.g. `scripts/ui/pause_menu.gd` +
  scene, **or** open `SettingsMenu` as child of current scene on `menu` action.
- Modify: `test_arena` / `match_session` / `player_hud` as appropriate so local
  authority only opens pause.

**Behavior:**
- `menu` action toggles pause menu (Esc / Start).
- Options: Resume, Settings (Controls), Leave arena (main menu) — MVP: Resume +
  Settings + Quit to menu.
- While open: `get_tree().paused = true`; Settings/Controls
  `PROCESS_MODE_WHEN_PAUSED`; free mouse (`Input.MOUSE_MODE_VISIBLE`); on close
  recapture if FPS.
- Do not open pause for remote peers’ UI.

- [x] **Step 1:** Wire pause + Settings from arena; smoke test offline.
- [x] **Step 2:** Ensure listen mode works while paused.
- [x] **Step 3:** Suite green; commit `feat: pause menu opens Controls rebind while paused`.

---

### Task 6: Docs, cspell, full suite, acceptance

**Files:**
- `docs/MECHANICS_REFERENCE.md` — short note under Input: Controls menu +
  multi-bind + listen-to-rebind + `user://input_bindings.json`
- `docs/superpowers/RESUME-HERE.md` — controls rebind status
- `.cspell/custom-dictionary.txt` if needed (`InputBindings`, etc.)

**Acceptance checklist (owner / agent manual):**

1. Fresh save deleted: defaults match current project binds (KBM + pad).
2. Select Repulse → press F → chip shows F; E gone if stolen or still present
   if multi — **Add** keeps both until remove.
3. Same action: E + RB both listed; both fire Repulse.
4. Bind RT to Fire when RT was ADS → ADS loses RT; status explains steal.
5. Reset to defaults restores factory; JSON updated.
6. Sensitivity / invert affect look in arena without restart (after apply).
7. Full GdUnit exit 0; headless OK (listen path not required headless).

- [x] **Step 1:** Docs + cspell.
- [x] **Step 2:** Full suite.
- [x] **Step 3:** Commit `docs: Controls rebind menu — mechanics note + resume`.

---

## Deviations
- Controls/Settings use `PROCESS_MODE_ALWAYS` (not only WHEN_PAUSED) so main-menu rebind works unpaused.
- Commits deferred to end of agent session (single implementation pass).

---

## Out of scope (explicit)

- Steam Input API / action manifests / official Steam glyphs (Phase 2).
- Loadout-specific binding sets (schema-ready via `profile` only).
- Full ability radial (LB) implementation — reserve bind label only if action
  exists later.
- Fancy controller icon atlas (text labels first: `A`, `RB`, `RT`, `L3`).
- Rebinding right-stick look axes.
- Cloud sync of bindings.
- Per-player networked custom binds (always local).

---

## Risk notes

| Risk | Mitigation |
|------|------------|
| Listen captures UI confirm click as mouse bind | Start listen next frame; ignore mouse for 1 frame; or require keyboard/pad first for “Add” from mouse click |
| Joy axis spam fires listen repeatedly | Threshold + one-shot until axis returns under 0.3 |
| Pause + netfox “Game stalled” | Expected offline; document; do not change netfox stall policy for menus |
| Factory reset wrong after editor InputMap edits | Snapshot factory at runtime first boot of process before user JSON apply |
| HUD still shows old key names | Task 2 `action_label`; migrate HUD prompts in a follow-up if hardcoded |

---

## Suggested PR / commit cadence

1. Task 1 — autoload plumbing  
2. Task 2 — listen + multi-bind + steal  
3. Task 3 — PlayerInput feel  
4. Task 4 — Controls UI + main menu  
5. Task 5 — pause integration  
6. Task 6 — docs + acceptance  

---

## Quick reference: default controller layout (unchanged)

From MECHANICS_REFERENCE §11 — rebindable, not rewritten by this plan’s factory
snapshot (snapshot = whatever is in `project.godot` at runtime):

- LS move / L3 sprint · RS look · RT fire · LT ADS · RB Repulse · A jump
  (→ glide airborne) · X reload · Y swap · Start menu · Select scoreboard ·
  D-pad abilities/ping as currently bound · PC defaults remain.

---

**End of plan.**
