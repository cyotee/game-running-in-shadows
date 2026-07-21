# Familiar — Design (G5 Wave 3, ability 2)

**Status:** APPROVED 2026-07-20 · **Branch:** `feat/familiar` ·
**Master plan item:** G5 Wave 3 (needs G7 ping ✅)

## 1. Purpose & scope

Familiar summons a **combat minion** (4 Resonance held) that follows the caster,
**hunts a ping-tagged enemy** (the payoff of the G7 ping system), or **guards a
placed point** — dealing melee damage to enemies. Minions fight each other and
are destroyed by Null charges and Dwarves.

**In scope (this pass — the full approved behavior):**
- One Familiar per caster, summoned/re-tasked by a `familiar` press-tick.
- Three modes: FOLLOW (default), HUNT (auto from `PingService.latest_enemy_tag`),
  GUARD (a placed point).
- Deterministic melee combat vs enemy players AND enemy Familiars.
- Counters: destroyed inside a Null field, destroyed by a nearby Dwarf, shootable.
- 4 Resonance held while it lives; dies with caster.
- MatchConfig tuning; unit tests; E2E no-regression check.

**Out of scope (deferred, documented):** ranged Familiars, more than one per
caster, obstacle pathfinding (arenas are open), "rear-warning" HUD.

## 2. Architecture — a mobile PlacedField (rollback entity)

The Familiar is a **rollback-simulated entity** in the same family as
`PlacedField`/grenade/corpse: reconstructed on every peer from flat spawn data
via `ProjectileSpawner`, then each peer simulates it deterministically through
its own `RollbackSynchronizer`. There is **no navigation/pathfinding in the
project**, so movement is simple deterministic steering (`move_toward` in the
XZ plane) — fine for open arenas.

**Cross-node damage is applied in-tick with `NetworkRollback.mutate`** — the
same path weapons use (a hitscan calls `victim.take_damage(...)` from the
shooter's rollback tick and it sticks). This is NOT an out-of-band write (those
are the ones made outside any rollback tick, which the state restore discards).

## 3. Entity: `Familiar` (`scripts/abilities/familiar.gd`, extends `Node3D`)

**Rollback state** (registered in `familiar.tscn`
`RollbackSynchronizer.state_properties`): `:transform`, `:hp`, `:mode`,
`:guard_pos`, `:attack_cooldown_ticks`.

**Plain fields:** `caster_peer: int`, `_freed: bool`.

**Consts:** `FOLLOW := 0`, `HUNT := 1`, `GUARD := 2`.

**Lifecycle** (mirrors `PlacedField`):
- `_ready`: `add_to_group("familiars")`, `rollback_synchronizer.process_settings()`.
- `setup(pos, caster, mode, guard_pos)`: init position/state.
- `_process`: if `_is_dead()` and not `_freed` → `queue_free()` (never frees in
  the rollback tick).
- `_is_dead() -> bool`: `hp <= 0.0 or _caster_gone()`.

**`_rollback_tick(delta, tick, is_fresh)`:**
1. If `_is_dead()`: return.
2. **Counters:** if `_in_null_field()` (scan `null_charge` fields, point-in-radius)
   or `_dwarf_in_range()` → `hp = 0.0`; return.
3. Resolve the effective target and desired position for this tick:
   - Find caster (`_find_player(caster_peer)`). If gone → dead (handled by
     `_caster_gone`).
   - HUNT: `tag := PingService.latest_enemy_tag(caster_peer)`; if `tag != 0` and
     that player is alive → target = that player.
   - Else GUARD → hold `guard_pos`, target = nearest enemy within
     `aggro_radius_m` of `guard_pos`.
   - Else FOLLOW → desired = caster position + `follow_offset_m` behind; target =
     nearest enemy within `aggro_radius_m` of self.
4. **Move:** steer `global_position` toward (target position if a target and we
   are outside melee range, else the mode's home position) via `move_toward` at
   `move_speed * delta` (XZ only; keep Y grounded).
5. **Attack:** `attack_cooldown_ticks = max(0, attack_cooldown_ticks - 1)`. If a
   target exists within `melee_range_m` and `attack_cooldown_ticks == 0`:
   - Player target: `target.take_damage(melee_damage, _find_player(caster_peer), tick)`.
   - Enemy-Familiar target: `target.take_familiar_damage(melee_damage)`.
   - `attack_cooldown_ticks = round(attack_interval_s * tickrate)`.

**Target selection** `_nearest_enemy(from: Vector3, radius) -> Node`:
scan `players` (alive, not the caster, team-scoped when a `MatchState` exists)
and `familiars` (not owned by the caster, team-scoped); return the nearest within
`radius`. HUNT bypasses this with the explicit ping target.

**Damage in:** `take_familiar_damage(amount)` → `hp = max(hp - amount, 0.0)`,
`NetworkRollback.mutate(self)`. `destroy()` → `hp = 0.0` + mutate (external
kill). Weapon rays hit a StaticBody/collision child (collision layer as
`PlacedField` uses — layer 5, mask that weapon rays 1|2 can see; confirm the
field collision setup and mirror it so guns can shoot the Familiar).

**`_caster_gone()`:** true if no live player has authority `caster_peer`
(mirrors `PlacedField`).

## 4. Caster side (`FPSController`)

**Input:** new edge `familiar` press-tick (plumbed through `PlayerInput` +
`input_properties`, exactly like `reclaim`). Key + joypad in `project.godot`.

**Cast dispatch** in `_rollback_tick` (with the other casts):
`if not is_wraithed and input.familiar_press_tick == tick: _cast_familiar(tick, is_fresh)`.

**`_cast_familiar(tick, is_fresh)`:**
- Determine base mode + guard point from aim: raycast (reuse the
  `enemy_under_reticle` query shape) to a ground point within
  `familiar.guard_range_m`; a valid hit → GUARD there, else FOLLOW.
- If the caster has **no** live Familiar:
  - Guard: need `resonance.current >= familiar_cost`; else deny (`cast_denied`).
  - `resonance.reserve(cost)`, `familiar_reserved = true`, `familiar_cast_tick = tick`.
  - `spawner.spawn_familiar(spawn_pos, my_peer, base_mode, guard_pos)`.
- If a live Familiar exists: **re-mode** it — but changing its mode is a cross-node write
  to the Familiar's rollback state, so route it through a plain-pending setter on
  the Familiar (`queue_set_mode(mode, guard_pos)`) applied in the Familiar's own
  tick (the Reclaim plain-pending pattern). No new reservation.

**Reservation reconcile** (extend `_reconcile_field_reservations`, mirroring
Reclaim/Lifebloom): `if familiar_reserved and tick > familiar_cast_tick + 30 and
not _has_owned_familiar(): release(cost); familiar_reserved = false`.
`_has_owned_familiar()` scans the `familiars` group for one with
`caster_peer == my_peer` that is not dead.

**New FPSController rollback state:** `familiar_reserved: bool`,
`familiar_cast_tick: int` (registered in `fps_controller.tscn`). Clear both in
`_apply_pending_respawn` (like the Reclaim state).

## 5. Spawner

Add to `scripts/weapons/projectile_spawner.gd`:
`spawn_familiar(pos, caster_peer, mode, guard_pos)` → `spawn(["familiar", pos,
caster_peer, mode, guard_pos.x, guard_pos.y, guard_pos.z])` (flat primitives),
and a `"familiar"` case in `_spawn` reconstructing via `Familiar.setup`.

## 6. Tuning (MatchConfig `DEFAULTS`)

| key | baseline | meaning |
|-----|----------|---------|
| `resonance.familiar_cost` | 4.0 | held while the Familiar lives |
| `familiar.hp` | 100.0 | minion health |
| `familiar.move_speed` | 7.0 | steering speed (m/s) |
| `familiar.aggro_radius_m` | 12.0 | enemy detection radius |
| `familiar.melee_range_m` | 2.0 | attack range |
| `familiar.melee_damage` | 12.0 | per-hit damage |
| `familiar.attack_interval_s` | 0.8 | seconds between hits |
| `familiar.dwarf_destroy_radius_m` | 4.0 | Dwarf proximity kill radius |
| `familiar.follow_offset_m` | 2.5 | follow distance behind caster |
| `familiar.guard_range_m` | 30.0 | max guard-placement raycast range |

## 7. Edge / determinism

- **Null / Dwarf** checked first each tick → immediate destruction (clean counters).
- **HUNT fallback:** ping target dead/gone/expired → falls back to base mode.
- **No caster team:** team-less → any non-caster player/enemy-Familiar is an enemy.
- **Determinism:** all movement/combat is `move_toward` + tick-count cooldowns —
  no `randf()` (none needed). No wall-clock.
- **Cross-node writes** (damage out, re-mode in) happen in a rollback tick with
  `mutate`, or via plain-pending applied in the target's own tick — never a bare
  out-of-band write.
- **Self-safety:** the Familiar never targets its own caster or same-team players.

## 8. Testing (static-prop harness — see `test_reclaim.gd`)

Only the local-authority `runner.scene()` is simulated offline; other controllers
are static props configured before the first tick.

- **Summon:** caster casts → a Familiar spawns in the `familiars` group and the
  caster reserves `familiar_cost`.
- **Follow:** with the caster as the runner scene and the Familiar spawned, after
  ticks the Familiar's distance to the caster ≤ ~`follow_offset + melee_range`.
- **Hunt:** set a `PingService` enemy tag (via `_apply_ping`) to a static enemy
  prop; the Familiar moves toward that enemy's position.
- **Guard:** cast aimed at a point → mode GUARD, Familiar holds near `guard_pos`.
- **Melee damages a player (in-tick):** the ENEMY is the runner scene (simulated);
  spawn a Familiar (caster = static prop) adjacent; assert the enemy's health
  drops (via `take_damage` + mutate in the Familiar's tick).
- **Minion-vs-minion:** two Familiars (distinct casters); one adjacent enemy
  Familiar loses hp.
- **Null counter:** a Null field over the Familiar → hp 0 / freed.
- **Dwarf counter:** a Dwarf prop within `dwarf_destroy_radius` → destroyed.
- **Dies with caster + reservation release:** caster (runner scene) with a
  Familiar reserves; kill caster → Familiar dies, reservation releases after grace.
- **Shootable:** `take_familiar_damage(hp)` → dies.

**Gates:** headless suite `0 errors | 0 failures` exit 0 per task; E2E
`net_smoke` PASS (no regression); cspell; `--no-ff` merge; master-plan Familiar ✅.

## 9. Build order (for the plan)

1. Input plumbing (`familiar` press-tick) + MatchConfig keys + FPSController
   reservation state registration.
2. `Familiar` entity skeleton + scene + spawner `"familiar"` kind + `setup`/
   lifecycle/`_is_dead`/`_caster_gone` (spawn + dies-with-caster test).
3. `_cast_familiar` summon + reservation + reconcile (summon/reserve/release tests).
4. Movement: FOLLOW + GUARD steering (+ re-mode via plain-pending) (follow/guard tests).
5. HUNT via `PingService.latest_enemy_tag` (hunt test).
6. Melee combat vs players + enemy Familiars, in-tick + mutate (damage + minion-vs-minion tests).
7. Counters: Null field + Dwarf proximity + shootable (counter tests).
8. E2E no-regression + docs (tuning, MECHANICS §11 key, master-plan ✅).
