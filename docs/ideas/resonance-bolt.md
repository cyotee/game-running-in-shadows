# Resonance Bolt

**Type:** Manifestation — introduces the **spirit** damage type (aka "soul"; same type as Death Field's, owner-confirmed 2026-07-16)
**Status:** Idea — recorded 2026-07-16

## Concept (owner spec)

- Homing missile dealing **spirit damage** — a new damage type that **bypasses physical damage reduction** (Troll Harden, Armor Skin, etc.).
- Explodes with a small AoE — far smaller than grenades/other explosives.
- **High Resonance cost, minimal cooldown** — tuned as a reliable opening shot, or a finisher to prevent an escape / land a last hit before reloading.
- Deliberately weak DPS: even the Pistol gives faster TTK. **The value is the homing.**
- **Target selection tiebreak: homes on the player with the highest available Resonance.**

## Interactions with decided systems

- **Cooldown framework:** we decided Resonance-only pacing (no cooldowns). "Minimal cooldown" is read as *no recharge timer* — the high cost is the limiter. Flag if a real timer was intended (would be a framework exception).
- **Damage types:** adds `spirit` to direct/pellet/windup/explosive/melee (one type shared with Death Field — "soul" is the same type). Bypasses physical DR by type rule; note Death Field's Troll resistance is per-ability, so Resonance Bolt is NOT resisted by Troll Harden. Katana deflection: spirit presumably NOT deflectable (it homes; also not "direct"). Confirm.
- **Targeting rule is thematically loaded:** it hunts the biggest caster in range — anti-mage seeking. Also means Wraith (high Resonance while phased?) attracts bolts... but Wraith is immune to *bullets*; is a spirit bolt a bullet? A spirit missile hitting Wraiths would be a clean anti-Wraith counter. Decide.
- **Projectile netcode:** first homing projectile — predicted flight with server-confirmed target; the weapons plan's projectile deferral (rockets) shares this work.

## Open questions

- Cost baseline (4? 5?) and damage (enough to finish ~15-20 HP targets?).
- Homing acquisition: nearest in view cone at cast, then tiebreak by highest available Resonance? Define acquisition rules precisely.
- Can it be body-blocked, shot down, or juked (turn rate limit)?
- Does Null field destroy in-flight bolts?

## Research notes

(none yet)
