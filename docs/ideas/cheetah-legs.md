# Cheetah Legs

**Type:** Cybernetic (Augment) — **Leg slot** (new slot; mutually exclusive with Hopper Legs)
**Status:** Idea — recorded 2026-07-16

## Concept (owner spec)

- Doubles ground movement speed (passive).
- Active: short period of **4× speed**.

## Interactions with decided systems

- **Speed budget alarm:** passive 2× on an Elf (fastest base) with light weapons is very fast at 60 tps; 4× active approaches netcode/readability limits (tick-distance, animation, hit registration at slow TTK). This is the idea most likely to need heavy tuning down (e.g. +50%/2× rather than 2×/4×) — record intent, tune in playtests.
- **Overclock overlap:** Overclock passive also boosts move speed (Full Body slot). Cheetah (Leg) + Overclock (Full Body) can stack — is stacked speed intended? Multiplicative stacking at 2× × 1.25 is already extreme.
- **Movement weight:** presumably multiplies after weight penalties. Confirm order of operations.
- **Active cost model:** Resonance cost per activation, HP cost (Overclock-style), or free with duration+grace like Overdrive? TBD.
- **Anti-cheat:** Layer-1 movement validation must know about legit 4× windows.

## Open questions

- Active duration/cost/gating.
- Turn radius / control at 4× (full air-control-style steering or committed dash?).
- Sound design: 4× should be LOUD (counterplay).

## Research notes

(none yet)
