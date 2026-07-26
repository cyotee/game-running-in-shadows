# Mechanics Reference

**Project:** CounterSpell  
**Status:** v0.2 — Draft (2026-06-29) — Updated with team design decisions: Resonance resource, Human/Elf/Dwarf/Troll archetypes, full body persistence, configurable bindings, strict buy phase for MVP, passive Dwarf drain + headshot immunity, variable flag items, Steam Input priority.  
**Purpose:** Detailed mechanical inspiration + our design decisions  
**Scope:** Core gameplay systems (resource, archetypes, abilities, weapons, interactions, economy)

> **Important:** This is an *original IP spiritual successor*. All names, numbers, and behaviors described under "Our Design" are original. Source inspiration is noted explicitly for reference only. We reproduce *feel and structure*, never protected terminology or direct copies.

---

## 1. Design Pillars (Recap)

From the PRD:
1. **Gun + Magic + Chrome** — Primary weapons feel excellent. Powers have meaningful costs and counters.
2. **Asymmetric Archetypes** — Distinct playstyles that remain viable together.
3. **Tactical Mobility & Verticality** — Strong movement tech (wall-running, leaps, boosts, glides).
4. **The Grid Matters** (future) — Hacking influences the physical fight.
5. **Gritty, Replayable PvP** — Round-based economy, high-stakes abilities, resurrection tension.

The 2007 game’s greatest strengths were the **unified resource** (essence), **deliberate magic-vs-chrome tradeoffs**, **movement tech combos**, and **resurrection/body play**.

---

## 2. Core Resource: Resonance

**Inspiration:** "Essence" in the source game was the single most important system. It paid for magic, was reserved ("held") by active effects, powered regeneration for some races, and was penalized by tech. This created the central tension between magic and chrome.

**Our Design — Resonance**

- Unified resource for **Manifestations** (awakened powers) and **Augments** (cyber/tech).
- Spent on activation.
- Some abilities "reserve" or "hold" Resonance while active or while their effects persist (e.g. summoned allies, fields).
- Certain Augments permanently reduce maximum Resonance or increase ability cooldowns.
- Some archetypes have natural Resonance regeneration or conditional healing tied to Resonance.
- Resonance also indirectly influences survivability (via regen or defensive passives).

**Key Tensions We Want**
- Heavy Augment users become weaker casters (higher cooldowns or lower max Resonance).
- Pure Manifestation users are fragile or have other tradeoffs.
- "Hybrid" builds are viable but require careful timing and positioning.

**World Flavor Note:** Resonance is styled with a music-influenced motif ("Music of the Spheres") to help distinguish the game's world and lore from source material.

**Long-term Vision Alignment**
- Designed with Steam Workshop mod support in mind (flexible bindings, data-driven configs, and distinct systems make it easier for community content).
- Regular updates and live ops friendly (buy phase + Resonance economy allow balance patches without breaking persistence).
- All terminology and mechanics kept legally distinct while capturing the desired cyber-fantasy runner fantasy.

**Proposed Starting Values (for prototyping)**

| Archetype | Base Max Resonance | Natural Regen | Tech Penalty | Notes |
|-----------|--------------------|---------------|--------------|-------|
| Human     | 10                 | Low           | None         | Best hybrid potential |
| Elf       | 12                 | High (out of combat) | Moderate | Strong caster, fragile |
| Dwarf     | 14                 | Very Low      | High         | Drains from others/objects |
| Troll     | 8                  | None          | Low          | Least Resonance, most health |

**Decided Semantics (2026-07-16, owner decisions)**
- **Float core, pip display:** internally a float (smooth per-tick regen/drain); HUD shows whole pips with a partial-fill indicator on the recharging pip. Costs are whole numbers.
- **Any-combat regen gating:** taking OR dealing damage marks the player "in combat"; regeneration pauses until the combat timer (baseline 4 s, tunable) has elapsed, then resumes at the archetype rate.
- **Hard block on insufficient Resonance:** casts fail with clear denial feedback; no health overdraft, no partial casts. (Wraith's overflow-to-health remains an enemy-inflicted drain special case only.)
- **Reservations return EMPTY:** reserving locks pips at the top of the pool (cap = max − reserved). When a held effect ends, the capacity returns but the pips come back empty and must regenerate. Losing a summon or field genuinely hurts; Null Charges and Dwarves are hard counters by design.
- **Tech penalty = scaled reservation:** each Augment has a base reservation cost, multiplied by the archetype's tech multiplier — Human ×1.0, Troll ×1.25, Elf ×1.5, Dwarf ×2.0.
- **Dwarf drain destroys** (no siphon): drained Resonance vanishes. Baselines: 6 m radius, 0.5/s per enemy in radius (field-effect drain rate decided when fields exist).
- **Elf heal auto-converts, gated:** while out of combat and below max health, Resonance converts to health automatically (baseline 1 Resonance → 8 HP at 0.5 Resonance/s), stopping at a floor of 2 Resonance.
- **Spawn state:** full pool minus reservations.
- **Everything above is a tunable:** all values ship as match-config properties injected at game start so private hosts can tune the game to their taste (see §11 Match Config).

**Implementation Notes**
- Track current Resonance + reserved Resonance as netfox rollback state.
- Display as pips + partial fill; reserved pips visually locked.

---

## 3. Archetypes (Lineages)

**Inspiration Summary (Source)**

| Source Race | Strengths | Trade-offs |
|-------------|-----------|------------|
| Human | Tech-friendly, balanced, extra starting money | No special passive |
| Elf | Fastest, fastest regen, out-of-combat healing | Lowest health & defense |
| Dwarf | Highest essence, headshot immunity, drains magic & players | Slowest regen |
| Troll | Highest health, adaptive defense when hit | Slowest, least essence, defense slows them |

**Our Design**

We use the common mythological terms Human, Elf, Dwarf, and Troll for our four core archetypes. These capture the same fantasy and mechanical roles. All specific mechanics, names, and balancing are original to CounterSpell.

### Human
- **Fantasy:** The adaptable professional. Good at everything, great at nothing extreme.
- **Mechanics:**
  - Starts with extra buy money each round.
  - No Resonance penalty for Augments.
  - Balanced health and speed.
- **Playstyle:** Flexible hybrid or specialist. Team "glue" player.

### Elf
- **Fantasy:** Ethereal, fast, hard to pin down. Relies on hit-and-run and recovery.
- **Mechanics:**
  - Highest base movement speed (light load).
  - Fastest natural Resonance regeneration.
  - Regenerates health using Resonance when not taking damage recently.
  - Lowest base health.
- **Playstyle:** Flanker, scout, mobile caster. Loses advantage when carrying heavy weapons.

### Dwarf
- **Fantasy:** Living null-field. Drains power from the awakened world and from others.
- **Mechanics:**
  - Highest base max Resonance.
  - Very slow natural regeneration.
  - Passively drains Resonance from nearby enemies and destroys/weakens active Manifestation effects (fields, summons, etc.) by proximity.
  - Headshot resistance (or full immunity in early prototypes).
- **Playstyle:** Anti-magic specialist, area denial, close-range disruptor. Excellent against heavy casters.

### Troll
- **Fantasy:** Living fortress. Gets tougher the more you hit it — at a cost.
- **Mechanics:**
  - Highest base health.
  - When damaged, gains temporary "Harden" stacks that reduce incoming damage.
  - Harden stacks also reduce movement speed.
  - Lowest base max Resonance.
  - Least affected by heavy weapon movement penalties.
- **Playstyle:** Anchor, objective holder, minigun/rocket carrier. Needs support when isolated.

**Future Archetypes (Post-MVP)**
- Decker/Grid specialist
- Rigger/drone controller
- Shaman/spirit-focused
- Street Samurai (heavy melee/chrome focus)

---

## 4. Abilities: Manifestations & Augments

Players buy abilities in a pre-round phase and equip a limited number (currently planned: 3 slots, mix of Manifestations and Augments allowed).

### Manifestations (Awakened Powers)

| Name | Buy Cost (prototype) | Resonance Cost | Type | Core Effect | Key Interactions |
|------|----------------------|------------|------|-------------|------------------|
| **Lifebloom** | $1800 | 3 (held) | Field | Plants a node that heals all nearby players (friend or foe). Provides limited cover. Slowly withers. | Drained/destroyed by Dwarves and Null charges. Two nodes near each other weaken each other. |
| **Reclaim** | $1800 | 4 (held, scales down when losing) | Utility | Revives fallen allies in a radius. If caster dies, revived allies begin bleeding out. | Bodies can be denied. Creates high-stakes decisions. |
| **Tangle** | $1800 | 2 (held) | Control | Grows crystal/razor growth that pulls in and damages/traps enemies. Blocks most gunfire. | Grenades and Null charges pass through. Allies are impeded but not pulled. Dwarves destroy quickly. |
| **Repulse** | $1600 | 2 | Instant | Powerful directional blast of force. Knocks enemies, pushes projectiles/objects, slight damage. | **Core movement tech.** Look down + Repulse + Glide Harness = big upward launch. |
| **Wraith** | $1700 | 1 + drain | Form | Become a phased cloud. Immune to bullets and fall damage. Cannot attack or use most abilities. Hard to spot. | Repulse does heavy Resonance damage to Wraithed players (can overflow to health). Null drains it. |
| **Slip** | $2000 | 3 | Movement | Short-range blink (≈8m) in the direction of current velocity. Can pass through solids (fails safely). | Can be disrupted by Null fields. Double upward for extra height. |
| **Familiar** | $2500 | 4 (held) | Summon | Calls a combat minion. Can be set to guard an area or hunt a target. Minions fight each other. | Destroyed by Null charges and Dwarves. Good for body denial in some modes. |

### Augments (Chrome / Tech)

| Name | Buy Cost | Resonance Impact | Type | Core Effect | Key Interactions |
|------|----------|--------------|------|-------------|------------------|
| **Glide Harness** | $1800 | 2 reserved | Mobility | Deploys wings for floaty descent and safe falls. Activate with the glide key or jump while airborne (no free air-jump). | **Look down + Repulse + deploy** = powerful launch (the only intentional upward while gliding; enemy Repulse hits still apply force). Self-Repulse while gliding slams you down. |
| **Pulse Sight** | $1700 | 3 reserved | Intel | Briefly reveals all enemies in a large radius through walls. | Wraith hides targets (limited range ping remains). |
| **Smart Rig** | $1700 | 2 reserved | Combat | Passive extra zoom on all weapons. Active: improved tracking + no friendly fire from direct fire. | Disabled vs Wraith. Laser sight reveals position. |
| **Null Charge** | $1400 | — (starts with limited stock) | Denial | Throwable device that sticks and projects an anti-awakening field. Destroys active Manifestations and drains Resonance. | Core counter to casters. Disrupts Slip even outside visual radius sometimes. |
| **Overclock Rig** | $1800 | Varies by archetype (lower on Troll) | Mobility/Combat | Passive speed, jump, and reload boost. Active: bigger burst + self-damage cost. | Excellent with melee. Provides defensive bullet blocking vs certain weapons when active. |
| **Grenades** | Free (2 per round) | — | Utility | Standard frag grenades. | Can be Repulsed for trick shots. Dropped on death. |

**Slot System (superseded 2026-07-16 — see Cybernetic Slots below and §11 Ability Slots & Binding)**
- Bindings: no hard slot limit; any activatable ability binds to any input (decided 2026-06-29).
- **Cybernetic Slots (decided 2026-07-16):** Augments occupy body slots; Augments sharing a slot are mutually exclusive per match. **Cybernetics are permanent once purchased** — they cannot be removed or replaced for the rest of the match (their scaled reservation persists). Intent: purchase commitment as risk/reward, and slot pressure that incentivizes team coordination.
  - Pulse Sight — **Eye** slot.
  - Smart Rig — **Eye + Full Body** slots (it aims the eyes and drives the body).
  - Overclock Rig — **Full Body** slot.
  - Lore: two Full Body systems issuing conflicting motor commands would cause seizures.
  - Net effect: Smart Rig excludes both Pulse Sight and Overclock; Pulse Sight + Overclock is a legal pairing.
  - Glide Harness / Null Charge / Grenades are equipment (no body slot).

## 4.A Decided Ability Designs (2026-07-16, owner decisions)

**Framework rules (bind all abilities)**
- **Resonance-only pacing:** no cooldowns anywhere; the pool, any-combat regen gating, and reservations are the pacing. (Overclock's grace-period reset timer is an internal mechanic, not a recharge cooldown.)
- **Instant + placement casts:** everything fires on keypress; placed effects (Lifebloom, Tangle, Null Charge throw) cast instantly at an aimed point with max range. No wind-ups or channels.
- **Effects die with their caster;** reservations release on death (returning empty, per the Resonance rules).
- **Full v0.2 roster ships in EA** — the counter web is a closed system; cut late only on playtest failure.
- **Full friendly fire** on all damage sources (Smart Rig's active is the exception mechanism).

**Manifestations**
- **Repulse** — as implemented (netfox plan): directional force blast, self-push, combo with Glide. Cost 2.
- **Slip** — velocity-directional blink (~8 m along current velocity; aim direction when stationary); passes through solids when the destination is clear; failed cast (no clear destination) refunds the cost with a fizzle cue.
- **Wraith** — toggle on (cost 1) + continuous drain (~1.5/s); forced out when pool empties. Walk speed only; weapons/abilities/glide locked while phased; immune to bullets and fall damage. **Rematerialization is instant — no vulnerability window.** Intent: infiltration and assassination. Balanced by drain, Repulse resonance-burn (overflow to health), Dwarf aura, Null fields.
- **Lifebloom** — friend-or-foe constant aura (~6 HP/s, 7 m); **heals regardless of combat state** (in-combat healing is a deliberately scarce category — currently only Lifebloom, plus the Second Heart idea if promoted); node has HP (shootable), withers (~3 min); two nodes near each other weaken each other. Planting is a tactical commitment (bait/steal games intended).
- **Tangle** — **active pull vortex**: continuously drags enemies within ~4 m toward center; allies impeded, not pulled; blocks most gunfire; grenades and Null charges pass through. Implementation note: the pull is applied inside each victim's own rollback tick from world state (deterministic, prediction-friendly).
- **Reclaim** — instant radius revive (6 m): revived allies return at **50% health with their bought abilities AND their weapons/ammo/grenades as they were at death — unless looted.** 4 Resonance held while any revived ally lives; caster death starts bleed-out on revived allies. **Corpse defense, destruction, and looting are a strategic pillar** (see §11 corpse decisions; looting mechanics land with the corpse system).
- **Familiar** — **ping-targeted hunt**: caster pings an enemy to send the Familiar after them (requires the ping system); otherwise follows the caster. Destroyed by Null charges and Dwarves; minions fight each other.

**Augments**
- **Glide Harness** — as implemented (netfox plan). Reservation 2 × tech multiplier. Deploy via glide key or airborne jump; no mid-air jump boost while gliding. Upward launch only from Repulse+Glide combo (external Repulse hits still apply force).
- **Null Charge** — persistent sticky field: sticks where thrown, ~5 m radius, ~10 s; destroys Manifestation effects inside, drains enemy Resonance (~1/s), suppresses casting within; has a small HP pool (shootable). Limited stock per round.
- **Pulse Sight** (Eye) — active ~5 s wall-reveal in a large radius, **self-only, except teammates who own Pulse Sight or Smart Rig also see the reveal** (chrome-networked intel; rewards coordinated cyber builds). Wraithed players: faint short-range ping only.
- **Smart Rig** (Eye + Full Body) — passive: zoom on all weapons. Active: **forced view tracking ("legal aimbot")** — the user's view is magnetically dragged to the nearest target's center of mass; headshots become very difficult (view pinned to center mass); if the target moves, the user's view is forced to turn and track them. Shots cannot hurt teammates while active; the targeting laser reveals the user's position; disabled vs Wraith. Sniper + Smart Rig should feel like cheating — intended. Lore: the rig is too predictable — hence the blade counter.
- **Overclock Rig** (Full Body) — passive: modest move/jump/reload boost. Active ("Overdrive"): amplified boost + blade bullet-deflection, costing **HP drain per second (~4 HP/s) with a grace period**: first ~2 s of an activation are free; deactivating stops drain instantly; the grace period is **all-or-nothing** with a ~10 s reset cooldown after deactivation — reactivating before it resets drains immediately and resets the cooldown to max.
- **Grenades** — free 2/round, **cookable fuse** (up to ~2.5 s hold; 3 s fuse total), bounces physically, Repulse-able in flight. (Cooking deliberately trades away some Repulse-return counterplay for precision — playtest watch item.)

**Weapon damage types (decided 2026-07-16 — for blocking/deflection rules)**
- **direct**: Pistol, SMG, Rifle, Sniper — blockable/deflectable by blade systems.
- **pellet**: Shotgun — not blockable.
- **windup**: Minigun (future) — not blockable.
- **explosive**: Rocket Launcher (future), grenades — not blockable.
- **melee**: blades — blocked by blades (melee plan).
- Katana + Overdrive deflects **direct** fire only: the intended hard counter to Smart Rig users (whose forced center-mass tracking makes them predictable); shotgun/minigun/explosives punch through.

---

## 5. Weapons

Weapons are bought per round and **drop on death** (can be picked up). Most players carry two.

**Proposed Starting Costs & Behaviors**

| Weapon | Approx Cost | Role | Key Behaviors | Counters / Notes |
|--------|-------------|------|---------------|------------------|
| Pistol | Free | Sidearm | Reliable, decent headshots. Resurrected players start with one. | Weak vs Trolls without headshots. |
| SMG | Low | All-rounder | Good close-mid. Easy ammo from corpses. | Inefficient vs hardened Trolls. |
| Rifle | Low | Mid-long | 1x zoom. Strong headshots. | Use Repulse to keep enemies at range. |
| Shotgun | Medium | Close burst | Very high close damage (can delete lighter archetypes). Heavy. | Damage falloff at range. Cannot be blocked by melee. |
| Combat Blade | Medium | Melee | Switches to 3rd-person view. Damage based on archetype strength. Backstabs bleed. Can block other blades. | Overclock Rig makes it terrifying. |
| Minigun | High | Sustained fire | Massive volume. Spin-up time. Very heavy. | Pulse Sight helps pre-aim. Smart Rig helps a lot. |
| Sniper | Very High | Long range | High zoom. Very lethal headshots. | Smart Rig laser gives away position. Use Familiar as rear warning. |
| Rocket Launcher | Extreme | Heavy ordnance | Slow powerful rocket. Long reload. Can destroy bodies. | Smoke/Wraith right after firing for safety. |
| Grenades | Free (2) | Utility | Pushable by Repulse. | — |

**Movement Weight**
- Lighter archetypes (especially Elf) suffer significant speed penalties from Shotgun, Minigun, and Rocket Launcher.
- Troll barely notices them.

**Decided Weapon Roster v1 (2026-07-16, owner decisions)**

| Weapon | Fire behavior | Notes |
|--------|---------------|-------|
| Pistol | Close range, semi-auto | Free sidearm; starts in slot 2 |
| SMG | Close range, full-auto | Spread increases with each shot (bloom) |
| Shotgun | Semi-auto, high spread | Damage scales with pellets that connect |
| Rifle | 3-round burst | Scoped ADS |
| Sniper | Single-shot hitscan | High-zoom scoped ADS |
| Combat Blade (katana-style) | Melee | Third-person view while wielded; blocks blades; backstab imparts bleed |

Minigun and Rocket Launcher deferred to a later content pass.

- **Hit zones:** head / body / limbs. Head takes a per-weapon multiplier (baseline ×2.0), limbs ×0.75. Dwarf headshot immunity = head hits resolve as body damage.
- **Recoil (hybrid per class):** deterministic patterns on Rifle/SMG; seeded random cone for Shotgun pellets; bloom on sustained SMG fire. All randomness via rollback-safe seeded RNG.
- **Ammo:** magazines + finite reserve; reserve refills via buy phase and corpse/drop scavenging (scavenging arrives with the corpse system).
- **Carry:** 2 slots total; pistol starts in slot 2 but is replaceable (two big weapons is a legal buy).
- **TTK target: slow/arena (1.5 s+ sustained at role range)** — long duels, abilities matter mid-fight.
- **Backstab bleed:** single instance, no stacking; re-application refreshes. Bleed ticks do NOT mark combat (the backstab hit does). Bleed HP/s is tuned equal to the Elf auto-heal rate so a bleeding Elf emergently holds health flat while Resonance drains to fuel healing — once drained to the floor, bleed damage lands normally. This equilibrium must emerge from the two systems, never from an explicit override.

---

## 6. Signature Movement Tech & Combos

These are high-priority to implement and tune early.

1. **Repulse Launch (Gust + Glider)**
   - Look straight down → Repulse at ground → immediately deploy Glide Harness.
   - Result: Strong vertical boost followed by slow controlled descent.
   - Can be angled for horizontal boosts.
   - **This should feel amazing and be a core skill expression.**

2. **Repulse + Glide while airborne**
   - Repulse can be used to adjust trajectory or recover.

3. **Wraith + Fall Safety**
   - Phase before big drops.

4. **Slip for verticality**
   - Jump + Slip upward, or double Slip while looking up.

5. **Overclock + Blade**
   - Burst speed into melee range + defensive bullet blocking.

6. **Repulse denial / setup**
   - Push enemies off ledges.
   - Push grenades or Lifebloom nodes.
   - Unzoom snipers.

**Counterplay**
- Repulse while gliding = slam to ground.
- Null Charge vs Slip / active fields.
- Dwarf proximity vs magic users.
- Grenades and rockets vs grouped players near Lifebloom.

---

## 7. Economy & Round Structure

**Inspiration:** Counter-Strike-style buy phase. Winners pull ahead economically. Weapons are lost on death.

**Our Design (MVP)**
- Pre-round buy phase with limited funds.
- Base wage + performance bonuses (kills, objectives, wins).
- Winners get more money → compounding advantage (keeps rounds meaningful).
- Magic/Augments are bought into your loadout for the round.
- Weapons are consumable per life (drop on death).
- Resurrected players come back with basic pistol + their bought abilities (subject to tuning).

**Loadouts — Shopping-List Shortcuts (decided 2026-07-15)**

Loadouts are **ordered shopping lists, not classes or kits**. They never restrict what a player can buy, own, or use, and are not mutually exclusive.

- Ship with default loadouts; players can define, save, and edit their own.
- A loadout = a list of purchasable items (weapons, Manifestations, Augments) in a **player-configured priority order**.
- **Purchase algorithm:** walk the list in priority order; for each item the player does not already own, buy it if affordable. Already-owned items are skipped. Unaffordable items are skipped and the walk continues (open tuning question: skip-and-continue vs stop-at-first-unaffordable — current design is skip-and-continue; validate in playtests).
- Selecting a loadout mid-round or when everything is owned is a safe no-op.
- Pairs with loadout-specific binding config sets (see §11 Ability Slots & Binding).

**Long-term**
- Possible loadout persistence between matches.
- Cosmetic/unlock progression via Steam.

---

## 8. Key Interactions & Counters (The "Rock-Paper" We Want)

| Situation | Strong Against | Weak To | Notes |
|-----------|----------------|---------|-------|
| Heavy Manifestation user | Control & area denial | Dwarf, Null Charges, Repulse | Drains their Resonance economy |
| Wraith user | Most direct fire | Repulse (Resonance damage), Null, good prediction | High risk/reward escape |
| Glide user | Vertical control | Repulse (slam), snipers, Pulse Sight | Signature high-mobility play |
| Troll + Minigun | Frontal pushes | Repulse off ledges, flanking, Dwarf (less Resonance) | Hard to move once hardened |
| Lifebloom node | Sustain for both teams | Dwarf proximity, grenades, Null | Can be used as bait |
| Reclaim | Comeback potential | Body denial (especially with objective weapons) | High drama |
| Overclock + Blade | 1v1 duels | Shotgun at range, good kiting | Very satisfying when it works |

**General Philosophy**
- Almost every powerful tool has a clear, learnable counter.
- Positioning and timing matter more than raw power.
- Information (Pulse Sight, Familiar) is extremely valuable.

---

## 9. Baseline Numbers for Prototyping (Subject to Heavy Tuning)

**Movement (current prototype baseline)**
- Walk: 5.0
- Sprint: 8.0
- Elf light-load bonus: +15–20%
- Heavy weapon penalty (Elf): -30–40%
- Troll heavy weapon penalty: -5–10%

**Health (relative)**
- Human: 100
- Elf: 78 (≈22% less)
- Dwarf: 95
- Troll: 130–140

**Resonance values** — see table in section 2.

**Distances (source reference, tune to Godot scale)**
- Slip: ~8 meters
- Lifebloom heal radius: ~6–8m
- Reclaim radius: ~6m
- Pulse Sight: ~50–60m
- Repulse effective push range: ~10–12m (with falloff)

**Ability Durations (early guesses)**
- Lifebloom: ~3.5–4 minutes or until destroyed / healed enough
- Tangle: 60–90 seconds or until destroyed
- Wraith: until Resonance depleted or cancelled
- Pulse Sight: 4–6 seconds, fast recharge

---

## 10. Implementation Priorities & Notes

**Phase 0 / Early Prototype**
- Resonance resource system + simple reservation
- One Manifestation + one Augment fully working (start with Repulse + Glide Harness)
- Archetype stat differences (speed + health)
- Basic weapon switching + drop on death

**High-Value Combos to Prototype Early**
1. Repulse ground + Glide launch
2. Repulse while gliding (slam)
3. Wraith + Repulse interaction
4. Dwarf draining active effects

**UI / Feel Needs**
- Clear Resonance pip or segmented bar
- Visual feedback for Harden stacks on Troll
- Good sound and VFX for Repulse launches (this should feel *cool*)
- Body persistence + clear "bleeding" state for Reclaim

**Netcode Considerations**
- Repulse is a physics impulse — needs to be authoritative or well-reconciled.
- Glide state and vertical velocity are important.
- Lifebloom and Tangle are persistent world objects that should be networked reliably.

---

## 11. Design Decisions (from team discussion 2026-06-29)

**Resource (Resonance)**
- Reserved/"held" Resonance reduces the player's maximum available pool. Display both current Resonance and reserved amount (e.g. current + reserved visual).

**Ability Slots & Binding**
- No hard slot limit. Any activatable, toggleable, or mappable ability can be bound to any supported key or controller input.
- Full configurability: key binding panel for keyboard + controller, in-game rapid reassignment menu.
- Support loadout-specific binding configurations (config-set system) so players can have different mappings per loadout.

**Economy**
- Strict pre-round buy phase for MVP (and potentially longer). Players purchase weapons and abilities each round with limited funds.

**Loadouts (added 2026-07-15, owner decision)**
- Loadouts are non-restrictive, priority-ordered shopping lists — see §7 for full semantics. Default loadouts ship with the game; players define and save their own, including the purchase priority order used when funds are insufficient.

**Resonance semantics (added 2026-07-16, owner decisions)**
- Float core / pip display; any-combat regen gating; hard block on insufficient; reservations return empty; tech penalty as scaled reservation (H ×1.0, T ×1.25, E ×1.5, D ×2.0); Dwarf drain destroys (no siphon); Elf heal auto-converts gated with a 2-Resonance floor. Full detail in §2.

**Weapons v1 (added 2026-07-16, owner decisions)**
- Roster: Pistol, SMG, Shotgun, Rifle (3-burst, ADS), Sniper (high-zoom ADS), Combat Blade (third-person melee, block, backstab bleed) — see §5 for full behaviors. Head/body/limb zones; hybrid recoil (patterns + seeded cones); mags + finite reserve; 2 slots with replaceable pistol; slow/arena TTK; non-stacking bleed that does not mark combat (Elf equilibrium is emergent).

**Abilities v1 (added 2026-07-16, owner decisions)**
- Framework: Resonance-only pacing (no cooldowns); instant + placement casts; effects die with caster; full 13-ability roster in EA; full friendly fire. Per-ability designs in §4.A.
- **Cybernetic slot system:** Augments occupy body slots (Eye, Full Body, …); shared slots are mutually exclusive; **cybernetics are permanent once purchased for the match**. Smart Rig = Eye + Full Body; Pulse Sight = Eye; Overclock = Full Body.
- **Weapon damage types** (direct / pellet / windup / explosive / melee) govern blocking and deflection — see §4.A.
- New prerequisite systems surfaced: **ping system** (Familiar targeting; also comms), **corpse inventory + looting** (Reclaim's retained-gear rule), damage-type taxonomy (melee + weapon plans).

**Match Config (added 2026-07-16, owner decision)**
- All gameplay tunables (costs, regen rates, archetype stats, timers) are configurable properties injected when the game starts — never hard-coded constants. Goal: private host servers can tune aspects of the game to their taste. Defaults live in a `MatchConfig` registry; hosts override via config file; host→client sync arrives with lobbies.

**Resurrection & Bodies**
- Full body persistence and denial in **all** game modes.
- Corpses remain in the world even after a player respawns.
- Future abilities will interact with corpses (design later).
- Implement a per-player corpse limit to prevent unbounded growth.
- **Corpse dragging (added 2026-07-17, owner decision):** any player can drag a corpse; while dragging, weapon use is limited to **Pistol or SMG**. (The Power Arm idea upgrades this to Rifle/Shotgun — see docs/ideas/power-arm.md.)
- Corpses carry their inventory (weapons/ammo/grenades as at death) and can be looted; Reclaim revives with unlooted gear intact (decided 2026-07-16).

**Dwarf Racial**
- Drain effect is fully passive: always drains nearby enemies and active magic effects by proximity.
- Full immunity to headshots.

**Objective Items (Flag / Artifact)**
- The "flag" will be implemented as a variable item.
- Start by replicating source behavior: powerful melee weapon that disables some abilities while carried.
- Future expansions: different types of flags with varied mechanics for more dynamic play.

**Input & Accessibility**
- Full Steam Input support and good controller schemes from day one.
- Include radial menus, modifier buttons, and robust rebinding.
- Steam Deck and controller support are first-class considerations.

**Controller Support v1 (added 2026-07-16, owner decisions)**
- **Backend:** native Godot InputMap joypad bindings now (works in editor/headless/E2E/non-Steam; Deck plays via Steam's default translation). Steam Input API + action manifest lands in Phase 2; action names follow the Steam-Input-compatible convention from day one (InputMap names = future IGA names).
- **Aim assist:** mild slowdown-on-target, controller only (reticle friction over enemies; no magnetism). PC mouse gets nothing; Smart Rig remains the only hard tracking for anyone. Assist is local input shaping — no netcode surface.
- **Default layout (rebindable):** LS move / LS-click sprint · RS look / RS-click reserved (melee quick) · RT fire · LT ADS/block · RB Repulse · LB reserved (ability radial) · **A jump → glide when airborne (contextual, implemented as a simulation rule; keyboard G unchanged)** · X reload · Y weapon swap · B reserved (interact/loot) · **D-pad Up = ping/comms (G7)**, **D-pad Left = Reclaim (G5 W3)**, **D-pad Right = Familiar (G5 W3)**, rest of D-pad reserved for abilities · Start menu · Select scoreboard. **PC ping = middle-mouse / P; PC Reclaim = H; PC Familiar = N (all rebindable).**
- **Timing:** implemented immediately after the netfox integration plan so all subsequent mechanics get controller-tested as they land.

**Controls rebind menu (added 2026-07-23)**
- In-game **Settings → Controls** (main menu) and **Pause → Settings** (`menu` / Esc / Start).
- **Listen-to-rebind:** select a command → **+ Add** → press key, mouse button, or controller input.
- **Multi-bind:** one command may hold many events (KBM + pad together). Conflict = steal with status toast.
- Local persistence: `user://input_bindings.json` via `InputBindings` autoload. Factory reset restores project defaults. Look feel (mouse sens, invert Y, stick rates, aim-assist mult) is local — not MatchConfig host sync.

**Terminology Notes**
- Archetypes: Human, Elf, Dwarf, Troll (common mythological terms).
- Manifestation names: Repulse, Lifebloom, Reclaim, Tangle, Wraith, Slip, Familiar (and future).
- Augment names: Glide Harness, Pulse Sight, Smart Rig, Null Charge, Overclock Rig (and future).
- Weapons: standard descriptive names.
- All specific mechanics and numbers are original.

---

## 12. References & Sources

This document draws from community documentation of the 2007 game for structural inspiration only:

- Shadowrun 2007 FPS — Shadowrun Wiki (Fandom)
- Shadowrun (2007) — Hardcore Gaming 101
- Various player guides, FAQs, and discussions (2007–present)

All specific names, costs, and numeric targets above are proposals for *CounterSpell* and are original work.

**Related Project Documents**
- [PRD.md](PRD.md) — Vision, roadmap, and high-level scope
- [SETUP.md](SETUP.md) — Development environment
- [ABILITY_TUNING_SHEET.md](ABILITY_TUNING_SHEET.md) — Active scratch pad for numbers, investigations, and refinement before promotion to this document.
- [ideas/](ideas/README.md) — Future-consideration designs (one file per idea), promoted here via the decision process when ready.

---

**Next Steps**
- Update code and future docs to use "Resonance" as the resource name.
- Prototype Resonance resource (with reservation display) + Repulse + Glide Harness combo.
- Design configurable input system supporting flexible bindings and loadout configs early.
- Plan corpse persistence system with per-player limits.
- Create a lightweight GDD or "Ability Kit" doc with exact tuning values.
- Consider Steam Workshop modding implications for binding configs and custom abilities long-term.

---

*Document will evolve rapidly during prototyping. Update version and date on major changes.*