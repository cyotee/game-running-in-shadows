# Ability Roster Wave 1 — Slip, Wraith, Grenades (Gap G5.1) Implementation Plan

> **For agentic workers:** execute with superpowers:executing-plans. Decided
> design from MECHANICS_REFERENCE §4.A (framework: Resonance-only pacing,
> instant/placement casts, effects die with caster, full friendly fire) and
> the per-ability specs in §4.A / ABILITY_TUNING_SHEET §4. Do not re-litigate.

**Goal:** The three instant/self abilities of Wave 1, all netfox-rollback-
native and driven by the established press-tick input pattern:
- **Slip** — instant blink ~8 m along current velocity (aim direction when
  stationary); passes through solids when the destination is clear; a failed
  cast (no clear destination) refunds the cost with a fizzle (`cast_denied`).
- **Wraith** — toggle on (cost 1) + continuous drain (~1.5/s); forced out when
  the pool empties. Walk speed only; weapons/abilities/glide locked while
  phased; immune to bullets and fall damage; rematerialization is instant.
- **Grenades** — free 2/round, cookable fuse (hold up to ~2.5 s, 3 s total),
  bounces physically, Repulse-able in flight; AoE damage on detonation.

**Architecture:** Slip and Wraith are controller rollback state + methods,
exactly like Repulse/Glide. Grenades spawn a rollback-simulated projectile
(`scripts/weapons/grenade.gd`) whose position/velocity/fuse are rollback
state ticked in its own `_rollback_tick`; both scenes gain a `Projectiles`
node + `MultiplayerSpawner` and the controller spawns through it. All numbers
via MatchConfig. Wraith gating (`is_wraithed`) must suppress weapon fire, the
other casts, glide, and incoming bullet/fall damage.

## MatchConfig additions (Task 1)

```gdscript
	"resonance.slip_cost": 3.0,
	"ability.slip_distance_m": 8.0,
	"resonance.wraith_cost": 1.0,
	"resonance.wraith_drain_per_s": 1.5,
	"ability.grenade_stock": 2.0,
	"ability.grenade_fuse_s": 3.0,
	"ability.grenade_cook_max_s": 2.5,
	"ability.grenade_damage": 70.0,
	"ability.grenade_radius_m": 5.0,
	"ability.grenade_inner_radius_m": 1.5,
	"ability.grenade_throw_speed": 18.0,
	"price.slip": 2000.0,
	"price.wraith": 1700.0,
	"price.grenades": 0.0,
```

## Input actions (Task 1)

- `slip` — F (physical 70) + joypad D-pad up (button 11)
- `wraith` — V (physical 86) + joypad D-pad down (button 12)
- `grenade` — C (physical 67) + joypad D-pad left (button 13)

All edge-triggered → new `slip_press_tick`, `wraith_press_tick`,
`grenade_press_tick` on PlayerInput (grenade fuse cook uses `grenade_held`
level input for release-to-throw). Register as input properties.

## Tasks

- [ ] **Task 1 — Inputs + config + PlayerInput fields.** Actions above;
  MatchConfig keys; PlayerInput `slip_press_tick`, `wraith_press_tick`,
  `grenade_press_tick`, `grenade_held`; register input properties in
  `fps_controller.tscn`. Test: PlayerInput gathers the new press-ticks.
- [ ] **Task 2 — Slip.** Controller `_cast_slip(tick)`: destination = origin +
  (velocity-dir if moving else aim-dir) × `slip_distance_m`; a shape/ray check
  confirms the destination is clear (not inside geometry); on success move
  there preserving velocity, on failure refund (no spend happened) + emit
  `cast_denied`. Gated: no Slip while wraithed/dead. Tests: blink moves ~8 m in
  open space; blocked destination refunds and stays put.
- [ ] **Task 3 — Wraith.** Rollback state `is_wraithed: bool`. Toggle on the
  `wraith_press_tick` (spend 1, only if affordable); continuous drain while
  active; forced out when pool empties. While wraithed: walk speed only, glide
  blocked, weapon fire suppressed (WeaponRig checks `controller.is_wraithed`),
  Repulse/Slip/Grenade casts blocked, bullet + fall damage ignored
  (`take_damage`/`take_zone_damage` early-return while wraithed — except the
  decided Repulse resonance-burn stays a Resonance effect, out of scope here).
  Tests: toggle drains and auto-exits at empty; bullets do nothing while
  phased; weapon cannot fire while phased.
- [ ] **Task 4 — Grenades (projectile + throw + integration).**
  `scripts/weapons/grenade.gd` + `scenes/weapons/grenade.tscn`: rollback state
  `velocity`, `fuse_ticks_left`, ballistic + raycast bounce per tick, detonate
  at 0 → radius AoE (inner = full damage, linear falloff to edge) on the fresh
  detonation tick, then free. Controller: `grenade_stock` rollback state
  (refilled by `initialize_ammo`/round reset), cook timer from `grenade_held`,
  throw on release (or at cook cap) spending one stock, spawns through the
  scene `Projectiles/MultiplayerSpawner`. Repulse's `_push_nearby_bodies`
  nudges grenade velocity. Both scenes get the `Projectiles` node + spawner.
  Tests: throwing consumes stock and spawns a grenade; grenade detonates after
  the fuse and damages a nearby player; cooking shortens time-to-detonation.
- [ ] **Task 5 — Verification + docs.** Live MCP checks in the arena (slip
  moves the player; wraith toggles + drains; grenade detonates); PRD/master-
  plan/tuning-sheet notes; cspell; full suite + three-peer E2E green.

**Buy integration:** `slip`/`wraith`/`grenades` become buyable — Economy's
`_deliver` already routes weapons; add an ability-delivery branch that calls a
new `FPSController.grant_ability(name)` (sets an owned-abilities set; casts
check it). Grenades grant stock. Kept minimal here; full ability-ownership UI
is later.

**Anti-cheat Layer 1:** every cast spends Resonance inside the authority tick;
grenade damage is authority-simulated; no client-reported hits.
