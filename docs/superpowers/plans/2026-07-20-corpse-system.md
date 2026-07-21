# Corpse System (Gap G6) Implementation Plan

> Execute with superpowers:executing-plans. Decided design: MECHANICS_REFERENCE
> §11 — full body persistence in ALL modes, corpses remain after respawn,
> per-player corpse limit, corpses carry inventory (weapons/ammo/grenades as at
> death) and are lootable, dragging limited to Pistol/SMG weapon use
> (decided 2026-07-17). Prerequisite for Reclaim (Wave 3).

**Goal:** A persistent Corpse entity spawned on death carrying the dead
player's inventory snapshot; per-owner corpse limit; looting (grant a weapon
from a nearby corpse); dragging (corpse follows the dragger, whose weapon use
is restricted to Pistol/SMG while dragging).

**Architecture:** `Corpse` (`scripts/abilities/corpse.gd`, Node3D +
RollbackSynchronizer) carries scalar rollback state — `owner_peer`,
`spawn_tick`, two weapon slots (`w1_key/w1_mag/w1_reserve`, `w2_...`),
`grenades`, and `dragged_by` (peer, 0 = none). Spawned via the generalized
spawner (new `"corpse"` kind) on the fresh death tick from
`FPSController`. Looting/dragging use a new `interact` input (hold). While
dragging, the corpse's position tracks the dragger each tick (deterministic);
the dragger's `is_dragging` gates weapon fire to Pistol/SMG in `WeaponBase`.
Per-owner limit enforced at spawn (free the oldest by `spawn_tick`).

## Tasks

- [ ] **Task 1 — Inputs, config, Corpse entity + spawn on death.** `interact`
  action (hold) + `interact_held` input; config `corpse.max_per_owner`,
  `corpse.loot_range_m`, `corpse.drag_range_m`. `Corpse` scene/script with the
  state above + `snapshot(controller)`; spawner `"corpse"` kind; controller
  spawns a corpse on the fresh death tick with its inventory; per-owner limit.
  Tests: death spawns a corpse with the loadout; a respawn (reset_for_round)
  leaves the corpse; limit frees the oldest.
- [ ] **Task 2 — Looting.** `interact` press near a corpse grants its first
  non-empty weapon to the looter (`queue_grant`) and clears that slot; ammo
  carried. Tests: looting grants the weapon and empties the slot; out-of-range
  interact does nothing.
- [ ] **Task 3 — Dragging.** `interact_held` on a corpse in range sets
  `dragged_by`; the corpse tracks the dragger's position each tick; releasing
  clears it. `FPSController.is_dragging` true while dragging; `WeaponBase`
  blocks fire unless the active weapon is Pistol/SMG. Tests: drag moves the
  corpse; a Rifle cannot fire while dragging, a Pistol can.
- [x] **Task 4 — Verify + docs.** Full suite (117/117) + three-peer E2E (PASS);
  master-plan queue updated; cspell. (Live MCP arena walkthrough deferred — the
  automated suite + E2E cover the behavior; revisit during the next arena play
  session.)

**Deferred (documented):** corpse destruction to deny Reclaim (objective-weapon
interaction — lands with G8 objective items); scavenging reserve ammo into the
weapon system beyond the looted weapon's own mag/reserve (loot currently grants
a fresh weapon via `queue_grant`, ammo-carry not yet wired); the Power Arm idea
(upgrades drag weapon restriction — docs/ideas/power-arm.md).

---

> **Status: EXECUTED 2026-07-20 (feat/corpse-system branch).** All 7 corpse
> tests pass; full suite **117/117** (exit 0, at loadavg ~10); three-peer E2E
> `net_smoke.py` PASS.
>
> The previously-flagged `test_drag_moves_corpse_toward_dragger` failure (and the
> intermittently-undiscovered `test_weapon_restricted_to_pistol_smg_while_dragging`)
> were NOT load flakiness and NOT a production bug — they were a single
> **test-isolation leak**: `_spawn_corpse_near` parents the corpse under
> `host.get_parent()`, which for CONTROLLER_SCENE tests is the runner's
> container (a *sibling* of the freed scene), so loot-test corpses survived
> `after_test` and accumulated in the global `corpses` group. The arena drag
> test then found a leaked loot-test corpse at x=1.0, closer than its own x=1.5
> corpse, and `FPSController._nearest_corpse` selected the leaked one — so the
> intended corpse never got dragged. Fixed by freeing all `corpses` in
> `after_test` (commit `3393474`). Production code unchanged — the push-based
> `set_dragged_by` path is correct.
>
> Learned: out-of-band rollback-state writes from tests (health, active_slot)
> are discarded by the state restore — use in-tick paths (`queue_damage`,
> `select_slot`); a corpse follow/drag test needs a floor (a falling dragger
> drifts out of drag range); and any test that spawns a persistent grouped node
> beside the scene must clean the group up in `after_test` or it contaminates
> later tests' nearest-node selection.
