# CounterSpell Asset Inventory

**Branch:** `feat/asset-pipeline-inventory`  
**Date:** 2026-07-27  
**Purpose:** Map every gameplay need (races, equipment, abilities, FX, animation, UI, maps, audio) to the **type of asset** we must find, kitbash, generate, or commission.  
**Sources:** `docs/MECHANICS_REFERENCE.md`, `docs/PRD.md`, `docs/ABILITY_TUNING_SHEET.md`, `scripts/config/match_config.gd`, `models/placeholders/`, ability/weapon scenes under `scenes/`.

**Strategy (agreed):** Production look is **cell-shaded stylized 3D** (PRD §1). Canonical ref: `docs/assets/references/style/human_male_runner_tpose_front.png`. Prefer **edit / kitbash existing low-poly CC0 models** toward that lock; use **Grok Imagine / Meshy** for concept boards, textures, decals, icons, and generated meshes. Full custom Blender models only for hero gaps.

**IP rule:** No Shadowrun trademarks or protected terms in assets or filenames. Use **Resonance**, **Runners**, **the Grid**, **Manifestations**, **Augments**, **Repulse**, **Glide**.

---

## Legend

### Asset types (what to find / make)

| Code | Asset type | Typical delivery |
|------|------------|------------------|
| `CHAR_MESH` | Character body mesh (rigged humanoid) | `.glb` + armature, T/A-pose |
| `CHAR_SKIN` | Texture / material set for a body | Albedo (+ optional ORM/emissive) |
| `VIEWMODEL` | First-person arms + weapon mesh | Low-poly `.glb`, grip origin |
| `WORLD_WEAPON` | Third-person / drop weapon mesh | `.glb`, readable silhouette |
| `PROP` | Placed world object / device | `.glb` (static or simple anim) |
| `SUMMON` | AI / minion character mesh | Rigged `.glb` or simple animated |
| `CORPSE` | Dead body / ragdoll or posed dead mesh | Often same as CHAR with death pose |
| `ENV` | Level piece / modular kit | Kit meshes, collision-friendly |
| `VFX_MESH` | Mesh used only for effects | Rings, wings, crystals, clouds |
| `VFX_PART` | Particle / trail / shader effect | Godot GPUParticles / shader |
| `ANIM` | Skeletal animation clip set | NLA / AnimationPlayer clips |
| `ICON` | 2D UI icon | PNG / SVG, square |
| `UI_FRAME` | HUD / menu chrome | Panels, bars, fonts, buttons |
| `SFX` | Sound effect | WAV / OGG |
| `MUSIC` | Music bed / stinger | OGG |
| `CONCEPT` | Art-direction image (not in engine) | PNG concept sheet |

### Acquisition channels (how we get it)

| Channel | Meaning |
|---------|---------|
| **Kitbash** | Edit / retexture / combine existing `models/placeholders/` Quaternius CC0 |
| **Find** | Source additional CC0 / free commercial-OK pack (same low-poly language preferred) |
| **Imagine** | Grok Imagine: concept, texture, icon, marketing |
| **Blender** | Author or heavily remodel in Blender → `.glb` |
| **Godot** | Built in-engine (materials, particles, CSG, procedural) |
| **Commission** | Hire artist later (EA polish) |

### Priority

| P | Meaning |
|---|--------|
| **P0** | Blocks readable playtests / EA core fantasy |
| **P1** | Full EA roster (v0.2 abilities + weapons + 4 lineages) |
| **P2** | Polish, deferred weapons, cosmetics, Phase 2+ |
| **P3** | Post-MVP / Phase 3 (PvE, Grid, extra archetypes) |

### Status vs repo today

| Status | Meaning |
|--------|---------|
| **Placeholder** | Exists under `models/placeholders/` (usable stand-in) |
| **Gap** | Needed; no good stand-in |
| **Code-only** | Logic exists; visuals are debug/primitive |
| **Deferred** | Designed, not shipping in first art pass |
| **N/A** | Pure systems / no dedicated art |

---

## 1. Style baseline (lock first)

| Need | Asset types | Channel | Priority | Notes |
|------|-------------|---------|----------|-------|
| Game art bible (cyber + magic hybrid, cell-shaded readable FPS) | `CONCEPT` × 8–12 | Imagine / Meshy | P0 | Locked look: `docs/assets/references/style/human_male_runner_tpose_front.png`. Expand to other lineages from this board |
| Palette + material language | `CONCEPT` + sample `CHAR_SKIN` | Imagine → apply in Blender / Meshy | P0 | Charcoal kit, muted teal trim, small chrome; organic crystal / Resonance glow as VFX, not baked mesh |
| Silhouette language (hard color regions, inked edges) | Cell-shaded lock + Quaternius prototypes | Kitbash keepers toward the lock | P0 | Light tactical kit; skip bulky webbing, backpacks, toon shooter kit, photoreal PBR |
| Logo / wordmark **CounterSpell** | `ICON` / `UI_FRAME` | Imagine | P1 | Menus + Steam page |

---

## 2. Lineages (races) — character bodies

Core EA lineages: **Human, Elf, Dwarf, Troll**. Each needs male + female presentation for production polish; playtests can ship with fewer variants.

| Game need | Fantasy / scale | Asset types | Placeholder today | Gap | Channel | Priority |
|-----------|-----------------|-------------|-------------------|-----|---------|----------|
| **Human** male | Baseline ~1.7–1.9 m professional runner | `CHAR_MESH`, `CHAR_SKIN`, `ANIM` | Strong: modular men (Punk, Worker, SWAT, Casual…) | Low | Kitbash + Imagine skins | P0 |
| **Human** female | Same | `CHAR_MESH`, `CHAR_SKIN`, `ANIM` | Strong: modular women (Soldier, Suit, SciFi, Worker) | Low | Kitbash + Imagine skins | P0 |
| **Elf** male | Tall, light, ethereal caster/flanker | `CHAR_MESH`, `CHAR_SKIN`, `ANIM` | Good: `races/elf/male/Elf.fbx` + wizard stand-ins | Medium (stylize to cyber-elf) | Kitbash + retexture | P0 |
| **Elf** female | Same | `CHAR_MESH`, `CHAR_SKIN`, `ANIM` | Weak: witch stand-ins only | **High** | Find / Blender / scale-recolor male Elf | P0 |
| **Dwarf** male | Short, dense, null-field anti-mage | `CHAR_MESH`, `CHAR_SKIN`, `ANIM` | Weak: short-scaled humans | **High** | Find true dwarf mesh or Blender | P0 |
| **Dwarf** female | Same | `CHAR_MESH`, `CHAR_SKIN`, `ANIM` | Weak stand-ins | **High** | Find / Blender | P1 |
| **Troll** male | Large fortress (~2.2–2.5 m), bulk tank | `CHAR_MESH`, `CHAR_SKIN`, `ANIM` | OK proxies: Giant, Yeti, Demon (read “monster” not metahuman) | Medium (need humanoid troll) | Kitbash bulk + retexture / Find | P0 |
| **Troll** female | Same bulk language | `CHAR_MESH`, `CHAR_SKIN`, `ANIM` | Empty | **High** | Find / Blender | P1 |
| Hit zones (head / torso / limbs) | Gameplay collision, not beauty | Collision shapes + optional zone meshes | Capsules in code | N/A art | Godot | P0 |
| Team / enemy readability | Outline, color band, or armband | `CHAR_SKIN` variant or decal | None | Medium | Imagine decals + material overrides | P0 |
| Future: Decker / Rigger / Shaman / Street Sam | Post-MVP archetypes | `CHAR_MESH` + gear | None | — | Deferred | P3 |

**Orc / Goblin** in placeholders are **not** player lineages; keep as ref or enemy stand-ins only.

### Per-lineage visual extras

| Need | Asset types | Channel | Priority |
|------|-------------|---------|----------|
| Elf Resonance heal (out of combat) | `VFX_PART` soft green/teal regen | Godot + Imagine ref | P1 |
| Dwarf passive drain aura | `VFX_PART` / radius distortion | Godot (debug disc exists) | P1 |
| Troll Harden stacks | `VFX_MESH` shell / stone-chrome plates or shader | Godot / small mesh | P1 |
| Human “hybrid” chrome accents | Augment socket props on body | Kitbash small props | P2 |

---

## 3. Player presentation (FPS + third person)

| Need | Asset types | Placeholder | Channel | Priority |
|------|-------------|-------------|---------|----------|
| **Third-person body** (others + blade cam + corpses) | `CHAR_MESH` + `ANIM` | Modular characters | Kitbash | P0 |
| **First-person arms** (shared or per race scale) | `VIEWMODEL` arms | None dedicated | Kitbash arms / Blender | P0 |
| **FP weapon models** per gun | `VIEWMODEL` | Sci-fi / ultimate gun packs | Kitbash | P0 |
| **TP weapon models** (holstered / held / dropped) | `WORLD_WEAPON` | Same packs | Kitbash | P0 |
| Blade third-person camera framing | SpringArm (code) + body mesh | Code exists | Godot + CHAR | P0 |
| Glide wings on body | `VFX_MESH` deployable wings / harness | None | Blender kitbash + VFX | P0 |
| Wraith form (phased cloud) | `VFX_PART` + optional ghost mesh | Code-only | Godot + Imagine ref | P0 |
| Death pose / corpse | `CORPSE` or death `ANIM` | Primitive corpse scene | Kitbash death pose from CHAR | P0 |
| Dragging corpse pose | `ANIM` drag / hold | None | Anim kitbash | P1 |

---

## 4. Weapons

### 4.1 v1 roster (implemented / EA)

| Weapon | Role | Asset types | Placeholder candidates | Channel | Priority | Status |
|--------|------|-------------|------------------------|---------|----------|--------|
| **Pistol** | Free sidearm | `VIEWMODEL`, `WORLD_WEAPON`, `ICON`, fire/reload `SFX` | `scifi_modular_guns/Scifi_Pistol*`, `ultimate_guns*/Pistol` | Kitbash | P0 | Code-only mesh |
| **SMG** | Close full-auto | Same + shell/muzzle FX | `Scifi_Smg`, `SMG.glb` | Kitbash | P0 | Code-only mesh |
| **Shotgun** | Close pellet burst | Same | `ultimate_guns*/Shotgun*` | Kitbash | P0 | Code-only mesh |
| **Rifle** | 3-burst ADS | Same | `Scifi_AR*`, `Assault_Rifle*` | Kitbash | P0 | Code-only mesh |
| **Sniper** | High-zoom hitscan | Same + scope glass | `Scifi_Sniper*`, `Sniper_Rifle*` | Kitbash | P0 | Code-only mesh |
| **Combat Blade** (katana-style) | Melee, block, backstab bleed | `VIEWMODEL` or hand mesh, `WORLD_WEAPON`, swing `ANIM`/`SFX`, block spark `VFX_PART` | RPG knife/scythe weak; **need katana** | **Find / Blender** | P0 | Code; no proper mesh |

### 4.2 Deferred weapons (design exists)

| Weapon | Asset types | Placeholder hints | Channel | Priority |
|--------|-------------|-------------------|---------|----------|
| **Minigun** | Heavy `VIEWMODEL`/`WORLD_WEAPON`, spin barrel `ANIM`, windup `SFX` | None strong in pack | Find / Blender | P2 (loadouts Anchor/Solo want it — review early promote) |
| **Rocket Launcher** | Launcher mesh, rocket `PROP`, explosion `VFX_PART`/`SFX` | Grenade launcher adjacent only | Find / Blender | P2 |

### 4.3 Shared weapon FX / audio

| Need | Asset types | Channel | Priority |
|------|-------------|---------|----------|
| Muzzle flash per class | `VFX_PART` / sprite | Godot + Imagine sprites | P0 |
| Tracer / hitscan streak | `VFX_PART` | Godot (playtest tracers exist) | P1 |
| Bullet impact (world / flesh) | `VFX_PART` + `SFX` | Godot + SFX pack | P1 |
| Shell casings (optional) | Tiny `PROP` + physics | Kitbash optional | P2 |
| Reload / dry fire / equip | `SFX` | Find SFX pack | P0 |
| ADS reticle / scope overlay | `UI_FRAME` | Imagine / Godot | P1 |
| Smart Rig laser sight | `VFX_PART` line | Godot | P1 |
| Bleed tick (blade) | `VFX_PART` + optional `SFX` | Godot | P1 |
| Weapon pickup / drop | World mesh + `SFX` | Same WORLD_WEAPON | P1 |

---

## 5. Equipment & throwables

| Item | Game role | Asset types | Placeholder | Channel | Priority | Status |
|------|-----------|-------------|-------------|---------|----------|--------|
| **Grenades** (2/round, cookable) | Frag, Repulse-able | `PROP` projectile, pin/cook UI, explosion `VFX_PART`/`SFX` | `Scifi_Grenade.glb` | Kitbash | P0 | Code + scene; art upgrade |
| **Null Charge** | Sticky anti-Manifestation field | Throwable `PROP`, field `VFX_PART`/`VFX_MESH`, stick `SFX` | Cyber lootbox / device-ish | Kitbash + Godot VFX | P0 | Code-only look |
| **Glide Harness** (equipment, no body slot) | Wings / harness | Body attach `VFX_MESH`, deploy `ANIM`/`SFX` | None | Blender + Imagine | P0 | Code-only |
| Weapon drops on death | Loot readability | `WORLD_WEAPON` + glow | Guns above | Kitbash | P1 | — |
| Ammo / reserve (if world pickups later) | Scavenge | Small `PROP` packs | None | Kitbash | P2 | — |

---

## 6. Manifestations (awakened powers)

| Ability | Visual fantasy | Asset types | Placeholder hints | Channel | Priority | Status |
|---------|----------------|-------------|-------------------|---------|----------|--------|
| **Repulse** | Directional force blast | Cast `VFX_PART`, ground ring `VFX_MESH`, knock `SFX` | None | Godot + Imagine | **P0** (signature) | Code-only |
| **Slip** | Short blink | Departure/arrival `VFX_PART`, fizzle `SFX` | None | Godot | P0 | Code-only |
| **Wraith** | Phased cloud form | Body dissolve `VFX_PART`, silhouette ghost, enter/exit `SFX` | None | Godot + Imagine | P0 | Code-only |
| **Lifebloom** | Heal node + aura | Planted `PROP` crystal/flower, heal aura `VFX_PART`, wither state, shootable HP | `props/magic` crystals | Kitbash crystals + Godot | P0 | Field scene; deferred VFX |
| **Tangle** | Crystal/razor growth vortex | Field `PROP`/`VFX_MESH`, pull tendrils `VFX_PART`, block solid | Crystal clusters | Kitbash + Blender | P0 | Field scene; deferred VFX |
| **Reclaim** | Radius revive | Revive burst `VFX_PART`, corpse consume FX, cast `SFX` | None | Godot | P1 | Code; deferred VFX |
| **Familiar** | Combat minion | `SUMMON` mesh + `ANIM` (idle/run/attack), death FX | Critters / robot / spirit-like | Kitbash (robot/critter) or Blender spirit | P1 | Code minion; deferred art |

### Manifestation shared

| Need | Asset types | Channel | Priority |
|------|-------------|---------|----------|
| Cast denial (insufficient Resonance) | HUD flash + `SFX` | Godot + Imagine | P0 |
| Reservation “locked pips” | `UI_FRAME` Resonance bar states | Imagine + Godot | P0 |
| Field destroyed by Dwarf / Null | Dissolve `VFX_PART` + `SFX` | Godot | P1 |
| Lifebloom mutual wither (two nodes) | Visual wilting state on `PROP` | Material / mesh swap | P2 |

---

## 7. Augments (chrome / tech)

| Augment | Visual fantasy | Asset types | Channel | Priority | Status |
|---------|----------------|-------------|---------|----------|--------|
| **Glide Harness** | Wearable wings/rig | See §5 | Blender | P0 | — |
| **Pulse Sight** | Wall-hack pulse | Full-screen / edge `UI_FRAME` + world silhouettes, ping `SFX` | Godot + Imagine | P1 | Code intel; deferred art |
| **Smart Rig** | Aim assist chrome | Eye implant mesh (optional TP), laser, HUD wedge, track `SFX` | Godot + small PROP | P1 | Playtest wedge exists |
| **Null Charge** | Device | See §5 | Kitbash | P0 | — |
| **Overclock Rig** | Full-body boost | Chrome veins `VFX_PART`, speed trails, Overdrive `SFX`, blade deflect sparks | Godot | P1 | Code; deferred art |
| Cyber slot exclusivity (Eye / Full Body) | Buy UI feedback only | `ICON` / `UI_FRAME` | Imagine | P1 | Debug buy menu |

---

## 8. World entities & match objects

| Need | Asset types | Placeholder | Channel | Priority |
|------|-------------|-------------|---------|----------|
| **Corpse** (loot + drag + Reclaim) | `CORPSE` / death pose, loot prompt UI, drag link visual | Primitive scene | Kitbash from CHAR | P0 |
| **CTF objective / variable “flag”** | Distinct `PROP` (not a literal sports flag if fantasy device preferred) | None strong | Blender / Kitbash device | P1 |
| Flag drop / return / capture | `VFX_PART` + `SFX` + HUD | — | Godot | P1 |
| Spawn points / buy zone markers | Simple `PROP` / decal | Env kit | Kitbash | P1 |
| Cover / interactables (doors, consoles) | `ENV` props | `cyberpunk_game_kit` (AC, door, computer, streetlight…) | Kitbash | P1 |
| Destructible fields only (fields have HP) | Damage states on field props | — | Material variants | P2 |

---

## 9. Animations (clips)

Shared humanoid set should retarget across lineages where skeleton allows; Troll/Dwarf may need retarget scale or dedicated clips.

### 9.1 Locomotion (third person)

| Clip | Asset type | Priority | Notes |
|------|------------|----------|-------|
| Idle | `ANIM` | P0 | Armed / unarmed variants later |
| Walk / run / sprint | `ANIM` | P0 | Weight classes (light vs heavy weapon) optional P2 |
| Jump / fall / land | `ANIM` | P0 | |
| Crouch (if added) | `ANIM` | P2 | PRD notes crouch pending |
| Glide loop (air) | `ANIM` | P0 | Wings pose |
| Wraith float / drift | `ANIM` or pure VFX | P0 | May be shader-only |
| Death / ragdoll or death pose | `ANIM` | P0 | Corpse system |
| Drag corpse walk | `ANIM` | P1 | |
| Revive get-up (Reclaim) | `ANIM` | P1 | |

### 9.2 Combat (third person)

| Clip | Asset type | Priority |
|------|------------|----------|
| Fire rifle/SMG/pistol/shotgun/sniper (TP) | `ANIM` | P1 |
| Reload (TP) | `ANIM` | P1 |
| Blade draw / sheath | `ANIM` | P0 |
| Blade swing (one or two attacks) | `ANIM` | P0 |
| Blade block hold | `ANIM` | P0 |
| Blade backstab | `ANIM` | P1 |
| Hit react / flinch | `ANIM` | P2 |
| Overclock sprint pose | `ANIM` | P2 |

### 9.3 First person

| Clip | Asset type | Priority |
|------|------------|----------|
| FP idle / walk bob (per weapon or shared) | `ANIM` or code bob | P0 |
| FP fire | `ANIM` | P0 |
| FP reload | `ANIM` | P0 |
| FP equip / holster | `ANIM` | P1 |
| FP blade (if any arms in FP) or camera-only | — | P0 (blade is TP) |

### 9.4 Summons / props

| Clip | Asset type | Priority |
|------|------------|----------|
| Familiar idle / move / melee | `ANIM` | P1 |
| Lifebloom grow / wither | `ANIM` or shader | P2 |
| Tangle open / pulse | `ANIM` or shader | P2 |
| Glide wings deploy / fold | `ANIM` | P0 |
| Null Charge arm / stick | `ANIM` optional | P2 |
| Grenade pin / throw (FP) | `ANIM` | P1 |

---

## 10. VFX catalog (effects matrix)

| Effect | Trigger | Asset types | Priority |
|--------|---------|-------------|----------|
| Repulse blast + launch trail | Cast / combo | `VFX_PART`, `VFX_MESH` ring | P0 |
| Glide trail / wing shimmer | While gliding | `VFX_PART` | P0 |
| Slip teleport puffs | Cast success / fizzle | `VFX_PART` | P0 |
| Wraith enter / loop / exit | Toggle | `VFX_PART` | P0 |
| Lifebloom heal ticks | In aura | `VFX_PART` | P1 |
| Tangle pull streaks | In vortex | `VFX_PART` | P1 |
| Null suppression dome | Active field | `VFX_PART` / dome mesh | P0 |
| Reclaim revive flash | On revive | `VFX_PART` | P1 |
| Dwarf drain motes | Enemies in radius | `VFX_PART` | P1 |
| Bleed drips | Blade backstab DoT | `VFX_PART` | P1 |
| Overdrive chrome surge | Overclock active | `VFX_PART` | P1 |
| Bullet deflect sparks | Blade + Overdrive vs direct | `VFX_PART` | P1 |
| Explosion (grenade / rocket later) | Detonation | `VFX_PART` | P0 grenade / P2 rocket |
| Muzzle / impact / blood (light) | Fire / hit | `VFX_PART` | P0–P1 |
| Pulse Sight world highlight | Active intel | Shader / outline | P1 |
| Resonance spend flash | Any cast | Small `VFX_PART` or UI | P1 |
| Harden shell (Troll) | On stack gain | Shader / mesh | P1 |

Playtest already has **debug radii / tracers** (`PlaytestViz`) — production VFX replace, do not ship debug discs in release.

---

## 11. Audio (SFX / music)

| Category | Examples | Asset type | Priority |
|----------|----------|------------|----------|
| Footsteps | Surface variants | `SFX` | P1 |
| Jump / land / glide wind | Movement | `SFX` | P0 |
| Weapon fire / reload / empty | Per weapon | `SFX` | P0 |
| Blade swing / clash / backstab | Melee | `SFX` | P0 |
| Ability casts | Repulse, Slip, Wraith, fields | `SFX` | P0 |
| Grenade cook beep / boom | Throwable | `SFX` | P0 |
| UI | Buy, deny, ping, round start/end | `SFX` | P1 |
| Hit / death / revive | Combat feedback | `SFX` | P1 |
| Ambient beds | Neon street, indoor, magic hum | `MUSIC` / amb `SFX` | P2 |
| Menu / round stingers | Brand | `MUSIC` | P2 |

**Channel:** Find CC0 / licensed SFX libraries first; commission signature ability sounds later.

---

## 12. UI / 2D

| Surface | Elements | Asset types | Priority | Status |
|---------|----------|-------------|----------|--------|
| Main menu | Background, logo, buttons | `UI_FRAME`, `ICON`, `CONCEPT` bg | P1 | Debug-grade |
| Lobby browser | List chrome, filters | `UI_FRAME` | P1 | Functional |
| Buy menu | Item rows, prices, slot icons, cyber slots | `ICON` per item, `UI_FRAME` | P0 | Debug list |
| Player HUD | Health, Resonance pips, ammo, ability keys, money | `UI_FRAME`, pip art | P0 | Functional debug |
| Crosshair / ADS | Reticles per weapon | `ICON` / `UI_FRAME` | P0 | Minimal |
| Scoreboard / round results | Panels, medals optional | `UI_FRAME` | P1 | Basic |
| Settings / controls / display | Standard chrome | `UI_FRAME` | P2 | Functional |
| Ping markers | World→HUD icons | `ICON` | P1 | Code projection |
| Damage / kill feed | Fonts + icons | `UI_FRAME` | P2 | Playtest combat log |
| Loadout editor | Shopping-list UI | `ICON` + frames | P2 | Default loadout only |
| Ability / weapon icons | Full buy roster | `ICON` set (~20+) | P0 | None art |
| Steam capsule / library art | Marketing | `CONCEPT` | P2 | — |

**Imagine-first** for icons + HUD language; keep resolution friendly for Steam Deck.

### Icon checklist (buy / HUD)

**Weapons:** pistol, smg, shotgun, rifle, sniper, blade, (minigun), (rocket), grenades  
**Manifestations:** lifebloom, reclaim, tangle, repulse, wraith, slip, familiar  
**Augments:** glide, pulse_sight, smart_rig, null_charge, overclock  
**Meta:** Resonance pip, locked reserved pip, money, armor-none (N/A), team colors

---

## 13. Environments & maps

| Need | Asset types | Placeholder / scenes | Channel | Priority |
|------|-------------|----------------------|---------|----------|
| Close-quarters map | Modular `ENV`, lighting, collision | `map_close_quarters.tscn` | Kitbash cyber kit + custom layout | P1 |
| Larger objective / CTF map | Same + verticality for Repulse/Glide | `map_objective.tscn` | Same | P1 |
| Test arena (dev) | Graybox OK | `test_arena.tscn` | Godot | P0 keep |
| Cyber street dressing | AC units, signs, cables, streetlights, doors | `cyberpunk_game_kit` | Kitbash | P1 |
| Magic / Resonance landmarks | Crystals, shrines, Grid nodes | `props/magic` | Kitbash hybrid | P1 |
| Sky / fog / post | Godot env | — | Godot | P1 |
| 2–4 polished maps (EA) | Full kits | PRD target | Layout + kitbash | P1–P2 |
| Traversal props | Rails, ledges, launch pads optional | Modular | Kitbash | P2 |

**Skip / archive from placeholders (style drift):** `toon_shooter_kit`, most `ultimate_space_kit` (ref only), critter enemies unless PvE.

---

## 14. Placeholder → production map (what we already have)

| Folder under `models/placeholders/` | Best use for CounterSpell | Action |
|-------------------------------------|---------------------------|--------|
| `characters/ultimate_modular_men` | Human / runner bodies | **Keep** → promote keepers |
| `characters/ultimate_modular_women` | Human / sci-fi / witch-as-elf interim | **Keep** |
| `characters/animated_men` | Lighter anim tests | Optional |
| `characters/toon_shooter_kit` | Style clash | Archive / delete later |
| `characters/animated_enemies` | Familiar / PvE ref | Optional |
| `weapons/scifi_modular_guns` | Primary gun language | **Keep** |
| `weapons/scifi_gun_pack` | Alt sci-fi / manifestation-y | Keep subset |
| `weapons/ultimate_guns_*` | Street guns, shotgun, SMG | **Keep** |
| `cyberpunk/cyberpunk_game_kit` | Env props | **Keep** |
| `cyberpunk/robots_mechs` | Familiar / chrome stand-in | Subset |
| `cyberpunk/ultimate_space_kit` | Style ref | Mostly skip |
| `props/magic` | Lifebloom / Tangle / Resonance props | **Keep** |
| `props/ultimate_rpg_items` | Weak melee; need real blade | Partial |
| `races/*` | Lineage stand-ins | Keep + fill gaps |

**Production target folders (from skill):**  
`models/characters/`, `models/weapons/`, `models/props/`, `models/env/` — keep placeholders out of final load paths.

---

## 15. Priority shopping list (what to find next)

Ordered for maximum playtest readability with kitbash-first.

### P0 — Find or kitbash now

1. **Human male + female** production stand-ins (modular keepers) + team color method  
2. **Elf male** polish; **Elf female** real mesh  
3. **Dwarf male** true short humanoid (not scaled human only)  
4. **Troll male** bulky humanoid (less “demon/yeti”)  
5. **Gun set:** pistol, SMG, shotgun, rifle, sniper (FP + world) from modular packs  
6. **Katana / combat blade** mesh (missing)  
7. **Grenade** + **Null Charge** device props  
8. **Glide wings / harness** mesh  
9. **Corpse** = death pose of body mesh  
10. **Ability icon sheet** + basic HUD chrome (Imagine)  
11. **Core SFX pack:** guns, Repulse, glide, UI deny  
12. **Signature VFX refs** (Imagine) → implement in Godot: Repulse, Glide, Wraith, Null dome  

### P1 — Full EA fantasy

13. Female Dwarf / Troll or temporary recolors  
14. Lifebloom / Tangle field hero props  
15. Familiar creature mesh + anims  
16. Reclaim / Pulse Sight / Smart Rig / Overclock VFX  
17. CTF objective prop  
18. Map kit dress pass (2 maps)  
19. Full locomotion + blade animation set  
20. Resonance pip art + buy menu art pass  

### P2 — Polish / deferred

21. Minigun + Rocket Launcher  
22. Cosmetics / skins  
23. Music + ambient  
24. Kill feed polish, loadout editor art  
25. Marketing / Steam art  

### P3 — Later

26. PvE enemies, drones, spirits  
27. Grid / decker UX  
28. Extra archetypes  

---

## 16. Acquisition matrix (summary)

| Domain | Primary channel | Secondary |
|--------|-----------------|-----------|
| Character bodies | Kitbash Quaternius + Find race gaps | Blender custom for Dwarf/Troll/Elf-F |
| Weapons | Kitbash gun packs | Blender blade / minigun / rocket |
| Ability props | Kitbash magic + cyber props | Blender hero devices |
| Ability VFX | Godot particles/shaders | Imagine concept refs |
| Animations | Find Mixamo-class or pack anims retargeted | Blender polish signature clips |
| UI / icons | Imagine | Godot Control theme |
| Textures / skins | Imagine → apply on UV’d meshes | Blender paint |
| SFX | Find libraries | Commission signature |
| Maps | Graybox Godot + kitbash modular | Custom hero pieces |
| Art direction | Imagine boards | Freeze before mass production |

---

## 17. Engineering hooks (where assets plug in)

| Asset class | Typical code / scene hook |
|-------------|---------------------------|
| Player body / arms | `scenes/player/fps_controller.tscn`, future visual child |
| Weapons | `WeaponRig` nodes + `scripts/weapons/*`; swap MeshInstance |
| Grenade / Null / fields / Familiar / Corpse | `scenes/abilities/*`, `scenes/weapons/grenade.tscn`, `projectile_spawner.gd` |
| HUD / buy | `scenes/ui/player_hud.tscn`, buy menu scripts |
| Maps | `scenes/levels/*` |
| Review | `scenes/dev/model_review.tscn` |
| Materials | GL **Compatibility** — Principled-simple; verify in Godot not only Blender |

---

## 18. Count estimates (order of magnitude)

| Category | Distinct art items (EA P0–P1) |
|----------|-------------------------------|
| Character bodies (4 lineages × 2 sexes, shared anim) | ~8 meshes (can share skeleton) |
| Locomotion + combat anim clips | ~25–40 clips (shared) |
| Weapons v1 (mesh × FP/TP) | 6 weapons × 2 presentations ≈ 12 |
| Throwables / devices | 2–3 |
| Ability fields / summons | 3 fields + 1 familiar |
| Signature VFX | ~15 systems |
| Icons | ~25–30 |
| Maps | 2–4 |
| Core SFX | ~80–150 cues (many variants) |

This is **solo-survivable** if kitbash + Imagine carry the load and custom modeling is reserved for blade, wings, race gaps, and 2 map kits.

---

## 19. Out of scope for this inventory file

- Exact poly budgets (see `.grok/skills/godot-blender-models/SKILL.md`)  
- MatchConfig balance numbers  
- Legal review of third-party packs beyond CC0 Quaternius already documented in `models/placeholders/ATTRIBUTION.md`  
- Post-MVP idea abilities under `docs/ideas/` (Shield, Clone, Spider Rope, etc.) — promote to this file when mechanics are decided  

---

## 20. Next actions (recommended)

1. Freeze a **style bible** (Imagine, 1 session).  
2. Promote keeper GLBs into `models/characters|weapons|props/` with a short README.  
3. Fill **P0 mesh gaps**: blade, glide harness, dwarf, elf-f, troll humanoid.  
4. Wire first **viewmodel + TP body** into arena for scale check.  
5. Imagine **icon set** for full buy roster; drop into buy menu / HUD.  
6. Implement **3 signature VFX** (Repulse, Glide, Null) before secondary abilities.

---

*Living document — update Status columns as assets land. Prefer links to concrete paths under `models/` once promoted out of placeholders.*

---

## Related: harvest prospects

| Doc | Role |
|-----|------|
| [`docs/assets/00_COMPATIBILITY_AND_SCALE.md`](assets/00_COMPATIBILITY_AND_SCALE.md) | Resize vs separate models; sockets; Augments on all races |
| [`docs/assets/01_SOURCE_CATALOG.md`](assets/01_SOURCE_CATALOG.md) | External/in-repo packs, URLs, license notes |
| [`docs/assets/02_INVENTORY_PROSPECTS.md`](assets/02_INVENTORY_PROSPECTS.md) | Every inventory need → one or more prospects |
| [`docs/assets/03_PLAYTEST_MODEL_REVIEW.md`](assets/03_PLAYTEST_MODEL_REVIEW.md) | Live Godot review (MCP **9292**) + raw scale measurements |
| [`docs/assets/04_ASSET_PROGRESS_AND_GAPS.md`](assets/04_ASSET_PROGRESS_AND_GAPS.md) | Progress, findings, and gap-fill plan |
