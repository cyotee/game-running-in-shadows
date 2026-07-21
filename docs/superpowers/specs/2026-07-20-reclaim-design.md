# Reclaim — Design (G5 Wave 3, ability 1)

**Status:** APPROVED 2026-07-20 · **Branch:** `feat/reclaim` ·
**Master plan item:** G5 Wave 3 (needs G6 corpses ✅)

## 1. Purpose & scope

Reclaim is a self/instant Manifestation that **revives fallen allies via their
corpses** within a 6m radius. It consumes the corpse (body denial matters).
Revived allies return at 50% health with the **unlooted** weapons/ammo/grenades
recorded on the corpse. The caster **holds 4 Resonance** while any revived ally
lives; the caster's death makes revived allies **bleed out**.

**In scope (this pass):**
- New edge-triggered `reclaim` input action (press-tick).
- Radius revive gated on a **dead ally's corpse** in range; corpse is consumed.
- Ally = same `MatchState` team; team-less context (team `-1`) → any dead player.
- Revive at 50% health with gear restored from the corpse snapshot.
- 4 Resonance held while any revived ally lives; released when none remain.
- Caster death → revived allies bleed out.
- MatchConfig tuning; unit tests + an E2E revive-replication check.

**Out of scope (deferred, documented):**
- Revive VFX / partial-gear HUD.
- "Reservation scales down when losing" economy tie-in (needs a losing signal).
- Reviving a dead ally who has **no** corpse (denied bodies stay denied — decided).

## 2. Core principle — cross-node writes use plain-pending, never direct rollback writes

The G6 corpse-drag lesson: **a write to another node's rollback state from the
caster's tick is snapshotted away.** So the caster only *requests*; each affected
node applies the change in its **own** `_rollback_tick`:
- Revive uses the same **plain pending-var** mechanism as `reset_for_round`
  (`_pending_respawn`/`_has_pending_respawn` are plain vars, consumed in the
  owner's own tick — out-of-band writes to *plain* vars persist; the in-tick
  apply mutates rollback state where it sticks).
- Corpse consumption uses a plain `_pending_reclaim_destroy` the corpse reads in
  its own tick.
- Caster-death bleed-out is a **victim-side pull** (Tangle pattern): the revived
  player checks its reviver in its own tick.

## 3. Components

### 3.1 Input — `reclaim` action

- `scripts/player/player_input.gd`: add `reclaim_press_tick: int = -1`,
  `_pending_reclaim: bool`, `_held_reclaim: bool`; poll in `_process`
  (`_pending_reclaim = _pending_reclaim or (reclaim_now and not _held_reclaim)`),
  stamp `reclaim_press_tick = NetworkTime.tick` in `_gather`, clear the latch.
- `scenes/player/fps_controller.tscn`: add `"Input:reclaim_press_tick"` to
  `RollbackSynchronizer.input_properties`.
- `project.godot`: `reclaim` action — keyboard **`H`** (physical_keycode 72,
  confirmed free) + joypad **D-pad Left** (button_index 13). Rebindable.

### 3.2 `FPSController._cast_reclaim(tick, is_fresh)`

Dispatched in `_rollback_tick` alongside the other casts:
`if not is_wraithed and input.reclaim_press_tick == tick: _cast_reclaim(tick, is_fresh)`.

```
cost = MatchConfig resonance.reclaim_cost
if reclaim_reserved or _in_null_field() or resonance.current < cost:
    deny (cast_denied on fresh); return
targets = corpses within reclaim.radius_m whose owner is a *dead ally*
if targets empty:
    deny (nothing to revive); return
for corpse in targets:
    owner = _find_player(corpse.owner_peer)   # dead ally's controller
    owner.queue_reclaim_revive(corpse.global_position, my_peer, corpse_snapshot(corpse))
    corpse.queue_reclaim_destroy()
resonance.reserve(cost); reclaim_reserved = true; reclaim_cast_tick = tick
```

- **Ally check:** with `MatchState` present and the caster's team `!= -1`, the
  corpse owner's team must equal the caster's team. Team `-1` (no MatchState) →
  any dead owner qualifies. Reuse a `_match_state`-style lookup (find `MatchState`
  in the tree; PingService already established the pattern, or read from the
  session). The caster never revives itself while alive (it isn't dead).
- **`corpse_snapshot(corpse)`** rebuilds the flat array
  `[w1_key, w1_mag, w1_reserve, w2_key, w2_mag, w2_reserve, grenades]` from the
  corpse's current (post-loot) fields — looted slots are `""`.

### 3.3 Revive (owner's own tick)

- `queue_reclaim_revive(pos, reviver_peer, snapshot)` — sets plain pending vars
  (`_has_pending_reclaim`, `_pending_reclaim_pos`, `_pending_reclaim_reviver`,
  `_pending_reclaim_snapshot`).
- Applied in `_rollback_tick` when `is_fresh` (before the `is_dead` early
  return, so a dead player can revive), via `_apply_pending_reclaim()`:
  - `is_dead = false`, clear bleed, `velocity = ZERO`, `global_position = pos`.
  - `_apply_archetype_config()` then `health = revive_health_frac * max_health`.
  - Restore gear from the snapshot: for each non-empty weapon key, `queue_grant`
    it and set that weapon's `mag`/`reserve` in-tick; set `grenade_stock` from
    the snapshot. (Mag/reserve are the weapon's rollback state, set here in the
    owner's own tick so it sticks.)
  - `revived_by_peer = reviver_peer`.

### 3.4 Corpse consume (corpse's own tick)

- `Corpse.queue_reclaim_destroy()` sets a plain `_pending_reclaim_destroy = true`.
- `Corpse._rollback_tick`: `if _pending_reclaim_destroy and not removed: removed = true`
  (its own tick — sticks; `_process` frees it as today). Distinct from normal
  respawn (which leaves the corpse); only Reclaim consumes it.

### 3.5 Held reservation + bleed-out

- **Caster reconcile** (extend `_reconcile_field_reservations` or a sibling):
  `if reclaim_reserved and tick > reclaim_cast_tick + 30 and not _any_revived_alive(my_peer): resonance.release(cost); reclaim_reserved = false`.
  `_any_revived_alive(peer)` scans players for an **alive** one with
  `revived_by_peer == peer`. Grace window (30 ticks) mirrors the field-reservation
  race guard.
- **Bleed-out (revived player's own tick, pull):** `if revived_by_peer != 0:` find
  the reviver; if `reviver == null or reviver.is_dead` → `apply_bleed(reclaim.bleedout_hp_per_s, reclaim.bleedout_duration_s)` and set `revived_by_peer = 0`
  (one-shot). `revived_by_peer` also clears on the player's own death and on
  `_apply_pending_respawn` (normal round reset).

### 3.6 Rollback state & config

- **New FPSController rollback state** (register in `fps_controller.tscn`
  `state_properties`): `reclaim_reserved: bool`, `revived_by_peer: int`, and
  `reclaim_cast_tick: int` (the grace-window marker — rollback state, exactly
  like `lifebloom_cast_tick`).
- **New plain pending vars** (FPSController): `_has_pending_reclaim: bool`,
  `_pending_reclaim_pos: Vector3`, `_pending_reclaim_reviver: int`,
  `_pending_reclaim_snapshot: Array`. **Corpse:** `_pending_reclaim_destroy: bool`.
- **MatchConfig `DEFAULTS`:** `resonance.reclaim_cost` 4.0, `reclaim.radius_m` 6.0,
  `reclaim.revive_health_frac` 0.5, `reclaim.bleedout_hp_per_s` 8.0,
  `reclaim.bleedout_duration_s` 10.0.

## 4. Data flow (happy path)

1. Caster presses `reclaim` → press-tick stamped → `_cast_reclaim` on that tick.
2. Finds a dead ally's corpse in radius; requests revive on the owner + destroy
   on the corpse (plain pending vars); reserves 4 Resonance.
3. Owner's next fresh tick: revives at 50% health with restored gear, sets
   `revived_by_peer`.
4. Corpse's next tick: `removed = true`; frees in `_process`.
5. While the revived ally lives, the caster holds the reservation.
6. If the caster dies, the revived ally (its own tick) sees the reviver dead →
   bleeds out, clears `revived_by_peer`; caster reservation reconciles to
   released (and resets on caster respawn).

## 5. Edge handling

- **No corpse in radius / all denied:** cast denied (nothing to revive), no spend.
- **Corpse owner already alive** (shouldn't happen — corpse owner is dead when
  revivable): guard by requiring `owner.is_dead`.
- **Null field:** `_in_null_field()` suppresses the cast (like other casts).
- **Wraithed caster:** cast blocked (dispatch guard `not is_wraithed`).
- **Team-less/headless:** team `-1` → any dead qualifies; fully testable.
- **Out-of-band safety:** every cross-node effect goes through plain-pending +
  own-tick apply — no direct rollback-state writes across nodes.

## 6. Testing

- **`tests/abilities/test_reclaim.gd`** (extends `NetSuite`, arena scene):
  - Dead ally with a corpse in radius → after cast, ally `is_dead == false`,
    `health ≈ 50%`, restored weapon key present, corpse `removed`.
  - Corpse out of `reclaim.radius_m` → ally stays dead, corpse untouched.
  - Enemy-team corpse (set teams via a `MatchState`) → not revived; same corpse
    in team-less context → revived.
  - Reservation: `resonance.reserved` rises by cost after a revive and releases
    after the revived ally dies again (+ grace).
  - Caster death → revived ally gains bleed (`bleed_ticks_remaining > 0`) and
    `revived_by_peer` clears.
  - Denied when `resonance.current < cost`, in a Null field, or no corpse.
  - Follow the corpse-suite `after_test` cleanup (free `corpses`) to avoid the
    G6 leak.
- **E2E (`tests/e2e/net_smoke.py`):** a client revives a downed peer's corpse;
  host confirms the revived peer `is_dead == false`. (Reuse the eval harness.)

**Gates:** headless suite `0 errors | 0 failures` exit 0 per task; E2E PASS;
cspell clean; `--no-ff` merge to main; master-plan G5 Wave-3 Reclaim ✅.

## 7. Build order (for the plan)

1. Input action + `reclaim` press-tick plumbing (`PlayerInput` + `input_properties`).
2. MatchConfig keys + `reclaim_reserved`/`revived_by_peer` state registration.
3. `_cast_reclaim` + ally/corpse selection + revive request (deny paths first, TDD).
4. Owner revive apply (`_apply_pending_reclaim`, gear restore) + corpse consume.
5. Held reservation reconcile + caster-death bleed-out pull.
6. E2E + docs (tuning sheet, MECHANICS §11 key, master-plan ✅).
