# Ability Roster Wave 2 — Lifebloom, Tangle, Null Charge (Gap G5.2) Plan

> Execute with superpowers:executing-plans. Decided design: MECHANICS_REFERENCE
> §4.A (placed effects cast instantly at an aimed point with max range; effects
> die with their caster; reservations release EMPTY on death) and §2 Resonance
> semantics. These are the "persistent networked objects" flagged in PRD §7.

**Goal:** The three placed/persistent field abilities, all rollback-simulated
like the grenade projectile:
- **Lifebloom** (Manifestation, 3 held) — friend-or-foe heal aura (~6 HP/s,
  7 m) that heals regardless of combat state; shootable HP; withers (~3 min);
  reserves Resonance while alive.
- **Tangle** (Manifestation, 2 held) — pull vortex dragging enemies within
  ~4 m toward center (applied inside each victim's own rollback tick from
  world state); allies impeded, not pulled; blocks gunfire; grenades/Null pass
  through; shootable HP; withers.
- **Null Charge** (Augment, limited stock) — sticky anti-magic field (~5 m,
  ~10 s) that drains enemy Resonance (~1/s), suppresses casting within, and
  destroys other Manifestation fields inside; shootable HP.

**Architecture:** A shared `PlacedField` base (`scripts/abilities/placed_field.gd`,
Node3D + RollbackSynchronizer) carries rollback state `hp`, `ticks_left`,
`caster_peer`; ticks wither + die-with-caster; exposes `take_field_damage`.
Fields spawn through the existing `Projectiles/ProjectileSpawner` (extended to
a generic field/projectile spawner keyed by a `kind` tag). Casts are instant
placement at an aimed world point (raycast to max range, else max-range point).
Cross-entity interactions (pull in victim tick, gunfire block, cast suppress,
field destruction) integrate into controller/weapon as noted per task.

## Tasks

- [ ] **Task 1 — Inputs, config, `PlacedField` base + spawner.** Actions
  `lifebloom`/`tangle`/`null_charge` (Z/X/B) as press-ticks; all MatchConfig
  keys; `PlacedField` base (hp/ticks_left/caster wither + die-with-caster +
  take_field_damage); generalize the spawner to spawn any field/grenade scene
  by kind. Test: base withers to death; dies when caster leaves.
- [ ] **Task 2 — Lifebloom.** Heal aura each tick (all players in radius,
  ignores combat); reserves 3 on cast, releases on death (empty). Controller
  cast on press-tick (instant placement, hard-block if unaffordable). Tests:
  heals a hurt player in radius (friend or foe); node dies from damage +
  releases reservation.
- [ ] **Task 3 — Tangle.** Pull applied in each enemy's rollback tick from the
  nearest Tangle in range (deterministic); allies not pulled; a Tangle body on
  a `field_block` layer stops direct weapon rays (grenades/Null unaffected).
  Tests: enemy velocity pulled toward center; ally not pulled; ray blocked.
- [ ] **Task 4 — Null Charge.** Limited stock; drains enemy Resonance in
  radius; `FPSController._in_null_field()` suppresses casts; destroys other
  `PlacedField`s in radius (fresh tick). Tests: drains a nearby enemy; a cast
  inside a Null field is denied; a Lifebloom inside is destroyed.
- [ ] **Task 5 — Verify + docs.** Live MCP arena checks; full suite +
  three-peer E2E; PRD/master-plan/tuning-sheet notes; cspell.

**Deferred (documented):** Dwarf-proximity destroys fields (Dwarf aura already
drains Resonance; field destruction folds in with the ability-ownership pass);
"two Lifebloom nodes weaken each other"; exact ally-impede slow. Buy/ownership
gating stays deferred with the rest of the abilities (Wave 1 precedent).
