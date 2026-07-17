# Combat Blade + Third-Person Melee Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Combat Blade (katana-style): third-person camera while wielded, swing + backstab detection, non-stacking bleed (which must produce the emergent Elf equilibrium), blade-vs-blade blocking, and archetype-strength damage scaling.

**Architecture:** The blade is a `WeaponBase` subclass using a shape sweep instead of rays. The third-person view is a local-only camera swap (a SpringArm3D rig activates while the blade is the active weapon — simulation still aims from recorded `aim_yaw`/`aim_pitch`, so netcode is untouched). Bleed is rollback state on the victim controller, ticked in `_rollback_tick`, and deliberately does **not** mark combat — the decided Elf equilibrium (bleed 4 HP/s == Elf heal 4 HP/s) must emerge from the two systems interacting, never from an override. Blocking reads the victim's own replicated `ads` input while their blade is active.

**Tech Stack:** Godot 4.7.1 GDScript, netfox v1.35.3, GdUnit4, MatchConfig.

**PREREQUISITES (in order):** netfox plan → Resonance plan → **Weapon System plan** (provides `WeaponBase`, `WeaponRig`, hit zones, `take_zone_damage`, input fields). Execute this plan last.

## Global Constraints

Same as the Weapon System plan (test command, MatchConfig-only tunables, typed GDScript, `.scratch/`, co-author line). Decided design (MECHANICS_REFERENCE §5): third-person while wielded; damage scales with archetype strength; backstab imparts bleed (no stack, refresh, no combat marking); blocks other blades. Slow TTK baselines in ABILITY_TUNING_SHEET §11.

## MatchConfig DEFAULTS additions (Task 1)

```gdscript
	"weapon.blade.damage": 25.0, "weapon.blade.backstab_mult": 1.6,
	"weapon.blade.swing_interval_s": 0.6, "weapon.blade.range_m": 2.2,
	"weapon.blade.arc_deg": 70.0, "weapon.blade.weight": 0.0,
	# Base-pipeline keys the shared WeaponBase code reads before BladeWeapon
	# overrides them away (prevents unknown-key push_errors, which GdUnit
	# treats as failures): sentinel values.
	"weapon.blade.mag": 1.0, "weapon.blade.reserve": 0.0,
	"weapon.blade.reload_s": 0.1, "weapon.blade.fire_interval_s": 0.6,
	"weapon.blade.head_mult": 1.0, "weapon.blade.falloff_start_m": 999.0,
	"weapon.blade.falloff_end_m": 999.0, "weapon.blade.falloff_min_mult": 1.0,
	"weapon.blade.bleed_hp_s": 4.0, "weapon.blade.bleed_duration_s": 8.0,
	"weapon.blade.block_mult": 0.3, "weapon.blade.backstab_cone_deg": 100.0,
	"archetype.human.melee_mult": 1.0,
	"archetype.elf.melee_mult": 0.8,
	"archetype.dwarf.melee_mult": 1.0,
	"archetype.troll.melee_mult": 1.4,
```

## File Structure

- `scripts/config/match_config.gd` — MODIFY: keys above (Task 1)
- `scripts/player/fps_controller.gd` — MODIFY: bleed state + tick, `is_blocking()`, camera swap (Tasks 1–2)
- `scenes/player/fps_controller.tscn` — MODIFY: Blade weapon node + FireAction, SpringArm rig, state registration (Tasks 1–2)
- `scripts/weapons/blade.gd` — NEW: `BladeWeapon` (Task 3)
- Tests: `tests/weapons/test_blade.gd`, appends to `tests/player/test_fps_controller.gd`
- Docs (final task)

---

### Task 1: Bleed state on the controller (+ config keys + Blade node stub)

**Files:**
- Modify: `scripts/config/match_config.gd`, `scripts/player/fps_controller.gd`, `scenes/player/fps_controller.tscn`
- Test: `tests/player/test_fps_controller.gd` (append)

**Interfaces:**
- Produces: controller rollback state `bleed_ticks_remaining: int`, `bleed_hp_per_s: float`; method `apply_bleed(hp_per_s: float, duration_s: float) -> void` (no stack — re-apply refreshes duration and takes the higher rate); bleed damage applied per tick in `_rollback_tick` via direct `health` reduction — **not** through `take_damage` (which would `mark_combat`; bleed must not). Scene gains `Blade` node (script `weapon_base.gd` for now, `weapon_key = "blade"`, `weight_class = 0`) + `FireAction` child; state registration for `Blade:mag` etc. (unused but harmless — blade overrides ammo away in Task 3) plus `:bleed_ticks_remaining`, `:bleed_hp_per_s`.

- [ ] **Step 1: Append failing tests:**

```gdscript
func test_bleed_damages_without_marking_combat() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()
	var start_health := victim.health

	victim.apply_bleed(4.0, 8.0)
	await runner.simulate_frames(60)  # ~1s

	assert_float(victim.health).is_less(start_health)
	assert_float(victim.health).is_greater(start_health - 8.0)  # ~4 HP lost
	assert_bool(victim.resonance.is_in_combat(NetworkTime.tick)).is_false()


func test_bleed_refreshes_does_not_stack() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()

	victim.apply_bleed(4.0, 8.0)
	var first := victim.bleed_ticks_remaining
	await runner.simulate_frames(30)
	victim.apply_bleed(4.0, 8.0)

	assert_int(victim.bleed_ticks_remaining).is_between(first - 5, first + 5)
	assert_float(victim.bleed_hp_per_s).is_equal(4.0)


func test_bleeding_elf_holds_health_while_resonance_drains() -> void:
	# THE decided equilibrium: bleed 4 HP/s vs Elf heal 4 HP/s must cancel
	# emergently. Elf must be out of combat for the heal to run.
	var runner := _spawn_controller()
	var elf: FPSController = runner.scene()
	elf.archetype = &"elf"
	elf._apply_archetype_config()
	elf.health = 60.0
	var start_res := elf.resonance.current

	elf.apply_bleed(4.0, 8.0)
	await runner.simulate_frames(120)  # ~2s

	assert_float(elf.health).is_equal_approx(60.0, 1.5)
	assert_float(elf.resonance.current).is_less(start_res)
```

- [ ] **Step 2: Run** controller suite → FAIL (no `apply_bleed`).
- [ ] **Step 3: Implement.** Config keys from the block above. Controller additions:

```gdscript
# --- Rollback state (bleed; registered in fps_controller.tscn) ---
var bleed_ticks_remaining: int = 0
var bleed_hp_per_s: float = 0.0
```

```gdscript
func apply_bleed(hp_per_s: float, duration_s: float) -> void:
	# No stacking (decided 2026-07-16): refresh duration, keep higher rate.
	bleed_ticks_remaining = int(roundf(duration_s * NetworkTime.tickrate))
	bleed_hp_per_s = maxf(bleed_hp_per_s, hp_per_s)
```

In `_rollback_tick`, after `_process_archetype_passives(...)`:

```gdscript
	if bleed_ticks_remaining > 0:
		bleed_ticks_remaining -= 1
		# Direct health reduction: bleed must NOT mark combat (decided) —
		# the Elf equilibrium depends on the heal running concurrently.
		health = maxf(health - bleed_hp_per_s * delta, 0.0)
		if bleed_ticks_remaining == 0:
			bleed_hp_per_s = 0.0
```

Scene: add Blade + FireAction nodes and the state registrations listed in Interfaces.

- [ ] **Step 4: Run** full suite → green (equilibrium test is the key gate). **Step 5: Commit** `feat: non-stacking bleed with emergent Elf equilibrium`.

---

### Task 2: Third-person camera while blade is wielded

**Files:**
- Modify: `scenes/player/fps_controller.tscn`, `scripts/player/fps_controller.gd`
- Test: `tests/player/test_fps_controller.gd` (append)

**Interfaces:**
- Produces: scene nodes `ThirdPersonRig` (Node3D at y 1.6) → `SpringArm3D` (`spring_length = 3.5`, pitched by view) → `ThirdPersonCamera` (Camera3D, `current = false`). Controller `_process` (all view-only, local player only): when `weapon_rig.active_weapon()` is the blade, `camera.current = false; third_person_camera.current = true`, rig yaw/pitch follow `input.local_yaw/local_pitch`; otherwise first-person camera current. `@onready var third_person_camera: Camera3D` and `@onready var third_person_rig: Node3D`.

- [ ] **Step 1: Append failing test:**

```gdscript
func test_blade_switches_to_third_person_camera() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	controller.weapon_rig.grant("blade", 1)
	controller.weapon_rig.active_slot = 1
	await runner.simulate_frames(5)

	assert_bool(controller.third_person_camera.current).is_true()
	assert_bool(controller.camera.current).is_false()

	runner.simulate_action_press("weapon_slot_2")
	await runner.simulate_frames(5)
	assert_bool(controller.camera.current).is_true()
	assert_bool(controller.third_person_camera.current).is_false()
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** scene nodes and, in `_process` (after the ADS block; guard on `input.is_multiplayer_authority()` which the method already has):

```gdscript
	var blade_out := active != null and active.weapon_key == "blade"
	if blade_out != third_person_camera.current:
		third_person_camera.current = blade_out
		camera.current = not blade_out
	if blade_out:
		third_person_rig.rotation = Vector3(input.local_pitch * 0.5, 0, 0)
```

(Yaw is inherited from the body, which `_rollback_tick` already turns to `aim_yaw`.)

- [ ] **Step 4: Run** → green. **Step 5: Commit** `feat: third-person camera while blade is wielded`.

---

### Task 3: BladeWeapon — sweep, archetype scaling, backstab bleed

**Files:**
- Create: `scripts/weapons/blade.gd`; modify scene (Blade node script)
- Test: `tests/weapons/test_blade.gd`

**Interfaces:**
- Produces: `class_name BladeWeapon extends WeaponBase`. Overrides: `_wants_fire()` = edge `input.fire`; `_can_fire` without ammo checks (blade has no mag — override `initialize_ammo` to no-op with `mag = 1.0` sentinel kept full; simpler: override `_can_fire(tick)` to only check active + swing interval); `_fire(tick)` replaced by a sphere-sweep melee resolve: victims within `range_m` and inside `arc_deg` of aim get `damage × attacker melee_mult`; if the attacker is within the victim's rear cone (`backstab_cone_deg` around victim's backward facing), damage ×`backstab_mult` and `victim.apply_bleed(bleed_hp_s, bleed_duration_s)`; blocking (Task 4) checked before damage. Victims propagated via `NetworkRollback.mutate`.

- [ ] **Step 1: Write failing tests** (`tests/weapons/test_blade.gd`):

```gdscript
class_name TestBlade
extends GdUnitTestSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()


func _blade_duel() -> Array:
	var runner := scene_runner(CONTROLLER_SCENE)
	var attacker: FPSController = runner.scene()
	attacker.weapon_rig.grant("blade", 1)
	attacker.weapon_rig.active_slot = 1
	var victim: FPSController = (load(CONTROLLER_SCENE) as PackedScene).instantiate()
	attacker.get_parent().add_child(victim)
	victim.global_position = attacker.global_position + Vector3(0, 0, -1.5)
	return [runner, attacker, victim]


func _swing(runner: GdUnitSceneRunner) -> void:
	runner.simulate_action_press("fire_primary")
	await runner.simulate_frames(5)
	runner.simulate_action_release("fire_primary")


func test_frontal_swing_damages_without_bleed() -> void:
	var trio := _blade_duel()
	var runner: GdUnitSceneRunner = trio[0]
	var victim: FPSController = trio[2]
	# Victim faces the attacker (attacker is at +Z of victim): front hit.
	victim.rotation.y = PI
	await _swing(runner)

	assert_float(victim._config("max_health") - victim.health).is_equal_approx(25.0, 0.1)
	assert_int(victim.bleed_ticks_remaining).is_equal(0)


func test_backstab_multiplies_and_bleeds() -> void:
	var trio := _blade_duel()
	var runner: GdUnitSceneRunner = trio[0]
	var victim: FPSController = trio[2]
	# Victim faces AWAY from the attacker: backstab.
	victim.rotation.y = 0.0
	await _swing(runner)

	assert_float(victim._config("max_health") - victim.health).is_equal_approx(40.0, 0.1)
	assert_int(victim.bleed_ticks_remaining).is_greater(0)


func test_troll_melee_hits_harder() -> void:
	var trio := _blade_duel()
	var runner: GdUnitSceneRunner = trio[0]
	var attacker: FPSController = trio[1]
	var victim: FPSController = trio[2]
	attacker.archetype = &"troll"
	attacker._apply_archetype_config()
	victim.rotation.y = PI
	await _swing(runner)

	assert_float(victim._config("max_health") - victim.health).is_equal_approx(35.0, 0.1)
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** `blade.gd`:

```gdscript
class_name BladeWeapon
extends WeaponBase


func initialize_ammo() -> void:
	mag = 1.0
	reserve = 0.0


func _can_fire(tick: int) -> bool:
	return _rig.active_weapon() == self \
		and NetworkTime.seconds_between(last_fire_tick, tick) >= config("swing_interval_s")


func _fire(tick: int) -> void:
	last_fire_tick = tick
	var me := _controller()
	var origin := me.global_position + Vector3(0, 1.2, 0)
	var forward := _aim_basis() * Vector3.FORWARD
	var arc := deg_to_rad(config("arc_deg")) * 0.5
	for node in me.get_tree().get_nodes_in_group("players"):
		var victim := node as FPSController
		if victim == null or victim == me:
			continue
		var to_victim := victim.global_position + Vector3(0, 1.2, 0) - origin
		if to_victim.length() > config("range_m"):
			continue
		if forward.angle_to(to_victim.normalized()) > arc:
			continue
		_strike(victim, me, tick)


func _strike(victim: FPSController, me: FPSController, tick: int) -> void:
	var damage := config("damage") * me._config("melee_mult")
	var victim_back := -(victim.transform.basis * Vector3.FORWARD)
	var from_victim := (me.global_position - victim.global_position).normalized()
	var is_backstab := victim_back.angle_to(from_victim) \
		<= deg_to_rad(config("backstab_cone_deg")) * 0.5
	if is_backstab:
		damage *= config("backstab_mult")
	if victim.is_blocking() and not is_backstab:
		damage *= config("block_mult")
	victim.take_damage(damage, me, tick)
	if is_backstab:
		victim.apply_bleed(config("bleed_hp_s"), config("bleed_duration_s"))
	NetworkRollback.mutate(victim)
```

Note the Godot forward convention: `Basis * Vector3.FORWARD` = `-basis.z`; the victim's *back* direction is `+basis.z`, i.e. `victim.transform.basis.z` — verify against the frontal/backstab tests and flip if inverted (the tests are the ground truth: victim at `-Z` of attacker, `rotation.y = PI` means facing attacker). Add `func is_blocking() -> bool: return false` stub on `FPSController` this task (real logic Task 4). Set the Blade scene node's script.

- [ ] **Step 4: Run** → green. **Step 5: Commit** `feat: blade sweep with archetype scaling and backstab bleed`.

---

### Task 4: Blocking (blade vs blade)

**Files:**
- Modify: `scripts/player/fps_controller.gd`
- Test: `tests/weapons/test_blade.gd` (append)

**Interfaces:**
- Produces: real `is_blocking() -> bool` — true when the player's active weapon is the blade AND their replicated `ads` input is held. Frontal blade damage ×`block_mult` (already wired in `_strike`; backstabs bypass).

- [ ] **Step 1: Append failing test:**

```gdscript
func test_frontal_block_reduces_blade_damage() -> void:
	var trio := _blade_duel()
	var runner: GdUnitSceneRunner = trio[0]
	var victim: FPSController = trio[2]
	victim.rotation.y = PI
	victim.weapon_rig.grant("blade", 1)
	victim.weapon_rig.active_slot = 1
	victim.input.ads = true  # inject replicated block input directly
	await _swing(runner)

	assert_float(victim._config("max_health") - victim.health).is_equal_approx(7.5, 0.1)
```

- [ ] **Step 2: Run** → FAIL (full 25 damage). **Step 3: Implement:**

```gdscript
func is_blocking() -> bool:
	var active := weapon_rig.active_weapon()
	return active != null and active.weapon_key == "blade" and input.ads
```

- [ ] **Step 4: Run** → green. **Step 5: Commit** `feat: blade blocking on hold-ads`.

---

### Task 5: Live verification + docs

- [ ] **Step 1: MCP live check:** run test arena headless; via TCP `eval`: grant blade (`c.weapon_rig.grant("blade", 1)`), select slot 1, confirm `third_person_camera.current == true`; spawn a second controller behind-facing, swing via `Input.action_press("fire_primary")` eval, read victim `bleed_ticks_remaining > 0`.
- [ ] **Step 2:** `docs/PRD.md` — weapons Phase 0 note gains "+ melee/third-person ✅". `docs/ABILITY_TUNING_SHEET.md` — log any baseline changes discovered during implementation. `CLAUDE.md` — one line: blade/backstab/bleed pattern lives in `scripts/weapons/blade.gd`; bleed never calls `take_damage`.
- [ ] **Step 3:** cspell pass (add `backstab` variants already present; add new flags). Full suite green.
- [ ] **Step 4: Commit** `docs: melee system notes` (with co-author line).

---

## Known risks & notes (for the executor)

- **The Elf equilibrium test (Task 1) is the contract for the whole bleed design.** If it fails, check: bleed must not call `take_damage`/`mark_combat`; Elf heal rate is `heal_convert_per_s (0.5) × heal_hp_per_resonance (8) = 4 HP/s`; both tick in the same `_rollback_tick`.
- **Basis direction conventions** are the likeliest bug source in backstab detection — trust the tests, not intuition; flip signs until frontal/backstab tests both pass.
- **Third-person camera is view-only** — no rollback/state registration for any camera node. If the camera ever influences simulation, that's a design violation.
- **Blade swing uses group iteration, not physics sweep** — adequate at ≤16 players; revisit if profiling says otherwise (it's inside rollback resimulation).
- **`input.ads` injection in the block test** bypasses input gathering intentionally (the victim has no real input source in tests); the game path replicates `ads` via netfox input properties already.
