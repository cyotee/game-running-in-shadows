# Resonance Resource System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the Resonance resource (float pool, reservations, any-combat regen gating, archetype stats) as netfox rollback state, wire costs into Repulse/Glide, and make every value host-configurable via a MatchConfig registry.

**Architecture:** A `MatchConfig` autoload holds all gameplay tunables (defaults + JSON overrides) — nothing gameplay-numeric is hard-coded. A `ResonancePool` node under `FPSController` owns pool math; its mutable vars are RollbackSynchronizer state properties, ticked from the controller's `_rollback_tick`. Health + damage attribution are added minimally (no death/respawn yet) because the any-combat timer and Elf auto-heal require them. Dwarf drain and hitscan damage are world side effects gated on `is_fresh`.

**Tech Stack:** Godot 4.7.1 GDScript, netfox v1.35.3 (already integrated — see `docs/superpowers/plans/2026-07-15-netfox-integration.md`), GdUnit4.

**PREREQUISITE:** The netfox integration plan must be fully executed first. This plan edits `_rollback_tick`, `PlayerInput`, and `fps_controller.tscn` as they exist AFTER that plan (12 passing tests).

## Global Constraints

- Test command (after every task):
  `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode`
  Expected: `0 errors | 0 failures`, `Exit code: 0`.
- **No gameplay constants in code.** Every number a designer might tune comes from `MatchConfig.get_value()`. Decided 2026-07-16: private hosts tune the game to their taste.
- **Decided semantics (MECHANICS_REFERENCE §2, do not re-litigate):** float core / pip display; any-combat regen gating (taking OR dealing damage, 4 s baseline); hard block on insufficient Resonance; reservations return EMPTY; tech penalty = reservation × archetype multiplier (H 1.0 / T 1.25 / E 1.5 / D 2.0); Dwarf drain destroys (no siphon); Elf auto-heal gated with floor 2; spawn at full minus reservations.
- Tick-based rule: durations are tick counts (`seconds * NetworkTime.tickrate`); no wall-clock, no `_input`-driven state. New rollback state must be registered in `fps_controller.tscn`'s RollbackSynchronizer.
- World side effects (damage to others, drain of others) run only when `is_fresh`.
- GDScript typed style, tabs. Temp files in `.scratch/`.
- Commits end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

## Baseline values (from docs/ABILITY_TUNING_SHEET.md §11 — these are the MatchConfig DEFAULTS)

| Key | Value |
|-----|-------|
| `resonance.combat_timeout_s` | 4.0 |
| `resonance.repulse_cost` | 2.0 |
| `resonance.glide_harness_reservation` | 2.0 |
| `weapon.hitscan_damage` | 10.0 |
| `archetype.human.max_resonance` / `regen_per_s` / `tech_mult` / `max_health` | 10.0 / 0.35 / 1.0 / 100.0 |
| `archetype.elf.max_resonance` / `regen_per_s` / `tech_mult` / `max_health` | 12.0 / 0.8 / 1.5 / 78.0 |
| `archetype.elf.heal_convert_per_s` / `heal_hp_per_resonance` / `heal_resonance_floor` | 0.5 / 8.0 / 2.0 |
| `archetype.dwarf.max_resonance` / `regen_per_s` / `tech_mult` / `max_health` | 14.0 / 0.15 / 2.0 / 95.0 |
| `archetype.dwarf.drain_radius_m` / `drain_per_enemy_per_s` | 6.0 / 0.5 |
| `archetype.troll.max_resonance` / `regen_per_s` / `tech_mult` / `max_health` | 8.0 / 0.0 / 1.25 / 135.0 |

## File Structure

- `scripts/config/match_config.gd` — NEW autoload: tunables registry (Task 1)
- `scripts/player/resonance_pool.gd` — NEW: `ResonancePool` pool math (Task 2)
- `scripts/player/fps_controller.gd` — MODIFY: health, damage, costs, archetype stats, Elf heal, Dwarf aura (Tasks 3–6)
- `scenes/player/fps_controller.tscn` — MODIFY: `Resonance` node + new state properties (Task 3)
- `scripts/ui/resonance_hud.gd` + `scenes/levels/test_arena.tscn` — NEW debug pip HUD (Task 7)
- Tests: `tests/config/test_match_config.gd`, `tests/player/test_resonance_pool.gd`, additions to `tests/player/test_fps_controller.gd`
- Docs: `CLAUDE.md`, `docs/TESTING.md`, `.cspell/custom-dictionary.txt` (Task 8)

---

### Task 1: MatchConfig autoload

**Files:**
- Create: `scripts/config/match_config.gd`
- Modify: `project.godot` (autoload entry)
- Test: `tests/config/test_match_config.gd`

**Interfaces:**
- Produces: autoload `MatchConfig` with `get_value(key: String) -> float`, `set_value(key: String, value: float) -> void` (runtime override, used by tests and later by host sync), `reset_to_defaults() -> void`, and `DEFAULTS: Dictionary` (flat `String -> float`, keys exactly as in the Baseline table). Overrides load from `--match-config=<path>` cmdline user arg, then `user://match_config.json` (flat JSON object, same keys, later source wins).

- [ ] **Step 1: Write the failing test**

Create `tests/config/test_match_config.gd`:

```gdscript
class_name TestMatchConfig
extends GdUnitTestSuite


func after_test() -> void:
	MatchConfig.reset_to_defaults()


func test_defaults_are_loaded() -> void:
	assert_float(MatchConfig.get_value("resonance.repulse_cost")).is_equal(2.0)
	assert_float(MatchConfig.get_value("archetype.troll.max_health")).is_equal(135.0)


func test_unknown_key_pushes_error_and_returns_zero() -> void:
	assert_float(MatchConfig.get_value("no.such.key")).is_equal(0.0)


func test_runtime_override_and_reset() -> void:
	MatchConfig.set_value("resonance.repulse_cost", 5.0)
	assert_float(MatchConfig.get_value("resonance.repulse_cost")).is_equal(5.0)
	MatchConfig.reset_to_defaults()
	assert_float(MatchConfig.get_value("resonance.repulse_cost")).is_equal(2.0)


func test_loads_json_override_file() -> void:
	var path := "user://test_match_config.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"resonance.combat_timeout_s": 9.5}))
	f.close()

	MatchConfig.load_overrides(path)
	assert_float(MatchConfig.get_value("resonance.combat_timeout_s")).is_equal(9.5)
	# Untouched keys keep defaults.
	assert_float(MatchConfig.get_value("resonance.repulse_cost")).is_equal(2.0)

	DirAccess.remove_absolute(path)
```

- [ ] **Step 2: Run to verify it fails**

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/config/test_match_config.gd --ignoreHeadlessMode
```

Expected: FAIL — `MatchConfig` not declared.

- [ ] **Step 3: Implement**

Create `scripts/config/match_config.gd`:

```gdscript
# Match-wide gameplay tunables, injected at game start.
# DESIGN RULE (2026-07-16): no gameplay number is hard-coded anywhere else —
# systems read from here so private hosts can tune the game to their taste.
# Override sources (later wins): --match-config=<path> cmdline user arg,
# then user://match_config.json. Host -> client sync arrives with lobbies.
extends Node

const DEFAULTS: Dictionary = {
	"resonance.combat_timeout_s": 4.0,
	"resonance.repulse_cost": 2.0,
	"resonance.glide_harness_reservation": 2.0,
	"weapon.hitscan_damage": 10.0,
	"archetype.human.max_resonance": 10.0,
	"archetype.human.regen_per_s": 0.35,
	"archetype.human.tech_mult": 1.0,
	"archetype.human.max_health": 100.0,
	"archetype.elf.max_resonance": 12.0,
	"archetype.elf.regen_per_s": 0.8,
	"archetype.elf.tech_mult": 1.5,
	"archetype.elf.max_health": 78.0,
	"archetype.elf.heal_convert_per_s": 0.5,
	"archetype.elf.heal_hp_per_resonance": 8.0,
	"archetype.elf.heal_resonance_floor": 2.0,
	"archetype.dwarf.max_resonance": 14.0,
	"archetype.dwarf.regen_per_s": 0.15,
	"archetype.dwarf.tech_mult": 2.0,
	"archetype.dwarf.max_health": 95.0,
	"archetype.dwarf.drain_radius_m": 6.0,
	"archetype.dwarf.drain_per_enemy_per_s": 0.5,
	"archetype.troll.max_resonance": 8.0,
	"archetype.troll.regen_per_s": 0.0,
	"archetype.troll.tech_mult": 1.25,
	"archetype.troll.max_health": 135.0,
}

var _values: Dictionary = {}


func _ready() -> void:
	reset_to_defaults()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--match-config="):
			load_overrides(arg.trim_prefix("--match-config="))
	if FileAccess.file_exists("user://match_config.json"):
		load_overrides("user://match_config.json")


func get_value(key: String) -> float:
	if not _values.has(key):
		push_error("MatchConfig: unknown key '%s'" % key)
		return 0.0
	return _values[key]


func set_value(key: String, value: float) -> void:
	_values[key] = value


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate()


func load_overrides(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("MatchConfig: cannot read overrides at %s" % path)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is not Dictionary:
		push_warning("MatchConfig: %s is not a JSON object; ignoring" % path)
		return
	for key in parsed:
		if _values.has(key) and (parsed[key] is float or parsed[key] is int):
			_values[key] = float(parsed[key])
		else:
			push_warning("MatchConfig: ignoring unknown/non-numeric key '%s'" % key)
	print("MatchConfig: loaded overrides from %s" % path)
```

Add to `project.godot` `[autoload]` (before the netfox entries so gameplay nodes can read it in `_ready`):

```ini
MatchConfig="*res://scripts/config/match_config.gd"
```

- [ ] **Step 4: Run to verify it passes**

Same command as Step 2. Expected: `4 test cases | 0 errors | 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add scripts/config/match_config.gd tests/config/test_match_config.gd project.godot
git commit -m "feat: MatchConfig tunables registry with JSON host overrides

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: ResonancePool node (pure pool math)

**Files:**
- Create: `scripts/player/resonance_pool.gd`
- Test: `tests/player/test_resonance_pool.gd`

**Interfaces:**
- Produces: `class_name ResonancePool extends Node`. Config vars (set by owner, not rollback state): `max_resonance: float`, `regen_per_s: float`, `combat_timeout_ticks: int`. Rollback state vars: `current: float`, `reserved: float`, `last_combat_tick: int`. Methods: `cap() -> float`, `can_afford(cost: float) -> bool`, `try_spend(cost: float) -> bool`, `reserve(amount: float) -> void`, `release(amount: float) -> void`, `drain(amount: float) -> void`, `mark_combat(tick: int) -> void`, `is_in_combat(tick: int) -> bool`, `process_tick(delta: float, tick: int) -> void`, `fill_to_cap() -> void` (spawn helper).

- [ ] **Step 1: Write the failing test**

Create `tests/player/test_resonance_pool.gd`:

```gdscript
class_name TestResonancePool
extends GdUnitTestSuite

var pool: ResonancePool


func before_test() -> void:
	pool = auto_free(ResonancePool.new())
	pool.max_resonance = 10.0
	pool.regen_per_s = 1.0
	pool.combat_timeout_ticks = 240
	pool.fill_to_cap()


func test_spawns_full_minus_reservations() -> void:
	pool.reserve(2.0)
	assert_float(pool.cap()).is_equal(8.0)
	assert_float(pool.current).is_equal(8.0)


func test_hard_block_spend() -> void:
	assert_bool(pool.try_spend(2.0)).is_true()
	assert_float(pool.current).is_equal(8.0)
	assert_bool(pool.try_spend(9.0)).is_false()
	assert_float(pool.current).is_equal(8.0)


func test_release_returns_empty_capacity() -> void:
	pool.reserve(4.0)          # cap 6, current clamped 10 -> 6
	assert_float(pool.current).is_equal(6.0)
	pool.release(4.0)          # cap back to 10...
	assert_float(pool.cap()).is_equal(10.0)
	assert_float(pool.current).is_equal(6.0)  # ...but pips come back EMPTY


func test_regen_gated_by_combat_timer() -> void:
	pool.drain(5.0)
	pool.mark_combat(1000)
	pool.process_tick(1.0, 1100)           # 100 ticks later: still in combat
	assert_float(pool.current).is_equal(5.0)
	pool.process_tick(1.0, 1241)           # past 240-tick timeout: regen 1.0
	assert_float(pool.current).is_equal(6.0)


func test_regen_respects_cap() -> void:
	pool.reserve(2.0)
	pool.drain(0.5)
	pool.process_tick(10.0, 100000)        # huge regen, must clamp to cap 8
	assert_float(pool.current).is_equal(8.0)


func test_drain_floors_at_zero() -> void:
	pool.drain(99.0)
	assert_float(pool.current).is_equal(0.0)
```

- [ ] **Step 2: Run to verify it fails**

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/player/test_resonance_pool.gd --ignoreHeadlessMode
```

Expected: FAIL — `ResonancePool` not declared.

- [ ] **Step 3: Implement**

Create `scripts/player/resonance_pool.gd`:

```gdscript
# Resonance pool math (MECHANICS_REFERENCE §2, decided 2026-07-16).
# Reservations lock capacity at the top of the pool: cap = max - reserved.
# Releasing a reservation raises the cap but returns the pips EMPTY.
# All mutable vars are netfox rollback state, registered in
# fps_controller.tscn as "Resonance:<name>". process_tick is called from the
# owning controller's _rollback_tick — never from _process.
class_name ResonancePool
extends Node

# Configured by the owner from MatchConfig at spawn (not rollback state).
var max_resonance: float = 10.0
var regen_per_s: float = 0.0
var combat_timeout_ticks: int = 240

# --- Rollback state ---
var current: float = 0.0
var reserved: float = 0.0
var last_combat_tick: int = -(1 << 30)


func cap() -> float:
	return maxf(max_resonance - reserved, 0.0)


func fill_to_cap() -> void:
	current = cap()


func can_afford(cost: float) -> bool:
	return current >= cost


func try_spend(cost: float) -> bool:
	if current < cost:
		return false
	current -= cost
	return true


func reserve(amount: float) -> void:
	reserved += amount
	current = minf(current, cap())


func release(amount: float) -> void:
	# Capacity returns; pips come back EMPTY (must regen). Decided 2026-07-16.
	reserved = maxf(reserved - amount, 0.0)


func drain(amount: float) -> void:
	current = maxf(current - amount, 0.0)


func mark_combat(tick: int) -> void:
	last_combat_tick = maxi(last_combat_tick, tick)


func is_in_combat(tick: int) -> bool:
	return tick - last_combat_tick < combat_timeout_ticks


func process_tick(delta: float, tick: int) -> void:
	if not is_in_combat(tick):
		current = minf(current + regen_per_s * delta, cap())
```

- [ ] **Step 4: Run to verify it passes**

Same command as Step 2. Expected: `6 test cases | 0 errors | 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/resonance_pool.gd tests/player/test_resonance_pool.gd
git commit -m "feat: ResonancePool with empty-return reservations and combat-gated regen

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Wire the pool into FPSController — archetype stats, Repulse cost, Glide reservation

**Files:**
- Modify: `scripts/player/fps_controller.gd`
- Modify: `scenes/player/fps_controller.tscn`
- Test: `tests/player/test_fps_controller.gd` (append)

**Interfaces:**
- Consumes: `MatchConfig` (Task 1), `ResonancePool` (Task 2).
- Produces: `FPSController.archetype: StringName` (`@export`, default `&"human"`); `resonance: ResonancePool` (`$Resonance`); `health: float` rollback state initialized to archetype max; `_config(key_suffix: String) -> float` helper returning `MatchConfig.get_value("archetype.%s.%s" % [archetype, key_suffix])`. Repulse hard-blocks below cost; Glide Harness reservation (`base × tech_mult`) applied at spawn. Tasks 4–6 extend `_rollback_tick` and rely on these names.

- [ ] **Step 1: Append failing tests to `tests/player/test_fps_controller.gd`**

```gdscript
func test_spawns_with_archetype_stats_and_reservation() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	# Human defaults: max 10, harness reservation 2 x 1.0 -> spawn at 8/10.
	assert_float(controller.resonance.max_resonance).is_equal(10.0)
	assert_float(controller.resonance.reserved).is_equal(2.0)
	assert_float(controller.resonance.current).is_equal(8.0)
	assert_float(controller.health).is_equal(100.0)


func test_repulse_spends_resonance() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.input.local_pitch = PITCH_LEVEL

	runner.simulate_action_press("repulse")
	await runner.simulate_frames(5)

	assert_float(controller.resonance.current).is_equal(6.0)


func test_repulse_hard_blocked_when_insufficient() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.resonance.current = 1.0
	var vel_before := controller.velocity

	runner.simulate_action_press("repulse")
	await runner.simulate_frames(5)

	assert_float(controller.resonance.current).is_equal(1.0)
	# No self-push happened.
	assert_float((controller.velocity - vel_before).length()).is_less(2.0)


func test_elf_archetype_reservation_scaled() -> void:
	var runner := scene_runner("res://scenes/player/fps_controller.tscn")
	var controller: FPSController = runner.scene()
	controller.archetype = &"elf"
	controller._apply_archetype_config()

	# Elf: max 12, harness 2 x 1.5 = 3 reserved -> cap 9.
	assert_float(controller.resonance.reserved).is_equal(3.0)
	assert_float(controller.resonance.cap()).is_equal(9.0)
	assert_float(controller.health).is_equal(78.0)
```

- [ ] **Step 2: Run to verify they fail**

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/player/test_fps_controller.gd --ignoreHeadlessMode
```

Expected: FAIL — no `resonance` member.

- [ ] **Step 3: Implement in `scripts/player/fps_controller.gd`**

Add after the existing `@export` block and state vars:

```gdscript
@export var archetype: StringName = &"human"

# --- Rollback state (also registered in fps_controller.tscn) ---
var health: float = 100.0
```

Add to the `@onready` block:

```gdscript
@onready var resonance: ResonancePool = $Resonance
```

In `_ready()`, before `rollback_synchronizer.process_settings()`:

```gdscript
	_apply_archetype_config()
```

Add the methods:

```gdscript
func _config(key_suffix: String) -> float:
	return MatchConfig.get_value("archetype.%s.%s" % [archetype, key_suffix])


func _apply_archetype_config() -> void:
	resonance.max_resonance = _config("max_resonance")
	resonance.regen_per_s = _config("regen_per_s")
	resonance.combat_timeout_ticks = int(roundf(
		MatchConfig.get_value("resonance.combat_timeout_s") * NetworkTime.tickrate))
	resonance.reserved = 0.0
	# Glide Harness is always equipped in the prototype; reservation scales
	# with the archetype tech multiplier (decided 2026-07-16).
	resonance.reserve(
		MatchConfig.get_value("resonance.glide_harness_reservation") * _config("tech_mult"))
	resonance.fill_to_cap()
	health = _config("max_health")
```

In `_rollback_tick`, change the Repulse gate and add the pool tick at the top:

```gdscript
	resonance.process_tick(delta, tick)

	if input.repulse and resonance.try_spend(MatchConfig.get_value("resonance.repulse_cost")):
		_cast_repulse(tick, is_fresh)
```

(The bare `if input.repulse:` line is replaced; everything else stays.)

- [ ] **Step 4: Add the node and state properties to `scenes/player/fps_controller.tscn`**

Add an ext_resource and node:

```
[ext_resource type="Script" path="res://scripts/player/resonance_pool.gd" id="5_resonance"]
```

```
[node name="Resonance" type="Node" parent="."]
script = ExtResource("5_resonance")
```

(Bump `load_steps` by 1.) Extend the RollbackSynchronizer's state list:

```
state_properties = Array[String]([":transform", ":velocity", ":is_gliding", ":glide_ticks_remaining", ":last_down_repulse_tick", ":health", "Resonance:current", "Resonance:reserved", "Resonance:last_combat_tick"])
```

- [ ] **Step 5: Run the full suite**

Global Constraints command. Expected: all tests pass (prior 12 + 4 config + 6 pool + 4 new = 26), `Exit code: 0`.
Note: `test_down_repulse_then_glide_triggers_combo_launch` and friends still pass — a fresh Human spawn affords two Repulses.

- [ ] **Step 6: Commit**

```bash
git add scripts/player/fps_controller.gd scenes/player/fps_controller.tscn tests/player/test_fps_controller.gd
git commit -m "feat: wire Resonance pool, archetype stats, and Repulse/Glide costs into controller

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Health, hitscan damage, and any-combat timer marking

**Files:**
- Modify: `scripts/player/fps_controller.gd`
- Test: `tests/player/test_fps_controller.gd` (append)

**Interfaces:**
- Consumes: Task 3 (`health`, `resonance`).
- Produces: `take_damage(amount: float, attacker: FPSController, tick: int) -> void` — reduces health (floor 0, no death handling yet: log and clamp), marks combat on BOTH victim and attacker (any-combat rule). `_try_shoot` renamed to `_try_shoot(tick: int)` and applies `weapon.hitscan_damage` when it hits an `FPSController`. Damage is only applied from fresh ticks (`_try_shoot` is already fresh-gated at its call site).

- [ ] **Step 1: Append failing tests**

```gdscript
func test_take_damage_marks_both_combatants_and_gates_regen() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()
	var attacker_runner := _spawn_controller()
	var attacker: FPSController = attacker_runner.scene()

	victim.resonance.drain(4.0)
	attacker.resonance.drain(4.0)
	var tick := NetworkTime.tick
	victim.take_damage(10.0, attacker, tick)

	assert_float(victim.health).is_equal(90.0)
	assert_bool(victim.resonance.is_in_combat(tick + 60)).is_true()
	assert_bool(attacker.resonance.is_in_combat(tick + 60)).is_true()
	# Both regen pools frozen while in combat.
	var v := victim.resonance.current
	victim.resonance.process_tick(1.0, tick + 60)
	assert_float(victim.resonance.current).is_equal(v)


func test_health_floors_at_zero() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()

	controller.take_damage(9999.0, controller, NetworkTime.tick)
	assert_float(controller.health).is_equal(0.0)
```

- [ ] **Step 2: Run to verify they fail**

Suite file command (as Task 3 Step 2). Expected: FAIL — no `take_damage`.

- [ ] **Step 3: Implement**

Add to `scripts/player/fps_controller.gd`:

```gdscript
func take_damage(amount: float, attacker: FPSController, tick: int) -> void:
	health = maxf(health - amount, 0.0)
	resonance.mark_combat(tick)
	if attacker != null and attacker != self:
		attacker.resonance.mark_combat(tick)
	if health <= 0.0:
		# Death/respawn arrives with the round-flow plan; clamp for now.
		print("%s down (no death handling yet)" % name)
```

Update `_try_shoot` to take and use the tick, and deal damage:

```gdscript
func _try_shoot(tick: int) -> void:
	var space_state := get_world_3d().direct_space_state
	var from := camera.global_position
	var aim := Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)
	var to := from + (aim * Vector3.FORWARD) * 100.0

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)

	if result and result.collider is FPSController:
		result.collider.take_damage(MatchConfig.get_value("weapon.hitscan_damage"), self, tick)
	elif result:
		print("Hit: ", result.collider.name, " at ", result.position)
```

And its call site in `_rollback_tick`:

```gdscript
	if input.fire and is_fresh:
		_try_shoot(tick)
```

- [ ] **Step 4: Full suite green**

Global Constraints command. Expected: 28 tests, `Exit code: 0`.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/fps_controller.gd tests/player/test_fps_controller.gd
git commit -m "feat: health, hitscan damage, and any-combat regen gating

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Elf auto-heal (gated Resonance → health conversion)

**Files:**
- Modify: `scripts/player/fps_controller.gd`
- Test: `tests/player/test_fps_controller.gd` (append)

**Interfaces:**
- Consumes: Tasks 3–4.
- Produces: per-tick Elf conversion inside `_rollback_tick` (all-archetype safe: rates are config-driven; non-Elf archetypes have no `heal_convert_per_s` key, so guard on archetype).

- [ ] **Step 1: Append failing tests**

```gdscript
func test_elf_converts_resonance_to_health_out_of_combat() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.archetype = &"elf"
	controller._apply_archetype_config()
	controller.health = 50.0

	await runner.simulate_frames(60)  # ~1s out of combat at 60 tps

	assert_float(controller.health).is_greater(50.0)
	assert_float(controller.resonance.current).is_less(controller.resonance.cap())


func test_elf_heal_respects_resonance_floor() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.archetype = &"elf"
	controller._apply_archetype_config()
	controller.health = 1.0
	controller.resonance.current = 2.0  # exactly at the floor

	await runner.simulate_frames(30)

	assert_float(controller.resonance.current).is_equal(2.0)
	assert_float(controller.health).is_equal(1.0)


func test_elf_does_not_heal_in_combat() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.archetype = &"elf"
	controller._apply_archetype_config()
	controller.health = 50.0
	controller.resonance.mark_combat(NetworkTime.tick)

	await runner.simulate_frames(30)

	assert_float(controller.health).is_equal(50.0)


func test_human_does_not_convert() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.health = 50.0

	await runner.simulate_frames(30)

	assert_float(controller.health).is_equal(50.0)
```

- [ ] **Step 2: Run to verify they fail** (suite file command). Expected: first test FAILS (health stays 50).

- [ ] **Step 3: Implement**

In `_rollback_tick`, after `resonance.process_tick(delta, tick)`:

```gdscript
	_process_archetype_passives(delta, tick)
```

Add:

```gdscript
func _process_archetype_passives(delta: float, tick: int) -> void:
	if archetype == &"elf":
		var max_health := _config("max_health")
		if health < max_health and not resonance.is_in_combat(tick):
			var floor_value := _config("heal_resonance_floor")
			if resonance.current > floor_value:
				var convert := minf(_config("heal_convert_per_s") * delta,
					resonance.current - floor_value)
				resonance.drain(convert)
				health = minf(health + convert * _config("heal_hp_per_resonance"), max_health)
```

- [ ] **Step 4: Full suite green** — Global Constraints command; expect 32 tests, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/fps_controller.gd tests/player/test_fps_controller.gd
git commit -m "feat: Elf gated auto-conversion of Resonance to health

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Dwarf drain aura (destroy-only)

**Files:**
- Modify: `scripts/player/fps_controller.gd`
- Test: `tests/player/test_fps_controller.gd` (append)

**Interfaces:**
- Consumes: Tasks 3–5 (`_process_archetype_passives`, `resonance.drain`).
- Produces: passive Dwarf aura draining nearby enemies' pools (`drain_radius_m`, `drain_per_enemy_per_s`); drained Resonance is destroyed, not siphoned (decided 2026-07-16). Cross-player state mutation runs on fresh ticks only.

- [ ] **Step 1: Append failing tests**

```gdscript
func test_dwarf_aura_drains_nearby_enemy() -> void:
	var runner := _spawn_controller()
	var dwarf: FPSController = runner.scene()
	dwarf.archetype = &"dwarf"
	dwarf._apply_archetype_config()

	var victim_runner := _spawn_controller()
	var victim: FPSController = victim_runner.scene()
	victim.global_position = dwarf.global_position + Vector3(2, 0, 0)
	var start := victim.resonance.current

	await runner.simulate_frames(60)  # ~1s in aura

	assert_float(victim.resonance.current).is_less(start)
	# Destroy-only: the dwarf gains nothing beyond its own (slow) regen cap.
	assert_float(dwarf.resonance.current).is_less_equal(dwarf.resonance.cap())


func test_dwarf_aura_ignores_distant_players() -> void:
	var runner := _spawn_controller()
	var dwarf: FPSController = runner.scene()
	dwarf.archetype = &"dwarf"
	dwarf._apply_archetype_config()

	var victim_runner := _spawn_controller()
	var victim: FPSController = victim_runner.scene()
	victim.global_position = dwarf.global_position + Vector3(50, 0, 0)
	var start := victim.resonance.current

	await runner.simulate_frames(30)

	assert_float(victim.resonance.current).is_equal(start)
```

- [ ] **Step 2: Run to verify they fail** (suite file command). Expected: first test FAILS (no drain).

- [ ] **Step 3: Implement**

Extend `_process_archetype_passives` — note the signature gains `is_fresh` (update the call site to `_process_archetype_passives(delta, tick, is_fresh)`):

```gdscript
func _process_archetype_passives(delta: float, tick: int, is_fresh: bool) -> void:
	if archetype == &"elf":
		var max_health := _config("max_health")
		if health < max_health and not resonance.is_in_combat(tick):
			var floor_value := _config("heal_resonance_floor")
			if resonance.current > floor_value:
				var convert := minf(_config("heal_convert_per_s") * delta,
					resonance.current - floor_value)
				resonance.drain(convert)
				health = minf(health + convert * _config("heal_hp_per_resonance"), max_health)
	if archetype == &"dwarf" and is_fresh:
		# Cross-player state writes run on fresh ticks only, like Repulse
		# pushes. Drained Resonance is destroyed, never siphoned.
		var radius := _config("drain_radius_m")
		var rate := _config("drain_per_enemy_per_s")
		for node in get_tree().get_nodes_in_group("players"):
			var other := node as FPSController
			if other == null or other == self:
				continue
			if other.global_position.distance_to(global_position) <= radius:
				other.resonance.drain(rate * delta)
```

Add group registration in `_ready()` (first line):

```gdscript
	add_to_group("players")
```

- [ ] **Step 4: Full suite green** — Global Constraints command; expect 34 tests, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/fps_controller.gd tests/player/test_fps_controller.gd
git commit -m "feat: Dwarf destroy-only Resonance drain aura

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Debug pip HUD + live verification

**Files:**
- Create: `scripts/ui/resonance_hud.gd`
- Modify: `scenes/levels/test_arena.tscn` (add HUD under the existing CanvasLayer)

**Interfaces:**
- Consumes: local player's `resonance` pool and `health` (Tasks 3–5).
- Produces: a debug HUD Label showing pips: filled `●`, partial `◐`, empty `○`, reserved/locked `▣`, plus health — enough to playtest the economy; the real HUD is a later plan.

- [ ] **Step 1: Create `scripts/ui/resonance_hud.gd`**

```gdscript
# Debug Resonance pip display. Attach to a Label under a CanvasLayer.
# Filled ● / partial ◐ / empty ○ / reserved ▣  — plus health readout.
extends Label

@export var player_path: NodePath = ^"/root/TestArena/FPSController"

var _player: FPSController


func _ready() -> void:
	_player = get_node_or_null(player_path) as FPSController


func _process(_delta: float) -> void:
	if _player == null:
		text = "Resonance: no player"
		return
	var pool := _player.resonance
	var pips := ""
	var whole := int(floorf(pool.current))
	var frac := pool.current - float(whole)
	for i in range(int(roundf(pool.max_resonance))):
		if i < whole:
			pips += "●"
		elif i == whole and frac > 0.05:
			pips += "◐"
		elif i >= int(roundf(pool.cap())):
			pips += "▣"
		else:
			pips += "○"
	text = "Resonance %s  %.1f/%.0f (cap %.0f)\nHealth %.0f" % [
		pips, pool.current, pool.max_resonance, pool.cap(), _player.health]
```

- [ ] **Step 2: Add to `scenes/levels/test_arena.tscn`**

Add ext_resource (bump `load_steps`):

```
[ext_resource type="Script" path="res://scripts/ui/resonance_hud.gd" id="4_resonance_hud"]
```

Add under the existing `CanvasLayer` node:

```
[node name="ResonanceHud" type="Label" parent="CanvasLayer"]
offset_left = 20.0
offset_top = 60.0
offset_right = 500.0
offset_bottom = 120.0
theme_override_font_sizes/font_size = 18
text = "Resonance: ..."
script = ExtResource("4_resonance_hud")
```

- [ ] **Step 3: Live verification via MCP TCP**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5000 >/dev/null 2>&1 &
sleep 4
python3 - <<'EOF'
import socket, json, time
s = socket.create_connection(("127.0.0.1", 9090), timeout=5); f = s.makefile("r")
def cmd(c, p=None, i=1):
    s.sendall((json.dumps({"id": i, "command": c, "params": p or {}}) + "\n").encode())
    return json.loads(f.readline())
# Fire two Repulses; pool should drop 8 -> 4 (Human, cost 2 each).
print(cmd("get_property", {"node_path": "/root/TestArena/FPSController/Resonance", "property": "current"}, 1))
cmd("click", {"button": "right"}, 2); time.sleep(0.3)
cmd("click", {"button": "right"}, 3); time.sleep(0.3)
print(cmd("get_property", {"node_path": "/root/TestArena/FPSController/Resonance", "property": "current"}, 4))
print(cmd("get_property", {"node_path": "/root/TestArena/CanvasLayer/ResonanceHud", "property": "text"}, 5))
s.close()
EOF
```

Expected: first `current` = 8.0, second = 4.0, HUD text shows 4 filled pips and 2 locked (`▣▣`).
If the MCP `click` right-button syntax doesn't trigger the action, replace each `click` call with this exact eval (presses and releases the InputMap action directly):
`cmd("eval", {"code": "Input.action_press(\"repulse\")\nawait get_tree().process_frame\nInput.action_release(\"repulse\")\nreturn true"})` — the assertion on `current` is what matters.

- [ ] **Step 4: Full suite green** — Global Constraints command; expect 34 tests, exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/resonance_hud.gd scenes/levels/test_arena.tscn
git commit -m "feat: debug Resonance pip HUD in test arena

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Documentation + spell-check pass

**Files:**
- Modify: `CLAUDE.md`, `docs/TESTING.md`, `docs/PRD.md`, `.cspell/custom-dictionary.txt`

- [ ] **Step 1: `CLAUDE.md`** — add to the Testing/conventions area: all gameplay numbers come from the `MatchConfig` autoload (`scripts/config/match_config.gd`) — never hard-code a tunable; add new keys to `DEFAULTS` and the baselines table in `docs/ABILITY_TUNING_SHEET.md` §11. Host overrides: `user://match_config.json` or `--match-config=<path>`.

- [ ] **Step 2: `docs/TESTING.md`** — note the pattern for testing config-driven mechanics: override via `MatchConfig.set_value()` in tests and `reset_to_defaults()` in `after_test`.

- [ ] **Step 3: `docs/PRD.md`** — in Phase 0 roadmap, mark the Resonance bullet done: `Resonance resource system + ability framework (Repulse, Glide Harness first...) ✅ (Resonance + costs; framework grows with each Manifestation)`.

- [ ] **Step 4: Spell check**

```bash
npx -y cspell --no-progress docs/ CLAUDE.md scripts/ 2>&1 | tail -5
```

Expected `Issues found: 0`; add any flagged legitimate terms (likely `tunables`) to `.cspell/custom-dictionary.txt` alphabetically.

- [ ] **Step 5: Final verification + commit**

Global Constraints test command (34 tests, exit 0), then:

```bash
git add CLAUDE.md docs/ .cspell/custom-dictionary.txt
git commit -m "docs: MatchConfig conventions and Resonance milestone notes

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Known risks & notes (for the executor)

- **Two controllers in one test scene** (Tasks 4/6): each `_spawn_controller()` creates its own SceneRunner scene; both controllers tick under the same NetworkTime. If the second runner's scene doesn't share the tree with the first, place the victim into the first runner's scene instead: `runner.scene().add_child(victim_controller)` with a plain instantiated scene rather than a second runner. The group-based Dwarf lookup (`get_nodes_in_group("players")`) works across the whole tree either way.
- **`resonance.current` in prediction:** the pool is state, spends happen in the tick simulation, so a mispredicted spend (e.g. Repulse fired the tick before a server correction) rolls back cleanly. Do not move spends outside `_rollback_tick`.
- **No death yet is intentional** — round flow/respawn is its own plan; `take_damage` clamps at 0 and logs.
- **Elf conversion + any-combat interplay:** dealing damage also freezes Elf healing (any-combat rule). This is the decided design; if playtests hate it, the knob is `resonance.combat_timeout_s`, not code.
