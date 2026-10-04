# Prospective Asset Sources (Harvest Catalog)

**Date:** 2026-07-27  
**License preference:** CC0 / public domain first; always re-check the pack page before shipping.  
**Style spine:** Quaternius low-poly (already vendored under `models/placeholders/`).

This catalog lists **external and in-repo** sources we can harvest. Cross-map to inventory items is in `02_INVENTORY_PROSPECTS.md`.

---

## A. In-repo already (first harvest)

| ID | Source | Path / notes | License | Covers |
|----|--------|--------------|---------|--------|
| **R-QMOD-M** | Quaternius Ultimate Modular Men | `models/placeholders/characters/ultimate_modular_men/` | CC0 | Human male runners, modular outfits, anim-ready |
| **R-QMOD-W** | Quaternius Ultimate Modular Women | `models/placeholders/characters/ultimate_modular_women/` | CC0 | Human female; SciFi / Witch / Soldier stand-ins |
| **R-QANIM** | Quaternius Animated Men/Women | `characters/animated_men/` etc. | CC0 | Lighter bodies, anim checks |
| **R-QGUN-SCI** | Sci-Fi Modular Guns | `models/placeholders/weapons/scifi_modular_guns/` | CC0 | Pistol, SMG, AR, sniper, grenade, grenade launcher |
| **R-QGUN-ULT** | Ultimate Guns Pack (sample) | `weapons/ultimate_guns_*` | CC0 | Street pistol, shotgun, SMG, rifle, sniper |
| **R-QGUN-SFP** | Sci-Fi Gun Pack | `weapons/scifi_gun_pack/` | CC0 | Ray/lightning guns, sniper, pistol |
| **R-QCYBER** | Cyberpunk Game Kit | `cyberpunk/cyberpunk_game_kit/` | CC0 | Env props, devices, turrets, computers |
| **R-QROBO** | Robots / Mechs | `cyberpunk/robots_mechs/` | CC0 | Familiar / chrome stand-ins |
| **R-QMAGIC** | Magic props | `props/magic/` | CC0 | Crystals, staff, potions → fields |
| **R-QRPG** | RPG items | `props/ultimate_rpg_items/` | CC0 | Weak melee stand-ins (not final blade) |
| **R-QRACE** | Race stand-ins | `races/` | CC0 | Elf, Orc, Giant/Yeti/Demon troll proxies, goblin |
| **R-QSPACE** | Ultimate Space Kit | mostly skip | CC0 | Style ref only |

**Attribution:** `models/placeholders/ATTRIBUTION.md`  
**Hub:** https://quaternius.com/ · mirror https://poly.pizza/u/Quaternius

---

## B. Quaternius packs to download / refresh (CC0)

Prefer pulling missing pieces from the same artist so style stays coherent.

| ID | Pack | URL | Formats | Harvest for |
|----|------|-----|---------|-------------|
| **Q-UAL** | Universal Animation Library | https://quaternius.com/packs/universalanimationlibrary.html | FBX/glTF | Locomotion, combat retarget base |
| **Q-UAL2** | Universal Animation Library 2 | https://quaternius.com/packs/universalanimationlibrary2.html | FBX/GLB | Melee combos, parkour, extra combat |
| **Q-UBC** | Universal Base Characters | https://quaternius.com/packs/universalbasecharacters.html | — | Shared humanoid base for modular outfits |
| **Q-MCO-F** | Modular Character Outfits – Fantasy | https://quaternius.com/packs/modularcharacteroutfitsfantasy.html | glTF | Mix parts; cyber-fantasy hybrid after retexture |
| **Q-GUNS** | Ultimate Guns Pack | https://quaternius.com/packs/ultimategun.html | FBX/OBJ | Full gun set (40 models) |
| **Q-AGUNS** | Animated Guns Pack | https://quaternius.com/packs/animatedguns.html | FBX | Fire/reload reference; FP inspiration |
| **Q-SMGUN** | Sci-Fi Modular Gun Pack | https://quaternius.com/packs/scifimodularguns.html | — | Already partially local |
| **Q-SFP** | Sci-Fi Gun Pack | https://quaternius.com/packs/scifigun.html | — | Manifestation-flavored weapons |
| **Q-SFE** | Sci-Fi Essentials Kit | https://quaternius.com/packs/scifiessentialskit.html | — | Guns, props, enemies |
| **Q-CYBER** | Cyberpunk Game Kit | https://quaternius.com/packs/cyberpunkgamekit.html | — | Env + devices (local) |
| **Q-MSCI** | Modular Sci-Fi Megakit | https://quaternius.com/packs/modularscifimegakit.html | — | Map modular pieces |
| **Q-MSCIF** | Ultimate Modular Sci-Fi Pack | https://quaternius.com/packs/ultimatemodularscifi.html | — | Map kit |
| **Q-MSTREET** | Modular Streets Pack | https://quaternius.com/packs/modularstreets.html | — | City streets for maps |
| **Q-FANTASY-RTS** | Ultimate Fantasy RTS | https://quaternius.com/packs/ultimatefantasyrts.html | — | Bulk/fantasy race silhouettes |
| **Q-MON** | Ultimate Monsters | https://quaternius.com/packs/ultimatemonsters.html | Animated | Familiar candidates, bulk creatures |
| **Q-MECH** | Animated Mech Pack | https://quaternius.com/packs/animatedmech.html | — | Chrome / rigger future |
| **Q-ROBO** | Animated Robot Pack | https://quaternius.com/packs/animatedrobot.html | — | Familiar / Null aesthetic |
| **Q-RPGCHAR** | RPG Character Pack | https://quaternius.com/packs/rpgcharacters.html | Animated | Elf/mage stand-ins |
| **Q-MEDWEP** | Modular Weapons (medieval) | https://quaternius.com/packs/medievalweapons.html | — | Blade parts / fantasy weapons |
| **Q-FPROPS** | Fantasy Props MegaKit | https://quaternius.com/packs/fantasypropsmegakit.html | Godot source option | Crystals, ritual props, flags |
| **Q-URPG** | Ultimate RPG Pack | https://quaternius.com/packs/ultimaterpg.html | — | Props / weapons fill |
| **Q-DOWNTOWN** | Downtown City MegaKit | https://quaternius.com/packs/downtowncitymegakit.html | Modular | Large map pieces (newer) |

**Compatibility notes:** Same artist ≈ same poly language. Modular outfits require **Universal Base** bones for clean part swaps. Anim libraries are humanoid-retarget targets for all four lineages once bodies exist.

---

## C. Standout7 LOWPO (CC0 free tiers)

| ID | Pack | URL | License | Harvest for | Race fit notes |
|----|------|-----|---------|-------------|----------------|
| **S7-ELF** | Low Poly Elf (free tier) | https://standout7.itch.io/low-poly-elf | CC0 free (3 elves + weapons) | **Elf male/female candidates**, sword | Fantasy low-poly; **retexture to cyber-elf**; verify gender presentation on import |
| **S7-ORC** | Orc low poly | https://standout7.itch.io/orc-low-poly | Free/CC0 check page | Bulk humanoid ref; **not** player Orc lineage | Proportions may help **Troll** kitbash |
| **S7-COL** | LOWPO collection | https://itch.io/c/7666726/lowpo | Mixed free/paid | Dwarf/troll when free tiers appear | Prefer free CC0 only unless budget opens |

**Compatibility:** Not Quaternius UV layout — use as **full body replacements** or heavy restyle, not modular part-swap with R-QMOD. Retarget anims via humanoid map.

---

## D. KayKit (Kay Lousberg) — CC0

| ID | Pack | URL | Harvest for |
|----|------|-----|-------------|
| **K-ANIM** | Character Animations | https://kaylousberg.itch.io/kaykit-character-animations | 130+ humanoid clips (Godot-friendly glTF/FBX) |
| **K-ADV** | Adventurers | https://kaylousberg.itch.io/kaykit-adventurers | Extra humanoids / accessories |
| **K-PROTO** | Prototype Bits | https://kaylousberg.itch.io/prototype-bits | Graybox + prototype character |

**Style:** Slightly different cute-lowpoly. **Restyle materials** before mixing with Quaternius in the same shot, **or** use **anims only** (recommended).

---

## E. Kenney — CC0 (UI, audio, some 3D)

| ID | Pack | URL | Harvest for |
|----|------|-----|-------------|
| **KN-UI** | UI packs | https://kenney.nl/assets?q=ui | Buy menu / HUD chrome, buttons |
| **KN-AUDIO** | Interface / impact / sci-fi sounds | https://kenney.nl/assets?q=audio · OGA mirrors | UI, impacts, sci-fi zaps |
| **KN-INPUT** | Input prompts | kenney.nl assets | Controller glyphs |
| **KN-3D** | Various 3D | https://kenney.nl/assets | Props only if style-matched |

---

## F. Poly Pizza (discovery hub)

| ID | Hub | URL | Notes |
|----|-----|-----|-------|
| **PP** | Poly Pizza | https://poly.pizza/ | Aggregates Quaternius + others; filter license; quick glTF |
| **PP-Q** | Quaternius author | https://poly.pizza/u/Quaternius | Giant, Demon, modular packs, guns |

Search targets: `dwarf`, `giant`, `elf`, `katana`, `wings`, `grenade`, `crystal`, `robot`.

---

## G. Blade / melee prospects

| ID | Source | URL / location | License | Notes |
|----|--------|----------------|---------|-------|
| **B-QMED** | Quaternius medieval weapons | Q-MEDWEP | CC0 | Kitbash into katana silhouette |
| **B-QRPG** | In-repo Knife / Claymore / Scythe | R-QRPG | CC0 | Interim only |
| **B-S7** | LOWPO elf sword | S7-ELF free | CC0 | Closer to blade fantasy |
| **B-ITCH** | Low Poly Katana (TheLeggies) | https://theleggies.itch.io/low-poly-katana | Check page (often free/name-your-price) | Verify commercial terms |
| **B-SKFB** | Sketchfab low-poly katana | Search Sketchfab “low poly katana” + downloadable + license filter | Varies | Prefer CC0/CC-BY with commercial; re-export glb |
| **B-BLEND** | Author simple katana in Blender | Internal | Owned | 300–800 tris, matches Quaternius edges — **recommended hero path** |

---

## H. Glide / wings / harness

| ID | Source | Notes |
|----|--------|-------|
| **W-BLEND** | Blender-authored hard-surface wing fins + backpack | Best match; 2–4 LODs unnecessary; socket_back |
| **W-SKFB** | Sketchfab “low poly wings” | License-filter; restyle chrome |
| **W-KIT** | Kitbash from Quaternius antenna / plate / robot fins | R-QCYBER + R-QROBO parts |

Do **not** use feathered angel wings without a hard-surface restyle (breaks chrome-runner fantasy).

---

## I. Race gap fillers

| Lineage | Primary prospects | Secondary |
|---------|-------------------|-----------|
| Human M/F | **R-QMOD-M/W** | Q-UBC + Q-MCO-F |
| Elf M | **R-QRACE** Elf.fbx · **S7-ELF** free | Q-RPGCHAR wizards restyled |
| Elf F | **S7-ELF** · R-QMOD-W Witch/SciFi + ears | Temporary scale male Elf + ear attach |
| Dwarf M/F | Poly Pizza dwarf/gnome search · S7 when free · **Blender reshape** modular human (shorten limbs, widen) | Avoid pure uniform scale |
| Troll M | **R-QRACE** Giant · Q-MON large humanoids · S7-ORC bulk | Restyle away from pure “demon” |
| Troll F | Kitbash Troll M proportions + modular women silhouette · Blender | High gap |

---

## J. Animation sources

| ID | Source | URL | Use |
|----|--------|-----|-----|
| **A-QMOD** | Clips on modular men/women | In-repo | Idle/run baseline |
| **A-UAL** | Quaternius UAL / UAL2 | Q-UAL, Q-UAL2 | Main TP library |
| **A-KAY** | KayKit Character Animations | K-ANIM | Secondary / Godot tutorials exist |
| **A-MIX** | Mixamo | https://www.mixamo.com/ | Filler clips; **Adobe free account**; retarget carefully; restyle not needed for anims-only |
| **A-GUN** | Quaternius Animated Guns | Q-AGUNS | Weapon motion reference |

**Race policy:** One library → retarget to all bodies. Dwarf/Troll may need playback rate and stride scale, not new mocap.

---

## K. Audio sources (CC0-friendly)

| ID | Source | URL | Use |
|----|--------|-----|-----|
| **AUD-FIRE** | Free Firearm Sound Library | https://opengameart.org/content/the-free-firearm-sound-library | Gunshots, reloads (CC0) |
| **AUD-KN-I** | Kenney Interface Sounds | https://opengameart.org/content/interface-sounds | UI |
| **AUD-KN-SCI** | Kenney Sci-Fi Sounds | https://opengameart.org/content/sci-fi-sounds | Abilities, Null, Slip |
| **AUD-KN-DIG** | Kenney digital/lasers | https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc | Manifestation zaps |
| **AUD-KN-IMP** | Kenney Impact Sounds | https://kenney.nl/assets/impact-sounds | Hits, landings |
| **AUD-RPG** | Kenney 50 RPG SFX | https://opengameart.org/content/50-rpg-sound-effects | Magic, UI |
| **AUD-100** | 100 CC0 SFX | https://opengameart.org/content/100-cc0-sfx | Filler |
| **AUD-FOOT** | Fantozzi footsteps (OGA collections) | Search OGA CC0 footsteps | Surfaces |
| **MUS-CC0** | OpenGameArt / freepd / incompetech (check license) | — | Menu beds (verify commercial) |

---

## L. UI / 2D / icons

| ID | Source | Use |
|----|--------|-----|
| **UI-KN** | Kenney UI packs | Frames, buttons, bars |
| **UI-IMG** | Grok Imagine | Full **icon set** for weapons/abilities; logo; HUD pips; team colors |
| **UI-FONT** | Godot defaults + free fonts (OFL) | HUD numbers; pick one geometric sans |

Icons should be drawn in one Imagine pass with a locked palette so buy menu matches HUD.

---

## M. VFX (mostly engine + refs)

| ID | Source | Use |
|----|--------|-----|
| **VFX-GODOT** | GPUParticles3D, meshes, shaders | Production implementation |
| **VFX-IMG** | Grok Imagine stills | Concept for Repulse rings, Wraith, Null dome, Lifebloom |
| **VFX-TEX** | Kenney particles / free particle sprites | Smoke, spark atlases |
| **VFX-MESH** | Quaternius crystals / rings kitbashed | Lifebloom, Tangle, Repulse ring |

---

## N. Maps / environment

| ID | Source | Use |
|----|--------|-----|
| **E-QCYBER** | Cyberpunk Game Kit (local) | Street dressing |
| **E-QMSCI** | Modular Sci-Fi MegaKit | Interiors / Grid-adjacent |
| **E-QMST** | Modular Streets | Outdoor lanes |
| **E-QDOWN** | Downtown City MegaKit | Larger blocks |
| **E-GODOT** | CSG / GridMaps for graybox | Layout first |
| **E-MAGIC** | Magic props + fantasy props | Resonance landmarks |

---

## O. Deferred weapons (P2)

| Need | Prospects |
|------|-----------|
| Minigun | Quaternius guns / space / turret barrels kitbash; Sci-Fi Essentials; Blender assemble from R-QGUN parts |
| Rocket Launcher | Scifi Grenade Launcher (local) restyled; Ultimate Guns; Blender |

---

## P. Sources to avoid as primary

| Source | Why |
|--------|-----|
| Toon Shooter Kit | Style clash (already flagged in placeholders README) |
| Unlicensed Sketchfab “download” rips | Legal risk |
| Unity Asset Store paid packs without budget | Cost; often locked license |
| AI mesh sites with unclear commercial rights | Prefer CC0-labeled only |
| Realistic megascans characters | Poly/material mismatch + Compatibility pain |

---

## Q. Recommended harvest order (practical)

1. Freeze style from **R-QMOD** + **R-QGUN-SCI** (already local).  
2. Download **Q-UAL / Q-UAL2** for TP animation coverage.  
3. Pull **S7-ELF** free for Elf gap.  
4. Author **blade + glide harness** in Blender to match Quaternius (fast, guaranteed fit).  
5. Grab **AUD-FIRE + Kenney sci-fi/UI**.  
6. Imagine **icon sheet + art bible**.  
7. Expand maps with **Q-MSCI / Q-MSTREET / Q-DOWNTOWN** as needed.  
8. Fill Dwarf/Troll with Giant + reshaped modular + optional LOWPO paid only if free fails.

---

## R. License checklist (every download)

- [ ] License is **CC0** or commercial-OK written on page  
- [ ] No “non-commercial only”  
- [ ] Note author + URL in `models/.../ATTRIBUTION.md` or pack README  
- [ ] Re-export clean `.glb` into `models/characters|weapons|props|env/` (not forever under placeholders)  
- [ ] Strip trademark names from textures  

---

*Prospects are candidates, not commitments. Promote into production folders only after the §6 test in `00_COMPATIBILITY_AND_SCALE.md`.*
