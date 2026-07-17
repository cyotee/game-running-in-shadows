# Weapon System (Framework + 5 Guns) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Weapon framework (2 slots, switching, mags + finite reserve, reload, hit zones, hybrid recoil, movement weight) plus Pistol, SMG, Shotgun, Rifle (3-burst + ADS), and Sniper (high-zoom ADS) — all netfox-rollback-native with lag-compensated hitscan.

**Architecture:** Follows netfox's official `examples/rollback-fps` weapon pattern: each weapon is a static scene node with a `RewindableAction` child; firing is decided in `_rollback_tick` (`set_active` from input → `CONFIRMING/ACTIVE` fires, `CANCELLING` undoes), raycasts run inside the rollback so resimulation makes them lag-compensated for free, and victims are propagated via `NetworkRollback.mutate()`. All ammo/heat/cooldown state is rollback state. Hit zones are Area3D children (head/body/limbs) on a dedicated physics layer. Every number comes from MatchConfig.

**Tech Stack:** Godot 4.7.1 GDScript, netfox v1.35.3 (`RewindableAction`, `NetworkRollback.mutate`), GdUnit4, MatchConfig autoload.

**PREREQUISITES (execute in order):** 1) netfox integration plan (2026-07-15), 2) Resonance plan (2026-07-16 — provides `MatchConfig`, `health`, `take_damage`, archetype config). The melee/third-person plan (same date, `-melee` suffix) executes AFTER this one.

## Global Constraints

- Test command (after every task):
  `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests --ignoreHeadlessMode` → `0 errors | 0 failures`, exit 0.
- All tunables via `MatchConfig` (add keys to `DEFAULTS`); recoil *patterns* are the one exception: they are `PackedVector2Array` data on weapon scenes, scaled by a MatchConfig factor.
- Decided design (MECHANICS_REFERENCE §5, do not re-litigate): head/body/limb zones (head ×2.0 baseline, limb ×0.75, Dwarf head→body); hybrid recoil; mags + finite reserve; 2 slots with replaceable pistol; slow/arena TTK (baselines in ABILITY_TUNING_SHEET §11); world side effects fresh-tick/confirm-gated.
- Weapon fire code must skip when `rollback_synchronizer.is_predicting()` (upstream pattern).
- Randomness must be deterministic per (tick, peer, index): use `rand_from_seed(hash([tick, multiplayer.get_unique_id(), i]))` — never `randf()` in simulation.
- GDScript typed, tabs; temp files in `.scratch/`; commits end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

## Baseline values → MatchConfig DEFAULTS additions (Task 1)

```gdscript
	# --- Weapons (slow/arena TTK; see ABILITY_TUNING_SHEET §11) ---
	"zones.head_mult_default": 2.0,
	"zones.limb_mult": 0.75,
	"weapon.pistol.damage": 12.0, "weapon.pistol.head_mult": 2.0,
	"weapon.pistol.fire_interval_s": 0.35, "weapon.pistol.mag": 12.0,
	"weapon.pistol.reserve": 36.0, "weapon.pistol.reload_s": 1.4,
	"weapon.pistol.falloff_start_m": 15.0, "weapon.pistol.falloff_end_m": 35.0,
	"weapon.pistol.falloff_min_mult": 0.5, "weapon.pistol.weight": 0.0,
	"weapon.smg.damage": 7.0, "weapon.smg.head_mult": 1.5,
	"weapon.smg.fire_interval_s": 0.08, "weapon.smg.mag": 30.0,
	"weapon.smg.reserve": 90.0, "weapon.smg.reload_s": 1.8,
	"weapon.smg.falloff_start_m": 12.0, "weapon.smg.falloff_end_m": 30.0,
	"weapon.smg.falloff_min_mult": 0.4, "weapon.smg.weight": 0.0,
	"weapon.smg.bloom_per_shot_deg": 0.15, "weapon.smg.bloom_max_deg": 3.0,
	"weapon.smg.bloom_decay_deg_s": 3.0,
	"weapon.shotgun.damage": 6.0, "weapon.shotgun.head_mult": 1.5,
	"weapon.shotgun.pellets": 8.0, "weapon.shotgun.cone_deg": 5.0,
	"weapon.shotgun.fire_interval_s": 0.9, "weapon.shotgun.mag": 6.0,
	"weapon.shotgun.reserve": 24.0, "weapon.shotgun.reload_s": 2.4,
	"weapon.shotgun.falloff_start_m": 6.0, "weapon.shotgun.falloff_end_m": 18.0,
	"weapon.shotgun.falloff_min_mult": 0.2, "weapon.shotgun.weight": 1.0,
	"weapon.rifle.damage": 11.0, "weapon.rifle.head_mult": 2.0,
	"weapon.rifle.burst_count": 3.0, "weapon.rifle.burst_intra_s": 0.1,
	"weapon.rifle.fire_interval_s": 0.5, "weapon.rifle.mag": 24.0,
	"weapon.rifle.reserve": 72.0, "weapon.rifle.reload_s": 2.0,
	"weapon.rifle.falloff_start_m": 30.0, "weapon.rifle.falloff_end_m": 70.0,
	"weapon.rifle.falloff_min_mult": 0.6, "weapon.rifle.weight": 1.0,
	"weapon.rifle.ads_zoom": 1.6,
	"weapon.sniper.damage": 55.0, "weapon.sniper.head_mult": 2.0,
	"weapon.sniper.fire_interval_s": 1.4, "weapon.sniper.mag": 5.0,
	"weapon.sniper.reserve": 15.0, "weapon.sniper.reload_s": 2.8,
	"weapon.sniper.falloff_start_m": 999.0, "weapon.sniper.falloff_end_m": 999.0,
	"weapon.sniper.falloff_min_mult": 1.0, "weapon.sniper.weight": 2.0,
	"weapon.sniper.ads_zoom": 4.0,
	"weapon.recoil_scale": 1.0,
	# Movement weight speed multipliers: weight class 0=light 1=medium 2=heavy
	"weight.medium.human": 0.95, "weight.medium.elf": 0.85,
	"weight.medium.dwarf": 0.95, "weight.medium.troll": 1.0,
	"weight.heavy.human": 0.85, "weight.heavy.elf": 0.65,
	"weight.heavy.dwarf": 0.85, "weight.heavy.troll": 0.93,
```

(Light = ×1.0 for everyone — no keys needed; `_weight_mult` returns 1.0 for weight 0.)

## File Structure

- `project.godot` — MODIFY: input actions `ads`, `reload`, `weapon_slot_1`, `weapon_slot_2`; **repulse default binding moves RMB → E** (ADS takes RMB; actions are binding-agnostic so tests are unaffected)
- `scripts/player/player_input.gd` — MODIFY: `fire_held`, `ads`, `reload`, `slot_select` inputs
- `scripts/player/fps_controller.gd` — MODIFY: zone damage routing, weight multiplier, WeaponRig hookup
- `scenes/player/fps_controller.tscn` — MODIFY: hit-zone Areas, WeaponRig + 5 weapon nodes, state/input property registration
- `scripts/weapons/weapon_base.gd` — NEW: shared fire pipeline (`WeaponBase`)
- `scripts/weapons/{pistol,smg,shotgun,rifle,sniper}.gd` — NEW: per-weapon behavior
- `scripts/weapons/weapon_rig.gd` — NEW: slots/ownership/switching (`WeaponRig`)
- Tests: `tests/weapons/test_weapon_rig.gd`, `tests/weapons/test_weapon_fire.gd`, `tests/weapons/test_weapon_variants.gd`, additions to `tests/player/test_fps_controller.gd`
- Docs (final task): `CLAUDE.md`, `docs/PRD.md`, `.cspell/custom-dictionary.txt`, test-arena `DebugLabel` text

---

### Task 1: Inputs, bindings, and MatchConfig weapon keys

**Files:**
- Modify: `project.godot`, `scripts/player/player_input.gd`, `scripts/config/match_config.gd`
- Test: `tests/player/test_player_input.gd` (append)

**Interfaces:**
- Produces: PlayerInput networked fields `fire_held: bool` (level), `ads: bool` (level), `reload: bool` (edge-latched), `slot_select: int` (0 = none, else 1/2, edge-latched); existing `fire` stays edge-latched (semi-auto trigger). New InputMap actions: `ads` (RMB), `reload` (R), `weapon_slot_1` (1), `weapon_slot_2` (2); `repulse` rebound to physical E. All MatchConfig weapon keys from the baselines block above.

- [ ] **Step 1: Append failing tests** to `tests/player/test_player_input.gd`:

```gdscript
func test_gathers_weapon_inputs() -> void:
	Input.action_press("fire_primary")
	Input.action_press("ads")
	Input.action_press("weapon_slot_2")
	await await_millis(100)

	assert_bool(_input.fire_held).is_true()
	assert_bool(_input.ads).is_true()
	assert_int(_input.slot_select).is_equal(2)

	Input.action_release("fire_primary")
	Input.action_release("ads")
	Input.action_release("weapon_slot_2")
	await await_millis(100)
	assert_int(_input.slot_select).is_equal(0)


func test_reload_is_edge_latched() -> void:
	Input.action_press("reload")
	Input.action_release("reload")
	await await_millis(100)
	assert_bool(_input._pending_reload).is_false()
```

- [ ] **Step 2: Run** `... -a ./tests/player/test_player_input.gd --ignoreHeadlessMode` → FAIL (no such members).

- [ ] **Step 3: Implement.** `project.godot` `[input]`: add actions (`ads`: mouse button_index 2; `reload`: physical_keycode 82; `weapon_slot_1`: 49; `weapon_slot_2`: 50) and change `repulse`'s event to `InputEventKey` physical_keycode 69 (E). In `player_input.gd` add:

```gdscript
# --- Networked per-tick input (additions) ---
var fire_held: bool = false
var ads: bool = false
var reload: bool = false
var slot_select: int = 0

var _pending_reload: bool = false
var _pending_slot: int = 0
```

In `_process` latches: `_pending_reload = _pending_reload or Input.is_action_just_pressed("reload")`; and:

```gdscript
	if Input.is_action_just_pressed("weapon_slot_1"):
		_pending_slot = 1
	elif Input.is_action_just_pressed("weapon_slot_2"):
		_pending_slot = 2
```

In `_gather`: `fire_held = Input.is_action_pressed("fire_primary")`, `ads = Input.is_action_pressed("ads")`, `reload = _pending_reload`, `slot_select = _pending_slot`, then reset both pendings. Add all weapon/zone/weight keys from the baselines block to `MatchConfig.DEFAULTS`.

- [ ] **Step 4: Run** the full suite → all green (input suite grows by 2).
- [ ] **Step 5: Commit** `feat: weapon input actions and MatchConfig weapon baselines` (with co-author line).

---

### Task 2: Hit zones + zone damage routing

**Files:**
- Modify: `scenes/player/fps_controller.tscn`, `scripts/player/fps_controller.gd`
- Test: `tests/player/test_fps_controller.gd` (append)

**Interfaces:**
- Produces: Area3D children `HitZones/Head`, `HitZones/Body`, `HitZones/Limbs` on collision layer 2 (mask 0), each with meta `zone` = `"head"|"body"|"limbs"` and meta `player` = the controller. Controller method `take_zone_damage(base_damage: float, weapon_key: String, zone: String, attacker: FPSController, tick: int) -> void` applying: head → `weapon.<key>.head_mult` (Dwarf: resolves as body, ×1.0), limbs → `zones.limb_mult`, body ×1.0; then calls existing `take_damage`.

- [ ] **Step 1: Append failing tests:**

```gdscript
func test_zone_damage_multipliers() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()

	victim.take_zone_damage(10.0, "pistol", "head", null, NetworkTime.tick)
	assert_float(victim.health).is_equal(80.0)   # 10 x 2.0
	victim.take_zone_damage(10.0, "pistol", "limbs", null, NetworkTime.tick)
	assert_float(victim.health).is_equal(72.5)   # 10 x 0.75


func test_dwarf_headshot_immunity() -> void:
	var runner := _spawn_controller()
	var victim: FPSController = runner.scene()
	victim.archetype = &"dwarf"
	victim._apply_archetype_config()

	victim.take_zone_damage(10.0, "pistol", "head", null, NetworkTime.tick)
	assert_float(victim.health).is_equal(85.0)   # 95 - 10, no multiplier


func test_hit_zone_areas_exist_with_meta() -> void:
	var runner := _spawn_controller()
	var controller: FPSController = runner.scene()
	for zone in ["Head", "Body", "Limbs"]:
		var area: Area3D = controller.get_node("HitZones/%s" % zone)
		assert_object(area).is_not_null()
		assert_str(str(area.get_meta("zone"))).is_equal(zone.to_lower())
		assert_int(area.collision_layer).is_equal(2)
```

- [ ] **Step 2: Run** controller suite → FAIL (no `take_zone_damage`).
- [ ] **Step 3: Implement.** In the tscn add under the root: `HitZones` (Node3D) with three Area3D children — Head: SphereShape3D r 0.25 at y 1.6; Body: CapsuleShape3D r 0.35 h 0.7 at y 1.1; Limbs: BoxShape3D (0.6, 0.85, 0.5) at y 0.42 — each `collision_layer = 2`, `collision_mask = 0`, `monitoring = false`. Set metas in `_ready()`:

```gdscript
	for zone_area: Area3D in $HitZones.get_children():
		zone_area.set_meta("zone", zone_area.name.to_lower())
		zone_area.set_meta("player", self)
```

Add the routing method:

```gdscript
func take_zone_damage(base_damage: float, weapon_key: String, zone: String,
		attacker: FPSController, tick: int) -> void:
	var mult := 1.0
	match zone:
		"head":
			# Dwarf headshot immunity: resolves as body damage.
			mult = 1.0 if archetype == &"dwarf" \
				else MatchConfig.get_value("weapon.%s.head_mult" % weapon_key)
		"limbs":
			mult = MatchConfig.get_value("zones.limb_mult")
	take_damage(base_damage * mult, attacker, tick)
```

- [ ] **Step 4: Run** full suite → green. **Step 5: Commit** `feat: head/body/limb hit zones with Dwarf headshot immunity`.

---

### Task 3: WeaponRig — slots, ownership, switching, movement weight

**Files:**
- Create: `scripts/weapons/weapon_rig.gd`, `scripts/weapons/weapon_base.gd` (skeleton this task, fire pipeline next task)
- Modify: `scenes/player/fps_controller.tscn`, `scripts/player/fps_controller.gd`
- Test: `tests/weapons/test_weapon_rig.gd`

**Interfaces:**
- Produces: `class_name WeaponBase extends Node3D` with `@export var weapon_key: String`, `@export var weight_class: int` (0/1/2), rollback state `mag: float`, `reserve: float`, `last_fire_tick: int`, `reload_until_tick: int`, method `initialize_ammo()` (fills from config), `is_reloading(tick) -> bool`. `class_name WeaponRig extends Node3D` with rollback state `slot1: String`, `slot2: String` (weapon keys, `""` = empty), `active_slot: int` (1 or 2); methods `grant(key: String, slot: int)`, `active_weapon() -> WeaponBase`, `weapon_by_key(key) -> WeaponBase`, `process_tick(delta, tick, is_fresh)` (handles `slot_select` switching, **and — if the controller plan has executed — `input.swap_weapon`: toggle to the other slot when it holds a weapon**), `carry_weight_mult() -> float`. Controller: `speed` in `_rollback_tick` multiplied by `weapon_rig.carry_weight_mult()`; spawn grants pistol (slot 2) + rifle (slot 1) via `@export var default_slot1 := "rifle"`, `@export var default_slot2 := "pistol"`.
- Scene: `WeaponRig` (script) under `Camera3D/WeaponSocket`, with children `Pistol`, `Smg`, `Shotgun`, `Rifle`, `Sniper` (each WeaponBase-derived script, added in Tasks 4–8; this task adds the nodes with `weapon_base.gd` + `weapon_key` set). RollbackSynchronizer gains state entries: `Camera3D/WeaponSocket/WeaponRig:slot1`, `:slot2`, `:active_slot`, and per weapon `.../WeaponRig/Pistol:mag`, `:reserve`, `:last_fire_tick`, `:reload_until_tick` (×5 weapons). Input properties gain `Input:fire_held`, `Input:ads`, `Input:reload`, `Input:slot_select`.

- [ ] **Step 1: Write failing tests** (`tests/weapons/test_weapon_rig.gd`):

```gdscript
class_name TestWeaponRig
extends GdUnitTestSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()


func test_spawns_with_default_loadout() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	var rig: WeaponRig = controller.weapon_rig

	assert_str(rig.slot1).is_equal("rifle")
	assert_str(rig.slot2).is_equal("pistol")
	assert_int(rig.active_slot).is_equal(1)
	assert_float(rig.weapon_by_key("pistol").mag).is_equal(12.0)
	assert_float(rig.weapon_by_key("rifle").reserve).is_equal(72.0)


func test_slot_switch_via_input() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()

	runner.simulate_action_press("weapon_slot_2")
	await runner.simulate_frames(5)

	assert_int(controller.weapon_rig.active_slot).is_equal(2)
	assert_str(controller.weapon_rig.active_weapon().weapon_key).is_equal("pistol")


func test_carry_weight_slows_elf() -> void:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	controller.archetype = &"elf"
	controller._apply_archetype_config()
	controller.weapon_rig.grant("sniper", 1)  # heavy

	assert_float(controller.weapon_rig.carry_weight_mult()).is_equal(0.65)
```

- [ ] **Step 2: Run** → FAIL (no `weapon_rig`).
- [ ] **Step 3: Implement `weapon_base.gd`:**

```gdscript
# Base for all weapons. Fire pipeline lands in the next task; this task is
# identity + ammo + reload bookkeeping. All numeric config via MatchConfig
# under "weapon.<weapon_key>.*". Mutable vars are rollback state.
class_name WeaponBase
extends Node3D

@export var weapon_key: String = ""
@export var weight_class: int = 0  # 0 light, 1 medium, 2 heavy

# --- Rollback state ---
var mag: float = 0.0
var reserve: float = 0.0
var last_fire_tick: int = -(1 << 30)
var reload_until_tick: int = -(1 << 30)


func config(suffix: String) -> float:
	return MatchConfig.get_value("weapon.%s.%s" % [weapon_key, suffix])


func initialize_ammo() -> void:
	mag = config("mag")
	reserve = config("reserve")


func is_reloading(tick: int) -> bool:
	return tick < reload_until_tick


func start_reload(tick: int) -> void:
	if mag >= config("mag") or reserve <= 0.0 or is_reloading(tick):
		return
	reload_until_tick = tick + int(roundf(config("reload_s") * NetworkTime.tickrate))


func finish_reload_if_due(tick: int) -> void:
	# Called each tick; completes a pending reload exactly once.
	if reload_until_tick != -(1 << 30) and tick >= reload_until_tick:
		var need := config("mag") - mag
		var moved := minf(need, reserve)
		mag += moved
		reserve -= moved
		reload_until_tick = -(1 << 30)
```

**Implement `weapon_rig.gd`:**

```gdscript
# Owns the two weapon slots, switching, and carry weight.
# All children are WeaponBase nodes, present statically in the scene;
# "ownership" = a slot referencing their weapon_key.
class_name WeaponRig
extends Node3D

# --- Rollback state ---
var slot1: String = ""
var slot2: String = ""
var active_slot: int = 1

var _controller: FPSController


func setup(controller: FPSController) -> void:
	_controller = controller


func grant(key: String, slot: int) -> void:
	var weapon := weapon_by_key(key)
	assert(weapon != null, "unknown weapon key %s" % key)
	weapon.initialize_ammo()
	if slot == 1: slot1 = key
	else: slot2 = key


func weapon_by_key(key: String) -> WeaponBase:
	for child in get_children():
		if child is WeaponBase and child.weapon_key == key:
			return child
	return null


func active_weapon() -> WeaponBase:
	return weapon_by_key(slot1 if active_slot == 1 else slot2)


func carry_weight_mult() -> float:
	var mult := 1.0
	for key in [slot1, slot2]:
		if key == "":
			continue
		var weapon := weapon_by_key(key)
		match weapon.weight_class:
			1: mult = minf(mult, MatchConfig.get_value("weight.medium.%s" % _controller.archetype))
			2: mult = minf(mult, MatchConfig.get_value("weight.heavy.%s" % _controller.archetype))
	return mult


func process_tick(_delta: float, tick: int, _is_fresh: bool) -> void:
	var sel: int = _controller.input.slot_select
	if sel in [1, 2] and sel != active_slot:
		var target := slot1 if sel == 1 else slot2
		if target != "":
			active_slot = sel
	var weapon := active_weapon()
	if weapon != null:
		weapon.finish_reload_if_due(tick)
		if _controller.input.reload:
			weapon.start_reload(tick)
```

**Controller changes:** add `@export var default_slot1: String = "rifle"`, `@export var default_slot2: String = "pistol"`, `@onready var weapon_rig: WeaponRig = $Camera3D/WeaponSocket/WeaponRig`; in `_ready()` (before `process_settings`): `weapon_rig.setup(self)`, `weapon_rig.grant(default_slot2, 2)`, `if default_slot1 != "": weapon_rig.grant(default_slot1, 1)`; in `_rollback_tick` after passives: `weapon_rig.process_tick(delta, tick, is_fresh)` and change the speed line to `var speed := (sprint_speed if input.sprint else walk_speed) * weapon_rig.carry_weight_mult()`.
**Scene:** add the WeaponRig node + five children with scripts (per-weapon scripts arrive Tasks 4–8 — for now all use `weapon_base.gd` with `weapon_key`/`weight_class` set: pistol 0, smg 0, shotgun 1, rifle 1, sniper 2); register all state/input properties listed in Interfaces on the RollbackSynchronizer.

- [ ] **Step 4: Run** full suite → green. **Step 5: Commit** `feat: weapon rig with slots, reload bookkeeping, and movement weight`.

---

### Task 4: Fire pipeline (RewindableAction) + Pistol

**Files:**
- Modify: `scripts/weapons/weapon_base.gd` (fire pipeline), `scenes/player/fps_controller.tscn` (RewindableAction child per weapon, pistol script)
- Create: `scripts/weapons/pistol.gd`
- Test: `tests/weapons/test_weapon_fire.gd`

**Interfaces:**
- Produces on `WeaponBase`: `_rollback_tick(delta, tick, is_fresh)` implementing the upstream netfox pattern; overridables `_wants_fire() -> bool` (default: edge `input.fire`), `_shot_directions(tick) -> Array[Vector3]` (default: single aim ray), `_on_fire_tick(tick)`. Firing: checks active weapon == self, not reloading, `mag > 0`, tick cooldown via `fire_interval_s`; on fire: `mag -= 1`, `last_fire_tick = tick`, raycast(s) against world (layer 1) + hit zones (layer 2, `collide_with_areas`), zone resolved from Area3D meta, damage = `config("damage") * falloff(distance)`, applied via victim's `take_zone_damage(...)` + `NetworkRollback.mutate(victim)`. Auto-reload starts when mag hits 0. `pistol.gd` = `extends WeaponBase` with no overrides (semi-auto default).
- Each weapon node gets a `RewindableAction` child named `FireAction` (netfox class, plain Node with script `res://addons/netfox/rollback/rewindable-action.gd`... **verify**: `rewindable-action.gd` lives at `res://addons/netfox/rewindable-action.gd` — use that path).

- [ ] **Step 1: Failing tests** (`tests/weapons/test_weapon_fire.gd`):

```gdscript
class_name TestWeaponFire
extends GdUnitTestSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()


func _spawn_pair() -> Array:
	var runner := scene_runner(CONTROLLER_SCENE)
	var shooter: FPSController = runner.scene()
	shooter.default_slot1 = ""
	var victim: FPSController = (load(CONTROLLER_SCENE) as PackedScene).instantiate()
	runner.scene().get_parent().add_child(victim)
	victim.global_position = shooter.global_position + Vector3(0, 0, -5)
	return [runner, shooter, victim]


func test_pistol_shot_consumes_ammo_and_damages() -> void:
	var pair := _spawn_pair()
	var runner: GdUnitSceneRunner = pair[0]
	var shooter: FPSController = pair[1]
	var victim: FPSController = pair[2]
	runner.simulate_action_press("weapon_slot_2")
	await runner.simulate_frames(5)

	runner.simulate_action_press("fire_primary")
	await runner.simulate_frames(5)
	runner.simulate_action_release("fire_primary")

	var pistol := shooter.weapon_rig.weapon_by_key("pistol")
	assert_float(pistol.mag).is_equal(11.0)
	assert_float(victim.health).is_less(victim._config("max_health"))


func test_no_fire_while_reloading_or_empty() -> void:
	var pair := _spawn_pair()
	var runner: GdUnitSceneRunner = pair[0]
	var shooter: FPSController = pair[1]
	runner.simulate_action_press("weapon_slot_2")
	await runner.simulate_frames(5)
	var pistol := shooter.weapon_rig.weapon_by_key("pistol")
	pistol.mag = 0.0

	runner.simulate_action_press("fire_primary")
	await runner.simulate_frames(5)
	runner.simulate_action_release("fire_primary")

	assert_float(pistol.mag).is_equal(0.0)  # nothing fired...
	assert_bool(pistol.is_reloading(NetworkTime.tick)).is_true()  # ...auto-reload began


func test_semi_auto_requires_new_trigger_pull() -> void:
	var pair := _spawn_pair()
	var runner: GdUnitSceneRunner = pair[0]
	var shooter: FPSController = pair[1]
	runner.simulate_action_press("weapon_slot_2")
	await runner.simulate_frames(5)

	runner.simulate_action_press("fire_primary")
	await runner.simulate_frames(60)  # held a full second
	runner.simulate_action_release("fire_primary")

	assert_float(shooter.weapon_rig.weapon_by_key("pistol").mag).is_equal(11.0)
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** the pipeline in `weapon_base.gd` (add below the existing code):

```gdscript
@onready var fire_action: RewindableAction = $FireAction
@onready var _rig: WeaponRig = get_parent()


func _ready() -> void:
	fire_action.mutate(self)
	fire_action.mutate(_rig._controller)


func _controller() -> FPSController:
	return _rig._controller


func _wants_fire() -> bool:
	return _controller().input.fire  # edge: semi-auto default


func _can_fire(tick: int) -> bool:
	return _rig.active_weapon() == self \
		and not is_reloading(tick) \
		and mag > 0.0 \
		and NetworkTime.seconds_between(last_fire_tick, tick) >= config("fire_interval_s")


func _rollback_tick(_delta: float, tick: int, _is_fresh: bool) -> void:
	if _controller().rollback_synchronizer.is_predicting():
		return
	if mag <= 0.0 and _rig.active_weapon() == self and not is_reloading(tick):
		start_reload(tick)

	fire_action.set_active(_wants_fire() and _can_fire(tick))
	match fire_action.get_status():
		RewindableAction.CONFIRMING, RewindableAction.ACTIVE:
			_fire(tick)
		RewindableAction.CANCELLING:
			fire_action.erase_context()


func _fire(tick: int) -> void:
	last_fire_tick = tick
	mag -= 1.0
	for dir in _shot_directions(tick):
		_hitscan(dir, tick)
	_on_fire_tick(tick)


func _aim_basis() -> Basis:
	var input := _controller().input
	return Basis(Vector3.UP, input.aim_yaw) * Basis(Vector3.RIGHT, input.aim_pitch)


func _shot_directions(_tick: int) -> Array[Vector3]:
	return [_aim_basis() * Vector3.FORWARD]


func _on_fire_tick(_tick: int) -> void:
	pass


func _falloff(distance: float) -> float:
	var start := config("falloff_start_m")
	var end := config("falloff_end_m")
	if distance <= start: return 1.0
	if distance >= end: return config("falloff_min_mult")
	return lerpf(1.0, config("falloff_min_mult"), (distance - start) / (end - start))


func _hitscan(direction: Vector3, tick: int) -> void:
	var me := _controller()
	var from := me.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * 200.0)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0b11  # world (1) + hit zones (2)
	query.exclude = [me.get_rid()]
	var result := me.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Object = result.collider
	if collider is Area3D and collider.has_meta("player"):
		var victim: FPSController = collider.get_meta("player")
		if victim == me:
			return
		var dmg := config("damage") * _falloff(from.distance_to(result.position))
		victim.take_zone_damage(dmg, weapon_key, str(collider.get_meta("zone")), me, tick)
		NetworkRollback.mutate(victim)
```

Create `scripts/weapons/pistol.gd`: `class_name PistolWeapon` + `extends WeaponBase` (2 lines — semi-auto defaults). Scene: set the Pistol node's script to it; add a `FireAction` child (script `res://addons/netfox/rewindable-action.gd`) to **every** weapon node. Note: the shooter's own hit-zone Areas must be excluded — `query.exclude` only takes RIDs; add all five of `me.get_node("HitZones").get_children()` RIDs to `exclude`.

- [ ] **Step 4: Run** full suite → green. **Step 5: Commit** `feat: RewindableAction fire pipeline with lag-compensated hitscan + Pistol`.

---

### Task 5: SMG (full-auto + bloom)

**Files:** Create `scripts/weapons/smg.gd`; modify scene (Smg node script); test `tests/weapons/test_weapon_variants.gd` (new file).

**Interfaces:** `SmgWeapon extends WeaponBase`; rollback state `bloom_deg: float`; `_wants_fire()` returns `input.fire_held`; `_shot_directions` deflects the aim ray by a seeded random angle within `bloom_deg`; `_on_fire_tick` grows bloom (`bloom_per_shot_deg` up to `bloom_max_deg`); bloom decays by `bloom_decay_deg_s * delta` each tick (override `_rollback_tick` is NOT needed — decay goes in a new overridable `_weapon_tick(delta, tick)` called by `WeaponBase._rollback_tick` before the fire logic; add that hook in this task).

- [ ] **Step 1: Failing tests:**

```gdscript
class_name TestWeaponVariants
extends GdUnitTestSuite

const CONTROLLER_SCENE := "res://scenes/player/fps_controller.tscn"


func before_test() -> void:
	NetworkTime.start()
	await await_millis(100)


func after_test() -> void:
	NetworkTime.stop()


func _spawn_with(key: String) -> Array:
	var runner := scene_runner(CONTROLLER_SCENE)
	var controller: FPSController = runner.scene()
	controller.weapon_rig.grant(key, 1)
	controller.weapon_rig.active_slot = 1
	return [runner, controller]


func test_smg_full_auto_and_bloom() -> void:
	var pair := _spawn_with("smg")
	var runner: GdUnitSceneRunner = pair[0]
	var controller: FPSController = pair[1]
	var smg := controller.weapon_rig.weapon_by_key("smg")

	runner.simulate_action_press("fire_primary")
	await runner.simulate_frames(40)  # ~0.66s at 60tps -> ~8 shots at 0.08s
	runner.simulate_action_release("fire_primary")

	assert_float(smg.mag).is_less(26.0)      # multiple shots from one hold
	assert_float(smg.bloom_deg).is_greater(0.0)
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** In `weapon_base.gd` add the hook — inside `_rollback_tick`, first line after the predicting guard: `_weapon_tick(_delta, tick)`, plus `func _weapon_tick(_delta: float, _tick: int) -> void: pass`. Create `smg.gd`:

```gdscript
class_name SmgWeapon
extends WeaponBase

# --- Rollback state ---
var bloom_deg: float = 0.0


func _wants_fire() -> bool:
	return _controller().input.fire_held


func _weapon_tick(delta: float, _tick: int) -> void:
	bloom_deg = maxf(bloom_deg - config("bloom_decay_deg_s") * delta, 0.0)


func _on_fire_tick(_tick: int) -> void:
	bloom_deg = minf(bloom_deg + config("bloom_per_shot_deg"), config("bloom_max_deg"))


func _shot_directions(tick: int) -> Array[Vector3]:
	var seed_val := hash([tick, _controller().multiplayer.get_unique_id(), weapon_key])
	var rng := rand_from_seed(seed_val)
	var angle := deg_to_rad(bloom_deg) * (float(rng[0] % 1000) / 1000.0)
	var roll := TAU * (float(rand_from_seed(rng[1])[0] % 1000) / 1000.0)
	var dir := _aim_basis() * Vector3.FORWARD
	return [dir.rotated(_aim_basis() * Vector3.UP, angle * cos(roll))
		.rotated(_aim_basis() * Vector3.RIGHT, angle * sin(roll))]
```

Register `Camera3D/WeaponSocket/WeaponRig/Smg:bloom_deg` as a state property in the scene.

- [ ] **Step 4: Run** full suite → green. **Step 5: Commit** `feat: SMG full-auto with rollback-safe bloom`.

---

### Task 6: Shotgun (seeded pellet cone)

**Files:** Create `scripts/weapons/shotgun.gd`; modify scene; append to `tests/weapons/test_weapon_variants.gd`.

**Interfaces:** `ShotgunWeapon extends WeaponBase`; `_shot_directions` returns `pellets` rays, each deflected within `cone_deg` using the seeded pattern from Task 5 (seed includes pellet index). Damage-per-pellet is the base `damage` config — total damage emerges from pellets that connect (decided design).

- [ ] **Step 1: Failing test:** grant `"shotgun"`, place a victim 3 m ahead (as in Task 4's `_spawn_pair` pattern — victim spawned and positioned at `shooter.global_position + Vector3(0, 0, -3)`), fire once, assert `victim.health` dropped by more than one pellet's damage (`> 6.0` loss) and `shotgun.mag == 5.0`.

```gdscript
func test_shotgun_multi_pellet_damage() -> void:
	var pair := _spawn_with("shotgun")
	var runner: GdUnitSceneRunner = pair[0]
	var controller: FPSController = pair[1]
	var victim: FPSController = (load(CONTROLLER_SCENE) as PackedScene).instantiate()
	controller.get_parent().add_child(victim)
	victim.global_position = controller.global_position + Vector3(0, 0, -3)

	runner.simulate_action_press("fire_primary")
	await runner.simulate_frames(5)
	runner.simulate_action_release("fire_primary")

	var lost: float = victim._config("max_health") - victim.health
	assert_float(lost).is_greater(6.0)
	assert_float(controller.weapon_rig.weapon_by_key("shotgun").mag).is_equal(5.0)
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** `shotgun.gd`:

```gdscript
class_name ShotgunWeapon
extends WeaponBase


func _shot_directions(tick: int) -> Array[Vector3]:
	var dirs: Array[Vector3] = []
	var forward := _aim_basis() * Vector3.FORWARD
	var up := _aim_basis() * Vector3.UP
	var right := _aim_basis() * Vector3.RIGHT
	var cone := deg_to_rad(config("cone_deg"))
	for i in range(int(config("pellets"))):
		var s := rand_from_seed(hash([tick, _controller().multiplayer.get_unique_id(), weapon_key, i]))
		var angle := cone * (float(s[0] % 1000) / 1000.0)
		var roll := TAU * (float(rand_from_seed(s[1])[0] % 1000) / 1000.0)
		dirs.append(forward.rotated(up, angle * cos(roll)).rotated(right, angle * sin(roll)))
	return dirs
```

- [ ] **Step 4: Run** → green. **Step 5: Commit** `feat: shotgun with deterministic pellet cone`.

---

### Task 7: Rifle (3-round burst + ADS)

**Files:** Create `scripts/weapons/rifle.gd`; modify scene, `scripts/player/fps_controller.gd` (ADS FOV); append tests.

**Interfaces:** `RifleWeapon extends WeaponBase`; rollback state `burst_remaining: int`; trigger (edge `input.fire`) starts a burst if `_can_fire`; `_weapon_tick` continues the burst every `burst_intra_s` regardless of trigger; `supports_ads() -> bool` on WeaponBase (default false, rifle/sniper true) + `ads_zoom()` returning config. Controller `_process` (view-only): `camera.fov = 75.0 / zoom` when `input.ads` and active weapon supports ADS, else 75.0, lerped at 10/s.

- [ ] **Step 1: Failing tests:**

```gdscript
func test_rifle_fires_three_round_burst_per_trigger() -> void:
	var pair := _spawn_with("rifle")
	var runner: GdUnitSceneRunner = pair[0]
	var controller: FPSController = pair[1]
	var rifle := controller.weapon_rig.weapon_by_key("rifle")

	runner.simulate_action_press("fire_primary")
	await runner.simulate_frames(3)
	runner.simulate_action_release("fire_primary")
	await runner.simulate_frames(30)  # let the burst play out

	assert_float(rifle.mag).is_equal(21.0)  # exactly 3 rounds


func test_ads_zoom_applies_to_camera() -> void:
	var pair := _spawn_with("rifle")
	var runner: GdUnitSceneRunner = pair[0]
	var controller: FPSController = pair[1]

	runner.simulate_action_press("ads")
	await runner.simulate_frames(30)

	assert_float(controller.camera.fov).is_less(60.0)  # zooming toward 75/1.6
	runner.simulate_action_release("ads")
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** `rifle.gd`:

```gdscript
class_name RifleWeapon
extends WeaponBase

# --- Rollback state ---
var burst_remaining: int = 0
var next_burst_tick: int = -(1 << 30)


func supports_ads() -> bool:
	return true


func _wants_fire() -> bool:
	# Trigger only starts bursts; continuation is handled in _weapon_tick.
	return _controller().input.fire and burst_remaining == 0


func _on_fire_tick(tick: int) -> void:
	if burst_remaining == 0:
		burst_remaining = int(config("burst_count")) - 1
	else:
		burst_remaining -= 1
	next_burst_tick = tick + int(roundf(config("burst_intra_s") * NetworkTime.tickrate))


func _weapon_tick(_delta: float, tick: int) -> void:
	if burst_remaining > 0 and tick >= next_burst_tick and mag > 0.0:
		_fire(tick)
```

On `WeaponBase` add `func supports_ads() -> bool: return false` and `func ads_zoom() -> float: return config("ads_zoom")`. Controller `_process` addition (after camera pitch line):

```gdscript
	var active := weapon_rig.active_weapon() if weapon_rig != null else null
	var target_fov := 75.0
	if active != null and input.ads and active.supports_ads():
		target_fov = 75.0 / active.ads_zoom()
	camera.fov = lerpf(camera.fov, target_fov, minf(10.0 * _delta, 1.0))
```

Register `Rifle:burst_remaining` and `Rifle:next_burst_tick` state properties. Burst rounds bypass `fire_action` gating (they're consequences of a confirmed trigger; direct `_fire` in `_weapon_tick` is rollback-safe because all touched vars are state).

- [ ] **Step 4: Run** → green. **Step 5: Commit** `feat: rifle 3-round burst and scoped ADS`.

---

### Task 8: Sniper (single-shot, high zoom, heavy)

**Files:** Create `scripts/weapons/sniper.gd`; modify scene; append test.

**Interfaces:** `SniperWeapon extends WeaponBase` with `supports_ads() -> true` — semi-auto default pipeline covers the rest (interval 1.4 s acts as bolt time; no falloff per config).

- [ ] **Step 1: Failing test:** grant `"sniper"`, victim 5 m ahead, one shot → victim health drops exactly 55.0 (body); second trigger within 0.5 s does nothing (`mag == 4.0` still).

```gdscript
func test_sniper_single_shot_and_bolt_cooldown() -> void:
	var pair := _spawn_with("sniper")
	var runner: GdUnitSceneRunner = pair[0]
	var controller: FPSController = pair[1]
	var victim: FPSController = (load(CONTROLLER_SCENE) as PackedScene).instantiate()
	controller.get_parent().add_child(victim)
	victim.global_position = controller.global_position + Vector3(0, 0, -5)

	runner.simulate_action_press("fire_primary")
	await runner.simulate_frames(3)
	runner.simulate_action_release("fire_primary")
	runner.simulate_action_press("fire_primary")
	await runner.simulate_frames(10)   # within bolt time
	runner.simulate_action_release("fire_primary")

	assert_float(victim._config("max_health") - victim.health).is_equal(55.0)
	assert_float(controller.weapon_rig.weapon_by_key("sniper").mag).is_equal(4.0)
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** `sniper.gd` (`class_name SniperWeapon extends WeaponBase` + `func supports_ads() -> bool: return true`), set scene script.
- [ ] **Step 4: Run** → green. **Step 5: Commit** `feat: sniper with bolt cooldown and 4x ADS`.

---

### Task 9: Live verification + arena updates

**Files:** Modify `scenes/levels/test_arena.tscn` (DebugLabel text: E = Repulse, RMB = ADS, 1/2 slots, R reload), `scripts/ui/resonance_hud.gd` (append ammo line: `active.mag / active.reserve`, reload indicator).

- [ ] **Step 1:** Update DebugLabel text and HUD script (`text += "\n%s  %d / %d%s" % [weapon.weapon_key, int(weapon.mag), int(weapon.reserve), " (reloading)" if weapon.is_reloading(NetworkTime.tick) else ""]` for the active weapon).
- [ ] **Step 2: MCP live check:** run headless, connect to 9090, `eval` to read `/root/TestArena/FPSController` — assert rig slots are `rifle`/`pistol`; `key_press "1"`, fire via `Input.action_press("fire_primary")` eval, read rifle `mag` — expect 21.0 after one burst; `key_press "2"` then read `active_slot == 2`.
- [ ] **Step 3:** Full suite green. **Step 4: Commit** `feat: weapon HUD readout and arena controls update`.

---

### Task 10: Docs + spell check

- [ ] `CLAUDE.md`: weapons follow the `WeaponBase` pipeline (`RewindableAction`, `_wants_fire`/`_shot_directions`/`_weapon_tick`/`_on_fire_tick` overrides); new weapons = new script + scene node + MatchConfig keys + state property registration; seeded randomness only.
- [ ] `docs/PRD.md` Phase 0: mark weapon system bullet ✅ (hitscan framework + 5 weapons; melee + projectiles in follow-ups).
- [ ] `npx -y cspell --no-progress docs/ CLAUDE.md scripts/ | tail -3` → 0 issues (add flagged terms: likely `hitscan` present, add `bloom`? real word — add whatever surfaces).
- [ ] Full suite + commit `docs: weapon framework conventions`.

---

## Scope note: recoil view-kick patterns

The decided "hybrid per class" recoil model has two halves. This plan ships the **shot-dispersion half**: SMG bloom, shotgun seeded pellet cone, deterministic per-tick spread. The **view-kick half** (deterministic camera-kick patterns on Rifle/SMG, CS-style `PackedVector2Array` data scaled by `weapon.recoil_scale`) is deliberately a follow-up polish task once weapons are feelable in playtests — it is pure local view feedback (never simulation state), so it can land any time without netcode implications. The config key and data-format decision are reserved above so nothing needs redesign.

## Known risks & notes (for the executor)

- **`RewindableAction` is marked experimental upstream** — API verified against v1.35.3 vendored source (`set_active`, `get_status`, `has_confirmed`, `erase_context`, `mutate`). If behavior surprises, the reference implementation is `examples/rollback-fps/scripts/player-weapon.gd` in the netfox repo.
- **`is_predicting()` guard**: verify the exact method name on `RollbackSynchronizer` in the vendored source before Task 4 (upstream example calls `rollback_synchronizer.is_predicting()`).
- **Victim hit-zone areas and `monitoring`**: Areas with `monitoring = false` are still raycast-hittable via `collide_with_areas` — if rays pass through, set `monitorable = true` on the zones.
- **Burst + RewindableAction cancellation**: if a predicted trigger is cancelled but the burst continued, burst state vars roll back automatically (they're state properties). The `CANCELLING` branch only needs `erase_context`.
- **Two-controller tests** share the pattern established in the Resonance plan (victim instantiated into the runner's scene tree).
