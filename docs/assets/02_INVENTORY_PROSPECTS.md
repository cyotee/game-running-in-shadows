# Inventory → Prospects Map

**Date:** 2026-07-27  
**Inventory source:** `docs/ASSET_INVENTORY.md`  
**Sources:** `docs/assets/01_SOURCE_CATALOG.md` (IDs like `R-QMOD-M`, `S7-ELF`)  
**Fit rules:** `docs/assets/00_COMPATIBILITY_AND_SCALE.md`

For each inventory need: **prospects**, **race policy** (shared / resize / separate), **compat notes**.

Legend: **Pri** = P0–P3 · **Race** = Shared | Resize-OK | Separate mesh · **Status** = local / download / author / imagine / godot

---

## 0. Style & brand

| Inventory need | Prospects (IDs) | Race | Status | Notes |
|----------------|-----------------|------|--------|-------|
| Art bible / palette | **UI-IMG** (Imagine 8–12 keyframes); anchor refs R-QMOD + R-QCYBER + R-QMAGIC | Shared | Imagine | Lock neon chrome + crystal resonance before mass harvest |
| Logo CounterSpell | **UI-IMG** | Shared | Imagine | Menus + Steam |
| Silhouette language | Keep **R-QMOD**, **R-QGUN-SCI**; skip toon kit | Shared | Local | Cohesion test in `model_review.tscn` |

---

## 1. Lineages (character bodies)

| Inventory need | Prospects | Race policy | Status | Compat / scale |
|----------------|-----------|-------------|--------|----------------|
| **Human male** | **Primary:** R-QMOD-M (Punk, Worker, SWAT, Casual). **Alt:** Q-UBC + Q-MCO-F | Base mesh | Local | Baseline 1.7–1.85 m |
| **Human female** | **Primary:** R-QMOD-W (Soldier, Suit, SciFi, Worker). **Alt:** Q-UBC female | Base mesh | Local | Same skeleton family as men when possible for anim retarget |
| **Elf male** | **Primary:** R-QRACE `Elf.fbx`. **Strong alt:** S7-ELF free (Classic/Fire/Ice). **Fill:** Q-RPGCHAR wizards restyled | **Separate mesh** (ears, slim). Temp: Human ×1.05–1.10 + ear attach | Local + download S7 | Retexture fantasy → cyber-elf; do not modular-swap Quaternius limbs onto S7 without rebinding |
| **Elf female** | **Primary:** S7-ELF free/premium genders. **Interim:** R-QMOD-W Witch/SciFi + ear attach. **Last resort:** scale Elf male + retexture | **Separate mesh** preferred | Download / kitbash | Ear attach keeps Augment head sockets working |
| **Dwarf male** | **Primary:** Blender reshape R-QMOD (short limbs, wide torso) **or** Poly Pizza dwarf/gnome CC0. **Alt:** S7 when free dwarf appears | **Separate mesh required** | Author / find | **Never** uniform scale Human only |
| **Dwarf female** | Same pipeline as dwarf male + feminine modular proportions | **Separate mesh required** | Author / find | Share dwarf skeleton between sexes if possible |
| **Troll male** | **Primary:** R-QRACE Giant restyled cyber. **Alt:** S7-ORC bulk proportions, Q-MON large humanoids. Avoid pure Demon/Yeti for final | **Separate mesh required** | Local + kitbash | Height 2.2–2.55 m; retarget anims slow |
| **Troll female** | Kitbash Giant proportions + R-QMOD-W silhouette; Blender | **Separate mesh required** | Author | High gap — ship male-first OK for playtest |
| Hit zones | Godot capsules on all bodies | Per race dimensions | Godot | Art-free |
| Team readability | **UI-IMG** armband decals; material emission color; outline shader | Shared overlays | Imagine + Godot | Works on all races if UV has flat strip or use mesh overlay band on `socket_chest` |
| Future archetypes | Deferred | — | P3 | — |

### Per-lineage extras

| Need | Prospects | Race | Notes |
|------|-----------|------|-------|
| Elf heal VFX | VFX-GODOT + VFX-IMG ref | Shared effect, chest socket | |
| Dwarf drain aura | VFX-GODOT (disc → final mesh) | Shared | Debug disc exists |
| Troll Harden shell | Shader / simple shell mesh scaled to torso | **Scale with troll body** | One mesh + non-uniform scale OK |
| Human hybrid chrome | Socket props from R-QCYBER / R-QROBO | Attach shared | |

---

## 2. Player presentation (FPS + TP)

| Need | Prospects | Race policy | Status |
|------|-----------|-------------|--------|
| Third-person body | Per-lineage meshes above | Separate per race | — |
| First-person arms | **Primary:** extract arms from R-QMOD. **Alt:** simple Blender arms matching gun style | **Human+Elf shared**; **Dwarf separate**; **Troll separate or scale (ugly)** | Kitbash |
| FP weapons | R-QGUN-SCI, R-QGUN-ULT, Q-AGUNS | **Shared** (±scale) | Local |
| TP / drop weapons | Same gun meshes | **Shared** | Local |
| Blade TP camera | Code SpringArm + body | Per race body | Code exists |
| Glide wings | **W-BLEND** primary; W-KIT from R-QCYBER/R-QROBO fins; W-SKFB license-checked | **One attach set**, scale with `socket_back` | Author |
| Wraith form | VFX-GODOT + VFX-IMG | Shared VFX (hide mesh) | Godot |
| Corpse | Death pose of each race body; A-UAL death clips | **Per race** | Anim + mesh |
| Drag corpse | A-UAL / A-KAY / A-MIX “carry” or “walk” + IK later | Per race anim retarget | Download |

---

## 3. Weapons

### 3.1 v1 roster

| Weapon | Mesh prospects | Icon | SFX | Race | Status |
|--------|----------------|------|-----|------|--------|
| **Pistol** | R-QGUN-SCI `Scifi_Pistol*`; R-QGUN-ULT Pistol; Q-GUNS | UI-IMG | AUD-FIRE | Shared | Local mesh candidates |
| **SMG** | R-QGUN-SCI `Scifi_Smg`; R-QGUN-ULT SMG; Q-AGUNS P90-class | UI-IMG | AUD-FIRE | Shared | Local |
| **Shotgun** | R-QGUN-ULT Shotgun*; Q-GUNS | UI-IMG | AUD-FIRE | Shared | Local |
| **Rifle** | R-QGUN-SCI `Scifi_AR*`; Assault_Rifle* | UI-IMG | AUD-FIRE | Shared | Local |
| **Sniper** | R-QGUN-SCI `Scifi_Sniper*`; Sniper_Rifle* | UI-IMG | AUD-FIRE | Shared | Local |
| **Combat Blade** | **B-BLEND** (recommended); B-S7 sword; B-QMED kitbash; B-ITCH/B-SKFB if CC0 | UI-IMG | AUD-KN-IMP + swoosh from AUD-RPG | Shared length | **Author / find** — gap |

**Viewmodel policy:** One FP gun mesh per weapon; parent to arms; Dwarf/Troll change **arms**, not gun topology.

### 3.2 Deferred

| Weapon | Prospects | Race | Notes |
|--------|-----------|------|-------|
| **Minigun** | Kitbash Q-GUNS + turret barrels R-QCYBER; Q-SFE; Blender | Shared | Promote early if loadouts need it |
| **Rocket Launcher** | R-QGUN-SCI Grenade_Launcher restyle; Q-GUNS; Blender rocket prop | Shared | |

### 3.3 Shared weapon FX / audio

| Need | Prospects | Race |
|------|-----------|------|
| Muzzle flash | VFX-GODOT sprites; VFX-TEX; VFX-IMG | Shared |
| Tracers | Godot (playtest exists) | Shared |
| Impacts | VFX-GODOT + AUD-KN-IMP | Shared |
| Reload/equip SFX | AUD-FIRE | Shared |
| ADS reticle | UI-IMG / UI-KN | Shared |
| Smart Rig laser | VFX-GODOT line | Shared |
| Bleed VFX | VFX-GODOT | Shared |
| Pickup/drop | World mesh + AUD-KN-I | Shared |

---

## 4. Equipment & throwables

| Item | Prospects | Race | Compat |
|------|-----------|------|--------|
| **Grenades** | R-QGUN-SCI `Scifi_Grenade`; explosion VFX-GODOT; SFX AUD-FIRE/AUD-KN-SCI | Shared prop | Hand socket only |
| **Null Charge** | R-QCYBER Lootbox / Computer / Collectible restyle into sticky puck; field dome VFX-GODOT | Shared | World-space field |
| **Glide Harness** | W-BLEND / W-KIT | **Attach shared**, scale on back socket | Never bake into race mesh |
| Weapon drops | Same WORLD_WEAPON meshes + emissive | Shared | |
| Ammo packs (later) | R-QCYBER small props | Shared | |

---

## 5. Manifestations

| Ability | Prop / mesh prospects | VFX / SFX | Race | Notes |
|---------|----------------------|-----------|------|-------|
| **Repulse** | Optional ring mesh from torus / Q-FPROPS | VFX-GODOT + VFX-IMG; AUD-KN-SCI / AUD-KN-DIG | Shared | Signature — invest art |
| **Slip** | None (teleport) | Burst particles; AUD-KN-DIG | Shared | Fizzle variant |
| **Wraith** | Optional ghost duplicate mesh | Dissolve shader; AUD-KN-SCI | Shared hide body | Works all races |
| **Lifebloom** | R-QMAGIC Crystal / Big_Crystal / Crystal_Block; Q-FPROPS | Heal aura VFX; soft SFX AUD-RPG | Shared world | Friend-or-foe readable color |
| **Tangle** | Crystal clusters kitbash R-QMAGIC; razor shards Blender | Pull streaks VFX; scrape SFX | Shared world | Block silhouette must read |
| **Reclaim** | No prop required | Revive burst VFX; choir-like AUD-RPG | Shared | Corpse consumed |
| **Familiar** | **Primary:** R-QROBO small robot / Q-ROBO. **Alt:** Q-MON small creature; R-Q animated enemies | Melee anim from pack; death VFX | **One shared summon** | Not scaled to caster race |

---

## 6. Augments

| Augment | Visual prospects | Race / fit rule |
|---------|------------------|-----------------|
| **Glide Harness** | See §4 wings | Back socket, scale with torso |
| **Pulse Sight** | Fullscreen UI-IMG edges + outline shader; AUD-KN-I ping | **No body mesh** — universal |
| **Smart Rig** | Optional small eye prop on `socket_head` (R-QCYBER greeble); laser VFX; HUD wedge | Eye prop **scales with head**; laser shared |
| **Null Charge** | See §4 | Shared |
| **Overclock Rig** | Emissive veins **shader/decal** (Imagine masks); speed lines VFX; deflect sparks | **Shader-first** so Elf/Dwarf/Troll all work; avoid Human-only armor mesh |
| Cyber slot UI | UI-IMG icons Eye / Full Body | Shared UI |

---

## 7. World entities

| Need | Prospects | Race |
|------|-----------|------|
| **Corpse** | Race body + death anim A-UAL | Per race |
| **CTF / variable flag** | Q-FPROPS banner / device; R-QCYBER Collectible_Board restyle as “objective core”; Blender unique prop | Shared world |
| Flag VFX/SFX | VFX-GODOT + AUD-KN-I | Shared |
| Spawn / buy markers | Decals UI-IMG; R-QCYBER Light_Square | Shared |
| Cover / interactables | R-QCYBER Door, Computer, Streetlight, AC, Cable | Shared |
| Field damage states | Material swap on Lifebloom/Tangle | Shared |

---

## 8. Animations

| Clip group | Prospects | Race policy |
|------------|-----------|-------------|
| Idle / walk / run / sprint | A-QMOD, **A-UAL**, A-KAY, A-MIX | Retarget all races; Dwarf/Troll playback scale |
| Jump / fall / land | A-UAL, A-KAY | Shared retarget |
| Crouch (future) | A-UAL2 / A-MIX | Shared |
| Glide loop | Custom short clip or airborne idle + wing mesh | Shared |
| Wraith | VFX-driven; optional float idle | Shared |
| Death / get-up | A-UAL, A-KAY | Per race mesh + retarget |
| Drag walk | A-MIX “walking while carrying” or improvise | Retarget |
| TP fire / reload | A-UAL armed clips; A-GUN reference | Shared |
| Blade draw / swing / block | A-UAL2 melee; A-KAY; A-MIX sword packs | Shared |
| FP weapon anims | Q-AGUNS reference; Godot AnimationPlayer on viewmodel | Shared guns |
| Familiar idle/move/attack | Built into Q-ROBO / Q-MON packs | Single mesh |
| Wings deploy | Simple Blender shape keys or rotate bones | Shared harness |
| Grenade throw FP | A-MIX / custom | Shared arms |

---

## 9. VFX catalog

| Effect | Prospects | Race |
|--------|-----------|------|
| Repulse blast / launch trail | VFX-GODOT + Imagine ref | Shared |
| Glide trail | VFX-GODOT | Shared attach back |
| Slip puffs | VFX-GODOT | Shared |
| Wraith enter/loop/exit | Shader + particles | Shared |
| Lifebloom heal ticks | Particles green/teal | Shared |
| Tangle pull streaks | Particles + crystal mesh | Shared |
| Null dome | Transparent sphere mesh + shader | Shared |
| Reclaim flash | Particles | Shared |
| Dwarf drain motes | Particles | Shared |
| Bleed drips | Particles | Shared |
| Overdrive surge | Emissive + particles | Shared |
| Deflect sparks | Particles + AUD-KN-IMP | Shared |
| Grenade explosion | Particles + AUD-FIRE | Shared |
| Rocket explosion (P2) | Same system larger | Shared |
| Muzzle / impact | Particles | Shared |
| Pulse Sight highlight | Shader outline | Shared |
| Resonance spend | UI pip flash + tiny particle | Shared |
| Harden shell | Mesh/shader on troll | **Scales with troll** |

---

## 10. Audio

| Category | Prospects |
|----------|-----------|
| Footsteps | AUD-FOOT, AUD-KN-IMP |
| Jump / land / glide wind | AUD-KN-SCI, AUD-100 |
| Weapon fire / reload | **AUD-FIRE** primary |
| Blade | AUD-KN-IMP, AUD-RPG swooshes |
| Abilities | AUD-KN-SCI, AUD-KN-DIG, AUD-RPG |
| Grenade | AUD-FIRE + beeps from AUD-KN-I |
| UI | **AUD-KN-I** |
| Hit / death | AUD-KN-IMP, OGA hurt packs (CC0) |
| Ambient / music | MUS-CC0 (verify); Imagine not for audio |

All audio **shared** across races (pitch-shift troll footsteps optional polish).

---

## 11. UI / 2D

| Surface | Prospects |
|---------|-----------|
| Main menu / lobby chrome | UI-KN + UI-IMG backgrounds |
| Buy menu item icons | **UI-IMG** full set (see inventory icon checklist) |
| HUD health / Resonance pips | UI-IMG pips + Godot ProgressBar theme |
| Crosshair / ADS | UI-IMG |
| Scoreboard / results | UI-KN frames |
| Settings menus | UI-KN |
| Ping markers | UI-IMG |
| Loadout editor (later) | UI-KN + icons |
| Steam marketing | UI-IMG |

---

## 12. Environments & maps

| Need | Prospects |
|------|-----------|
| Close-quarters map | E-GODOT graybox + E-QCYBER + E-QMSCI |
| Objective / CTF map | Same + E-QMST / E-QDOWN verticality for Repulse/Glide |
| Test arena | Keep `test_arena.tscn` |
| Cyber street dressing | R-QCYBER, E-QCYBER |
| Resonance landmarks | R-QMAGIC, Q-FPROPS |
| Sky / fog | Godot Environment |
| Traversal props | Modular sci-fi + streets kits |

Race-independent.

---

## 13. Placeholder pack actions (from inventory §14)

| Pack | Prospect action |
|------|-----------------|
| ultimate_modular_men/women | **Promote keepers** → production Human |
| scifi_modular_guns + ultimate_guns | **Promote** → weapon set |
| cyberpunk_game_kit | **Promote** env subset |
| props/magic | **Promote** field props |
| robots_mechs | Familiar candidate |
| races/* | Elf + Giant keep; improve Dwarf/Troll |
| toon_shooter_kit | Archive |
| ultimate_space_kit | Ref only |

---

## 14. Coverage matrix (inventory completeness)

| Inventory domain | Covered by prospects? | Weakest link |
|------------------|----------------------|--------------|
| Style / logo | Yes (Imagine + Quaternius) | Need freeze pass |
| Human M/F | Yes (local) | — |
| Elf M/F | Yes (local Elf + S7 + Witch interim) | Female polish |
| Dwarf M/F | Partial | **Need author/find true dwarf** |
| Troll M/F | Partial (Giant) | Female; less “monster” |
| FP arms | Partial | Dwarf/Troll arms |
| Guns v1 | Yes (local) | Wire into scenes |
| Blade | Partial | **Author B-BLEND** |
| Grenade / Null | Yes | Restyle Null device |
| Glide harness | Partial | **Author W-BLEND** |
| All Manifestations | Yes (props + VFX + SFX packs) | Art polish |
| All Augments | Yes (shader/socket approach) | Overclock must stay non-mesh-locked |
| Familiar | Yes (robots/monsters) | Pick one silhouette |
| Corpse / CTF | Yes | Unique flag prop |
| Animations | Yes (UAL/KayKit/Mixamo) | Retarget pipeline |
| VFX full list | Yes (Godot + Imagine refs) | Implementation time |
| Audio full list | Yes (Firearm lib + Kenney) | Mix levels |
| UI full list | Yes (Kenney + Imagine icons) | Icon sheet |
| Maps | Yes (modular kits) | Layout labor |
| Minigun / Rocket | Yes (kitbash path) | Deferred |

**Nothing in `ASSET_INVENTORY.md` is left without at least one prospect path.**

---

## 15. “Cybernetic on Elf” guarantee

To keep Augments valid on every lineage:

| Augment | Implementation rule | If we break the rule… |
|---------|---------------------|------------------------|
| Glide | Back **socket prop** only | Wings clip Elf spine / float off Dwarf |
| Smart Rig | Head socket greeble **or** pure VFX/UI | Eye mesh only fits Human UV |
| Pulse Sight | UI + shader only | — |
| Overclock | **Material/shader**, not armor suit mesh | Suit explodes on Troll shoulders |
| Null / Grenades | Held world props | — |

Any future “chrome arm” cosmetic must be either:

1. Per-race weighted mesh, or  
2. Socketed modular piece with loose fit and no Human-only weights.

---

## 16. Suggested first harvest batch (actionable)

| # | Action | Covers |
|---|--------|--------|
| 1 | Promote R-QMOD Punk/SciFi + R-QGUN-SCI set into `models/` | Human + guns |
| 2 | Download S7-ELF free | Elf bodies |
| 3 | Download Q-UAL or Q-UAL2 | TP anims |
| 4 | Blender: katana + glide fins matching Quaternius | Blade + Glide P0 gaps |
| 5 | Download AUD-FIRE + Kenney Interface + Sci-Fi | Audio core |
| 6 | Imagine: icon sheet (weapons + abilities) + 6 art-bible frames | UI + direction |
| 7 | Kitbash Giant → Troll cyber material | Troll P0 |
| 8 | Blender dwarf blockout from modular human proportions | Dwarf P0 |

---

## 17. File index

| File | Role |
|------|------|
| `docs/ASSET_INVENTORY.md` | What the game needs |
| `docs/assets/00_COMPATIBILITY_AND_SCALE.md` | Resize vs separate; sockets; style lock |
| `docs/assets/01_SOURCE_CATALOG.md` | Where to get packs (URLs + IDs) |
| `docs/assets/02_INVENTORY_PROSPECTS.md` | This map: need → prospects |

---

*Update Status columns as packs are downloaded into the repo. Prefer CC0; log attribution beside production models.*
