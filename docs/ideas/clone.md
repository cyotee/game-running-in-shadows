# Clone

**Type:** Manifestation
**Status:** Idea — recorded 2026-07-16

## Concept (owner spec)

- Creates an illusionary clone of the caster.
- **Locks (reserves) Resonance per clone while active; no cast cooldown; cast as many clones as the reserve allows.**
- **Clones mimic the player's actions exactly** — e.g. when the caster aims and shoots at an enemy, each clone aims and shoots at the *same relative angle* (likely missing).
- Skill challenge: the caster must act in ways that make the real player hard to identify.
- Clones are illusionary: **no collision with the environment — they pass through walls**, which can reveal the caster's approach (a clone drifting through geometry gives the trick away).
- Very high skill ceiling.

## Interactions with decided systems

- **Resonance:** reservation-per-clone uses the decided held/empty-return mechanics; a Dwarf or Null field draining the caster naturally pops clones (reservation forced down) — confirm that rule.
- **Effects die with caster** — clones vanish on death (decided framework rule applies).
- **Netcode:** clones replay the caster's recorded input stream with a positional offset — netfox input properties make this surprisingly cheap (clones are non-colliding puppets driven by the same tick inputs). No hit registration ON clones (illusion) — or should shooting a clone pop it? (Open question.)
- **Smart Rig interaction:** does forced-view tracking lock onto clones? (If yes, clones counter Smart Rig; delicious with the Optical Camouflage family.)
- **Pulse Sight:** do clones appear in wall-reveals? (If yes, Pulse Sight can't distinguish either — strong; if no, Pulse Sight is the counter.)

## Open questions

- Do clones pop when shot (revealing the miss) or do bullets pass through (revealing via no hit feedback)?
- Do clones mimic weapon tracers/sounds? (Audio mimicry is most of the deception value.)
- Offset model: mirrored, fixed lateral, or caster-chosen at cast?
- Reserve cost per clone (baseline guess: 2 held each).

## Research notes

(none yet)
