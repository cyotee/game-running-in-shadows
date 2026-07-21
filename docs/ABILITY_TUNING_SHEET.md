# Ability Tuning Sheet

**Project:** CounterSpell  
**Purpose:** Active scratch pad / lab notebook for refining all gameplay numbers, behaviors, interactions, and tuning.  
**Audience:** Core team only during active development.  
**Workflow:**  
- Freely edit, experiment, and add notes here.  
- Record investigations, playtest feedback, "what if" ideas, and concerns.  
- When a value or system feels solid and has been playtested, promote the decision to the official docs:  
  - `MECHANICS_REFERENCE.md` (primary)  
  - `PRD.md` (when it affects vision/scope)  
- Add an entry to the **Promotion Log** below when promoting.

**Important IP Note:** All names, values, and mechanics here are original to *CounterSpell*. Source game references are for structural inspiration only and use generic terms.

**Current Date:** 2026-06-29  
**Status:** Initial version based on MECHANICS_REFERENCE v0.2 decisions.

---

## 1. Core Principles for Tuning

- Resonance is the central tension (magic vs chrome).  
- Archetypes must feel distinct but balanced in the same match.  
- Movement tech (especially Repulse + Glide) should feel powerful and skillful.  
- Clear, learnable counters for every strong tool.  
- Buy phase economy creates comeback potential and round-to-round decisions.  
- Full corpse persistence (with limits) for high-stakes play and future abilities.  
- Configurable bindings from day one (no hard ability slot limits).

---

## 2. Resonance System

**Current Baseline (MECHANICS_REFERENCE)**

| Archetype | Base Max Resonance | Natural Regen Rate | Tech Penalty | Health Baseline | Notes / Open Tuning |
|-----------|--------------------|--------------------|--------------|-----------------|---------------------|
| Human     | 10                 | Low                | None         | 100             | Best for hybrids. Extra starting money. |
| Elf       | 12                 | High (out of combat) | Moderate   | 78              | Fastest movement when lightly loaded. Regen pauses while healing or under fire? |
| Dwarf     | 14                 | Very Low           | High         | 95              | Passive drain. Full headshot immunity (locked decision). |
| Troll     | 8                  | None               | Low          | 130–140         | Harden stacks on damage. Reduced movement when hardened. |

**Tuning Questions & Investigations**
- Exact regen rates (per second or per "tick")? Should Elf regen be completely disabled while taking damage or just slowed?
- How visible is reserved Resonance? (Separate pip count? Darkened bar segment?)
- Can Resonance go negative temporarily (overflow damage from Wraith + Repulse)?
- Should some Augments *increase* Resonance costs instead of (or in addition to) reserving max?
- Resonance display for players: pips vs bar vs both? (Prototype needs this early.)

**Current Proposal for Prototyping**
- Start with the table above.
- Track `current_resonance` and `reserved_resonance`.
- Regen: Human ~0.5/s, Elf ~1.2/s (paused under fire or while healing), Dwarf ~0.2/s, Troll 0.
- [ ] Test these numbers in a simple debug scene.

**Playtest Notes**
- (Add here after first prototype runs)

---

## 3. Archetype Passives & Identity

### Human
- Extra starting buy money: +$500 (or +25%?).
- No Resonance penalty on Augments.
- **Investigation:** How much extra money feels fair without making them strictly best hybrids early?

### Elf
- Movement bonus when not encumbered by heavy weapons.
- Fastest Resonance regen + health regen tied to Resonance when safe.
- **Tuning:** Define "out of combat" / "not under fire" window (e.g. 3–5 seconds no damage taken).
- Heavy weapon speed penalty is severe.

### Dwarf
- Passive Resonance drain on nearby enemies and active Manifestations (Lifebloom, Tangle, Familiar, Wraith?).
- Full headshot immunity (decision locked).
- **Investigation:** Drain radius and rate. Should it affect Wraith form? Should it be stronger vs fields than vs players?
- [ ] Prototype proximity trigger first, then tune values.

### Troll
- Highest health.
- Damage taken builds temporary Harden stacks (damage reduction + movement slow).
- **Tuning:** How many stacks? Duration of each stack? % DR per stack? Speed penalty per stack?
- Least affected by heavy weapons.

**Cross-Archetype Balance**
- Light races (Elf especially) should feel fast with Pistol/SMG/Rifle/Blade but punished hard by Shotgun/Minigun/Rocket.
- Troll should feel tanky but slow to reposition.

---

## 4. Manifestations Tuning

**General Rules (locked for now)**
- Bought in pre-round phase.
- Can be quick-cast or equipped to buttons (no hard slot limit — see bindings decision).
- Some reserve Resonance while active.

### Lifebloom
- **Buy Cost:** $1800 (prototype)
- **Resonance Cost:** 3 held
- **Effect:** Heals all nearby (friend + foe). Limited cover. Withers over time or when healed enough. Two nodes weaken each other.
- **Interactions:** Dwarves drain/destroy. Null Charge destroys. Grenades damage.
- **Tuning Targets:**
  - Heal radius: ~7–8m ?
  - Lifetime: ~3.5–4 minutes (or health pool based)?
  - Heal rate per second?
  - Health pool before withering?
- **Notes:** Strong sustain tool but risky to use offensively. Good for objective defense.
- **Investigations:**
  - [ ] Should it heal the caster faster or the same?
  - [ ] Visual/audio feedback when being drained by Dwarf.

### Reclaim
- **Baselines (in `MatchConfig`, G5 W3 pass 1):** `resonance.reclaim_cost` 4 (held), `reclaim.radius_m` 6, `reclaim.revive_health_frac` 0.5, `reclaim.bleedout_hp_per_s` 8, `reclaim.bleedout_duration_s` 10.
- **Shipped behavior:** corpse-gated radius revive — revives dead allies whose corpse is in range (team-scoped; any-dead in team-less modes), at 50% health with the corpse's *unlooted* weapons/ammo/grenades; consumes the corpse (body denial). 4 Resonance held while any revived ally lives; the caster's death bleeds revived allies out. Key: H / D-pad Left. **Deferred:** VFX, the "reservation scales down when losing" economy tie-in.
- **Buy Cost:** $1800
- **Resonance Cost:** 4 held (scales down when team is losing; min 1)
- **Effect:** Revive allies in radius. If caster dies, revived start bleeding.
- **Key Decision:** Full body persistence across respawns in all modes. Per-player corpse limit.
- **Tuning:**
  - Radius: ~6m
  - Bleed rate on orphaned revived players?
  - Cast time / vulnerability?
- **Notes:** High drama. Bodies are valuable. Future corpse-manipulation abilities planned.
- **Investigations:**
  - [ ] How many corpses per player max before oldest despawns or is denied?
  - [ ] Visual state for "bleeding out" revived players.

### Familiar
- **Baselines (in `MatchConfig`, G5 W3 pass 2):** `resonance.familiar_cost` 4 (held), `familiar.hp` 100, `familiar.move_speed` 7, `familiar.aggro_radius_m` 12, `familiar.melee_range_m` 2, `familiar.melee_damage` 12, `familiar.attack_interval_s` 0.8, `familiar.dwarf_destroy_radius_m` 4, `familiar.follow_offset_m` 2.5, `familiar.guard_range_m` 30.
- **Shipped behavior:** combat minion (one per caster). Aim ground hit within guard range → GUARD there; else FOLLOW. Live enemy-tag ping (`PingService.latest_enemy_tag`) redirects to HUNT. Melee vs enemy players and enemy Familiars. Destroyed by Null fields, nearby Dwarves, gunfire, or caster death. 4 Resonance held while it lives. Key: **N / D-pad Right**. **Deferred:** VFX, ranged Familiars, multi-minion, pathfinding.
- **Buy Cost:** $2500 (ownership gating deferred with other Manifestations)
- **Resonance Cost:** 4 held while the Familiar lives
- **Effect:** Summon / re-task a melee minion (follow, guard point, or hunt ping-tagged enemy).
- **Notes:** Payoff of the G7 ping system. Minions fight each other. Open-arena steering only (no navmesh).
- **Investigations:**
  - [ ] Melee damage / interval feel vs players
  - [ ] Follow offset and aggro radius in arena playtests

### Tangle
- **Buy Cost:** $1800
- **Resonance Cost:** 2 held
- **Effect:** Crystals pull enemies, damage + trap, block gunfire. Grenades/Null pass through.
- **Lifetime:** 60–90s or destructible.
- **Tuning:** Pull strength, damage per second, health of crystals.
- **Notes:** Area denial. Allies impeded but not pulled.

### Repulse (Signature Movement Tool)
- **Buy Cost:** $1600
- **Resonance Cost:** 2
- **Effect:** Directional force blast. Knockback, slight damage, pushes objects/grenades. Passes some geometry?
- **Core Combo:** Look down + Repulse + immediate Glide Harness = strong upward launch + float.
- **Tuning (HIGH PRIORITY):**
  - Impulse strength (vertical vs horizontal).
  - Cooldown.
  - Damage amount (keep low?).
  - Range / falloff.
  - Does it affect Wraith form?
- **Investigations:**
  - [x] Prototype the exact "look down + cast + deploy" timing window. (Implemented - combo if repulse downward within 0.7s window then press Glide)
  - [ ] Feel of slamming gliding players.
  - [ ] Using it to boost horizontal movement or recover from falls.
  - [ ] Counterplay: crouch reduces effect?

**Prototype Implementation Notes (2026-06-29):**
- repulse_strength = 22.0, range=10.0
- Self velocity push on cast + extra down assist when looking down.
- Area push to nearby CharacterBody3D/RigidBody3D.
- Combo gives direct upward velocity = 28.0 + glide state.
- Air control and reduced gravity active while gliding.
- Glide in-flight: fixed set speed (glide_speed = 4.0 scalar) instead of variable air control for more predictable control. 80% of slowest race base walk speed as hardcoded scalar.

### Wraith
- **Buy Cost:** $1700
- **Resonance Cost:** 1 + continuous drain while active
- **Effect:** Phased cloud form. Bullet + fall immunity. Cannot attack or use most other abilities. Harder to see.
- **Counters:** Repulse does heavy Resonance damage (overflow to health). Null drains. Dwarf passive?
- **Tuning:** Drain rate while active. How "hard to see"? EV range reduction.
- **Notes:** High-risk escape / reposition tool.

### Slip
- **Buy Cost:** $2000
- **Resonance Cost:** 3
- **Effect:** ~8m blink in velocity direction. Through solids (fails safely if blocked). Can double upward.
- **Tuning:** Exact distance. Vertical capability when jumping. Cast time or instant?
- **Counters:** Null fields disrupt.

### Familiar
- **Buy Cost:** $2500 (expensive — high commitment)
- **Resonance Cost:** 4 held
- **Effect:** Summon that guards location or hunts target. Minions fight each other. Body denial in some modes.
- **Tuning:** Minion health, damage, lifetime, AI behavior.
- **Notes:** Expensive but powerful for area control or info.

### Ping (G7 — aimed ping, comms)
- **Baselines (in `MatchConfig`):** `ping.duration_s` 4.0, `ping.max_range_m` 120.0, `ping.cooldown_s` 0.5, `ping.per_player_limit` 1.
- **Effect:** one aimed ping — an enemy hit-zone → enemy tag (tracks the live enemy; consumed by Familiar via `PingService.latest_enemy_tag`), anything else → world point. Team-scoped HUD markers; 1 active ping per player (re-ping replaces).
- **Notes:** intel/comms, NOT rollback-simulated (host-authoritative RPC). Comms wheel deferred to a G7 follow-up. Tune duration/range against clutter vs. usefulness in playtests.

**Manifestation Buy Cost Philosophy**
- Most core abilities ~$1600–$2000.
- Summon is premium.
- Keep costs similar so choice is about playstyle, not "this one is cheaper."

---

## 5. Augments Tuning

### Glide Harness
- **Buy Cost:** $1800
- **Resonance:** 2 reserved
- **Effect:** High floaty jumps + no fall damage.
- **Signature Use:** Paired with Repulse for launches.
- **Tuning:** Jump height multiplier, descent speed, air control.
- **Counters:** Repulse while gliding slams to ground. Sniper easy target.

### Pulse Sight
- **Buy Cost:** $1700
- **Resonance:** 3 reserved
- **Effect:** Brief wallhacks on enemies (~50–60m).
- **Tuning:** Duration (4–6s?), recharge time.
- **Notes:** Wraith reduces effectiveness.

### Smart Rig
- **Buy Cost:** $1700
- **Resonance:** 2 reserved
- **Effect:** Passive extra zoom on everything. Active: better tracking + no friendly fire from guns.
- **Tuning:** Zoom levels, aim assist strength (controller vs mouse?).
- **Downsides:** Laser sight reveals position. Disabled vs Wraith.

### Null Charge
- **Buy Cost:** $1400
- **Stock:** Start with 4, slow replenish.
- **Effect:** Sticky anti-field grenade. Destroys Manifestations, drains Resonance, disrupts Slip.
- **Tuning:** Field radius, duration, drain rate.
- **Notes:** Primary caster counter. Affects more than visual glow sometimes.

### Overclock Rig
- **Buy Cost:** $1800
- **Resonance:** Varies (lower penalty on Troll)
- **Effect:** Passive speed/jump/reload. Active: bigger boost + self-damage. Defensive bullet block vs certain attacks when facing.
- **Best With:** Combat Blade.
- **Tuning:** Passive % bonuses, active duration and cost, block chance.

### Grenades (Free)
- Start with 2 per round.
- Dropped on death (usually 1).
- Repulse can redirect them.

---

## 6. Weapons Tuning

Current prototype has basic raycast hitscan. Need real damage, spread, recoil, etc.

**Baseline Targets (to be refined in code)**

| Weapon          | Damage Profile                  | Fire Rate / Spread | Headshot Mult | Movement Penalty (by archetype) | Other Notes |
|-----------------|---------------------------------|--------------------|---------------|----------------------------------|-------------|
| Pistol         | Low, consistent                | Medium             | High          | None                             | Starter weapon |
| SMG            | Medium volume                  | High               | Medium        | Low                              | Good vs most |
| Rifle          | High per shot                  | Low (semi)         | Very High     | Low                              | 2 headshots Elf, 3 Human (source ref) |
| Shotgun        | Very high close                | Low                | Medium        | High on Elf, Low on Troll        | Strong damage falloff |
| Combat Blade   | Strength-based melee           | Fast               | N/A           | None                             | 3rd person, backstab bleed |
| Minigun        | High sustained volume          | Very High (spin-up)| Low           | Severe on Elf                    | Great with Smart Rig |
| Sniper         | Extreme long range             | Very Low           | Extreme       | Medium                           | 1 headshot most (2 vs Dwarf) |
| Rocket Launcher| Massive explosion              | Very Low           | N/A           | Severe                           | Can body destroy. Use Wraith after firing |

**Tuning Investigations**
- Exact damage numbers once we have health values locked.
- Recoil / bloom patterns per weapon.
- Reload times (Overclock helps).
- Ammo economy / drop on death.
- [ ] Implement proper hitscan + projectile options.

---

## 7. Signature Combos & Interactions

**Priority 1: Repulse + Glide Launch**
- Must feel excellent and be the "cool moment" players remember.
- Test timing window, vertical power, horizontal options, recovery.

**Other Key Interactions**
- Repulse vs Wraith (heavy Resonance damage).
- Repulse vs gliding players (slam).
- Dwarf passive vs all Manifestations.
- Null Charge vs Slip / active fields / Wraith.
- Overclock + Blade dueling.
- Smart Rig + Minigun / Rifle.
- Wraith + big fall safety or rocket self-damage avoidance.

**Tuning Log**
- (Record specific test results here, e.g. "With impulse 1200 vertical, launch felt too floaty. Reduced to 950. Better.")

---

## 8. Economy & Buy Phase

**Locked for MVP:** Strict round-based buy phase like source.
- Base wage + win/objective/kill bonuses.
- Winners get more money (compounding but comebacks possible).
- Weapons drop on death.
- Abilities are "equipped" for the round.

**Tuning**
- Starting money per archetype (Human higher).
- Round wage amounts.
- Cost of each item (see tables above — adjust freely here first).
- [ ] How much money should a losing team still get to stay in the game?

---

## 9. Investigations & Playtest Tracker

**Steam sessions — pending owner verification (2026-07-19)**
- Plan 6 is code-complete: GodotSteam 4.20.1 boots, `SteamMultiplayerPeer` class present, session state machine + lobby browser tested with fakes, three-peer ENet E2E green.
- **PENDING (owner, needs Steam client + second machine/account):** Host (Public) → lobby appears in browser with correct n/16 → Join → both load match_session over Steam relay → movement + Repulse/Glide replicate; third account joins mid-session → spectator camera → host presses F9 → body spawns. Record latency feel + drops here.

**Milestone A exit check (2026-07-18 — automated half)**
- Two-instance NetworkSimulator E2E (`tests/e2e/net_smoke.py`) PASSES at 50 ms, 100 ms, and 150 ms injected latency: client movement, jump/glide (press-tick inputs), and state replication all verified host-side. Full GdUnit suite: 63 tests green.
- All five Milestone A plans executed (netfox core, controller support, Resonance, weapons, blade).
- **PENDING (owner):** the subjective PRD §11 gate — play the client instance at ≥100 ms (`NET_TEST_LATENCY_MS=100`, two windowed instances of `scenes/dev/net_test.tscn`) and judge whether Repulse+Glide, weapon fire, and blade duels *feel* responsive. Record the verdict here.

**Abilities Wave 2 shipped (2026-07-20)**
- Lifebloom: 3 held Resonance, 6 HP/s heal, 7 m radius, 100 HP, 3 min wither; heals friend or foe regardless of combat; reservation releases empty on death. Placed at aimed point (max range 30 m).
- Tangle: 2 held, 4 m radius, 4 m/s inward conveyor pull (min-inward-speed, not accel — decay swamps accel), 120 HP, 75 s; caster exempt (team-ally exemption deferred); blocks direct fire (layer-5 block body); grenades/Null pass through.
- Null Charge: stock 4/round, 5 m radius, 10 s, 1 Resonance/s drain on enemies, destroys Manifestation fields inside, suppresses Manifestation casting within (Repulse/Slip/Wraith/Lifebloom/Tangle); 60 HP. Watch: null stock vs caster economy; suppression radius feel.

**Abilities Wave 1 shipped (2026-07-20)**
- Slip: 3 Resonance, 8 m blink (velocity dir when moving, aim dir when stationary); destination-clear check (world layer 1 sphere) refunds+fizzles on block. Passes through walls if landing is clear.
- Wraith: toggle 1 Resonance + 1.5/s drain; forced out on empty. Walk-speed only, glide/cast/weapon locked, bullet+fall immune (`take_damage` early-returns while phased). Net drain ~1.15/s vs out-of-combat regen. Watch: drain rate vs escape value; the Repulse resonance-burn counter is not yet implemented.
- Grenades: free 2/round, 3 s fuse, cook up to 2.5 s (min fuse 0.5 s), 70 dmg / 5 m radius (full inside 1.5 m, linear falloff), throw speed 18. Rollback-simulated ballistic projectile with raycast bounce (0.5 dampen); Repulse-able (nudges "grenades" group). Watch: bounce dampen feel, cook-vs-Repulse-return tradeoff.

**Weapon implementation notes (2026-07-18)**
- SMG bloom now decays only after sustained fire stops: at the recorded baselines (0.15°/shot at 12.5 shots/s vs 3°/s decay) continuous-decay bloom could never accumulate. Behavior: grows while firing, decays at 3°/s once fire stops.
- Player bodies moved to collision layer 4 (world 1, hit zones 2) so weapon rays resolve zones instead of the body shell; capsule offset so feet sit at node origin (camera 1.6 is inside the 1.8 m body).
- View-kick recoil patterns deferred per the weapon plan's scope note (dispersion half shipped).

**Netfox rebuild behavior note (2026-07-17)**
- Glide now cancels on floor contact **only while descending** (`velocity.y <= 0.01`), so a ground-level Repulse + Glide combo keeps glide active through the upward launch. This is a deliberate change from the pre-netfox prototype, where a grounded launch silently dropped glide. Validate feel in playtests.

**High Priority Tests**
- [ ] Resonance resource + reservation UI in prototype.
- [ ] Repulse ground + Glide launch timing and power.
- [ ] Dwarf passive drain feel and counterplay.
- [ ] Full corpse persistence + Reclaim in a deathmatch test.
- [ ] Movement speed differences between archetypes with light vs heavy weapons.
- [ ] Wraith + Repulse interaction damage.
- [ ] Controller binding experience (radial? modifiers?).

**Medium Priority**
- Weapon damage balance once health numbers are set.
- Lifebloom sustain vs denial.
- Null Charge effectiveness vs Slip.
- Overclock + Blade vs ranged.

**Future / Nice to Have**
- Different flag types (variable objective items).
- Corpse-manipulation Manifestations.
- More archetypes.

---

## 10. Promotion Log

Record stable decisions that have been moved out of this sheet.

**2026-06-29 (Initial)**
- Created this sheet.
- Pulled baselines from MECHANICS_REFERENCE v0.2.
- Locked: Resonance name + reservation mechanic, Human/Elf/Dwarf/Troll, full body persistence with limits, configurable bindings, strict buy phase, passive Dwarf + headshot immunity, variable flags, Steam Input priority.

**Next Promotion Candidates**
- (Add date + what was promoted when values stabilize)

---

## 11. Misc Notes & Scratch Area

**Resonance baselines (2026-07-16 — provisional numbers for the decided semantics; tune after implementation)**

| Tunable | Human | Elf | Dwarf | Troll |
|---------|-------|-----|-------|-------|
| Max Resonance | 10 | 12 | 14 | 8 |
| Regen (per s, out of combat) | 0.35 | 0.8 | 0.15 | 0 |
| Tech multiplier (reservation scaling) | 1.0 | 1.5 | 2.0 | 1.25 |
| Max health | 100 | 78 | 95 | 135 |

- Combat timeout (any-combat gating): 4.0 s
- Repulse cost: 2 · Glide Harness base reservation: 2 (so Elf pays 3, Dwarf 4 for the harness)
- Dwarf drain aura: 6 m radius, 0.5/s per enemy (destroy-only)
- Elf auto-heal: 0.5 Resonance/s → 8 HP per Resonance, floor 2, out-of-combat only
- Placeholder hitscan damage: 10 (needed to exercise the combat timer)
- ALL of the above are MatchConfig tunables, host-overridable — never bake into code as constants.
- Watch during playtests: combo (Repulse 2 + reserved harness) economics per archetype; whether Dwarf ×2.0 tech mult makes Augments unplayable on Dwarf (may be intended).

**Default loadout candidates & feel targets (2026-07-16, owner examples — names provisional, review later)**

These four express how ability combinations should FEEL. Use them as tuning north stars and default-loadout label candidates.

| Name | Contents | Fantasy (owner's words) |
|------|----------|------------------------|
| **Ninja** | Repulse, Slip, Wraith, Glide Harness, Overclock, Katana, SMG | "Rapid hit and run. Run towards enemy, teleport behind them, backstab, flee. Be the assassin." |
| **Anchor** | Lifebloom, Reclaim, Pulse Sight, Shotgun, Minigun | "Hold ground, team rallies around you. Save the day with Reclaim." |
| **Solo** | Tangle, Familiar, Null Charge, Grenades, Minigun | "One man army. Tie down the whole enemy team or flank them all by yourself." |
| **Sniper** | Sniper Rifle, Slip, Smart Rig, Repulse, Glide Harness | "Hidden killer. Hide in impossible to reach places. Reach out and kill anyone. Escape to do it again." |

**System checks (2026-07-16):**
- All four are slot-legal: Ninja (Overclock = Full Body only), Anchor (Pulse Sight = Eye), Sniper (Smart Rig = Eye + Full Body, no conflicts). Ninja and Anchor forgo the pistol for two weapons (legal); Solo keeps the free pistol beside the Minigun.
- Ninja validates three decisions working together: Wraith's instant rematerialize (infiltrate → backstab), Katana+Overdrive deflect, and the movement-combo economy. On an Elf: 4 base reservation ×1.5 = 6 of 12 locked — tight pool is the intended tension.
- **Anchor full-lock math:** Lifebloom (3 held) + Reclaim (4 held) + Pulse Sight (3 × tech mult) = 10 on a Human — the ENTIRE pool locked while both effects are up, zero castable, and (per empty-return) a devastating reset if effects die. Dramatic and maybe intended ("commit everything"); Troll (8 max) literally cannot run this loadout fully. Review when tuning.
- **Minigun dependency:** two of four loadout concepts (Anchor, Solo) are built around the Minigun, which the v1 weapon roster DEFERRED. Consider promoting Minigun into the EA roster earlier than planned — flag for owner review.
- Sniper + Smart Rig = the decided "should feel like cheating" pairing; note Smart Rig's forced center-mass view means the Sniper loadout plays for 2-shot body kills while active, not headshots — consistent with the decided trade-off.
- Familiar (Solo) requires the ping system; Wraith/Slip/Tangle per §4.A designs.

**Controller input baselines (2026-07-16 — ALL MatchConfig tunables)**
- Stick deadzone: 0.15 (inner), 0.98 (outer) · look response curve exponent: 2.0
- Max look rate: 240°/s yaw, 180°/s pitch (at full deflection, hip); ADS scales by 1/zoom
- Slowdown-on-target (controller only): sensitivity ×0.6 while reticle is over an enemy within 40 m; ×1.0 otherwise; no effect on mouse
- Contextual A-button: jump on floor · deploy glide when airborne · glide boost while gliding

**Ability baselines (2026-07-16 — provisional numbers for §4.A decisions; ALL MatchConfig tunables)**

| Ability | Key numbers (baseline) |
|---------|------------------------|
| Slip | 8 m blink, cost 3, refund on fail |
| Wraith | cost 1 + 1.5/s drain; walk speed; instant rematerialize |
| Lifebloom | 6 HP/s aura, 7 m, node 80 HP, 3 min wither, cost 3 held |
| Tangle | 4 m vortex, ~2.5 m/s pull, 6 HP/s DoT inside, 60–90 s or destroyed, cost 2 held |
| Reclaim | 6 m radius, revive at 50% HP + gear-as-died (unless looted), 4 held |
| Familiar | ping-hunt; 60 HP minion; melee ~12 dmg/s, cost 4 held |
| Null Charge | 5 m field, 10 s, 1/s enemy drain, casting suppressed inside, 40 HP, 2 stock |
| Pulse Sight | 5 s reveal, ~50 m, 3 reserved; shared with allied Eye-chrome owners |
| Smart Rig | view-drag strength: full track within ~20°/s turn budget; laser visible ~40 m; 2 reserved |
| Overclock | Overdrive: +25% move/jump, +40% reload, 4 HP/s after 2 s grace; grace reset 10 s (all-or-nothing); 2 reserved |
| Grenades | 3 s fuse, cookable ≤2.5 s, 70 dmg center with falloff, free ×2 |

- Watch: Smart Rig forced-view feel (players hate losing camera control — the point here, but validate the strength curve); cooked grenades vs Repulse-return; Wraith instant-strike assassinations (no exit delay is intentional); Tangle vortex vs prediction feel.

**Weapon baselines (2026-07-16 — provisional, slow/arena TTK vs 100 HP; ALL MatchConfig tunables)**

| Weapon | Body dmg | Head mult | Fire interval | Mag / Reserve | Weight class | Notes |
|--------|----------|-----------|---------------|---------------|--------------|-------|
| Pistol | 12 | ×2.0 | 0.35 s | 12 / 36 | light | Free sidearm |
| SMG | 7 | ×1.5 | 0.08 s | 30 / 90 | light | Bloom: +0.15° per shot, decays 3°/s |
| Shotgun | 6 × 8 pellets | ×1.5 | 0.9 s | 6 / 24 | medium | Cone 5°; per-pellet falloff |
| Rifle | 11 | ×2.0 | burst: 0.1 s intra, 0.5 s between | 24 / 72 | medium | 3-round burst; ADS 1.6× zoom |
| Sniper | 55 | ×2.0 | 1.4 s | 5 / 15 | heavy | ADS 4× zoom; head kills ≤110 HP (Troll survives) |
| Combat Blade | 25 swing / 40 backstab | n/a | 0.6 s | — | light | Backstab bleed: 4 HP/s × 8 s (= Elf heal rate 0.5 res/s × 8 HP) |

- Limb multiplier: ×0.75 (all weapons). Dwarf: head hits resolve as body.
- Movement weight speed multipliers: light ×1.0 all; medium — Elf ×0.85, others ×0.95, Troll ×1.0; heavy — Elf ×0.65, Human/Dwarf ×0.85, Troll ×0.93.
- Bleed does NOT mark combat; backstab hit does. Elf equilibrium: bleed 4 HP/s == Elf heal 4 HP/s → health flat, Resonance drains ~0.5/s until floor (2), then damage lands. Duration 8 s > combat timeout 4 s so the equilibrium window is visible.
- Watch: slow TTK + Troll 135 HP + heavy-weapon immunity may need Troll-specific tuning; sniper head vs Troll intentionally non-lethal.

- Current FPS prototype movement: walk 5.0, sprint 8.0 (scripts/player/fps_controller.gd).
- Need to add proper weapon system before serious damage tuning.
- Long-term: Make as much data-driven as reasonable for Workshop mod support.
- Music motif for Resonance: consider audio cues that feel "harmonic" or "dissonant" when Resonance is low/high.

---

*This document is intentionally less polished than the reference docs. Edit aggressively. Delete or archive old notes as needed.*