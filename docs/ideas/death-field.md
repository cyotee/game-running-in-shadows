# Death Field

**Type:** Manifestation — deals **spirit** damage (aka "soul" — same type as Resonance Bolt's, owner-confirmed 2026-07-16)
**Status:** Idea — recorded 2026-07-16

## Concept (owner spec)

- Caster emits a damage-over-time field that **follows them** and hurts **ALL players** (enemies AND allies; presumably not the caster — confirm).
- Deals **spirit damage** and **drains Resonance** from those affected.
- **Tuned to counter Elf heal exactly** (field DoT == Elf heal rate → a fleeing Elf can't out-heal it).
- **Troll damage reduction DOES apply as an ability-specific carve-out** — despite spirit damage normally bypassing physical DR, Troll stone-skin resists *this ability* (the carve-out belongs to Death Field, not to the spirit type; Resonance Bolt is unaffected by Harden).
- **Duration/cost model:** runs while the caster has Resonance, draining the caster's pool; tuned such that a same-archetype caster and victim (no DR, no HP boosts, no healing) leaves the victim at **10% HP when the caster's Resonance runs out**.
- **Recast gate: cannot be cast again until Resonance FULLY recharges.**
- **Owner-noted trade-off (intended):** cybernetics lower your max available Resonance → the full-recharge gate is reached sooner (cast more often) but the field runs for less time. An inherent check/trade-off, not a bug.

## Interactions with decided systems

- **Framework exception:** "cannot recast until fully recharged" is a *condition*, not a timer — arguably still Resonance-only pacing, but it's the first full-pool gate. Record as a deliberate special rule.
- **Any-combat gating (owner-confirmed 2026-07-16):** Death Field ticks do **NOT** mark combat — the field always ticks, in and out of combat, and victims' regen/Elf-heal keep running against it. That's the trade-off: it hurts everyone, teammates included, continuously. Same emergent-design principle as bleed.
- **Soul vs bleed stacking:** Death Field + backstab bleed = 2× Elf heal rate drain — lethal combo by design?
- **Second Heart (idea):** a Second Heart victim negates the field's HP damage (still loses Resonance). Cross-reference.
- **Hurts allies:** with full friendly fire decided, an ally-damaging aura is consistent — but it makes the caster a walking hazard for their own team. Strong identity; note comms burden.
- **Netcode:** same victim-side-tick pattern as Tangle's vortex — victims read "am I in the field?" in their own rollback tick. Cheap.

## Open questions

- Field radius; does it damage the caster's Resonance only via upkeep or also the caster's HP?
- Exact DoT (== Elf heal 4 HP/s at baseline) and Resonance drain per second on victims.
- Troll carve-out size (Harden %? flat?).
- Does Null field / Dwarf aura suppress it (draining the caster faster = shorter field)?

## Research notes

(none yet)
