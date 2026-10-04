# Asset Pipeline — Progress, Findings & Gap Plan

**Project:** CounterSpell  
**Branch:** `feat/asset-pipeline-inventory`  
**Date:** 2026-07-27  
**Audience:** Owner / agents continuing art integration  
**Related docs:**

| Doc | Role |
|-----|------|
| [`docs/ASSET_INVENTORY.md`](../ASSET_INVENTORY.md) | Full need list (races, weapons, FX, UI, anims…) |
| [`docs/assets/00_COMPATIBILITY_AND_SCALE.md`](00_COMPATIBILITY_AND_SCALE.md) | Resize vs separate mesh; sockets; Augments on all races |
| [`docs/assets/01_SOURCE_CATALOG.md`](01_SOURCE_CATALOG.md) | External packs & URLs |
| [`docs/assets/02_INVENTORY_PROSPECTS.md`](02_INVENTORY_PROSPECTS.md) | Inventory item → harvest prospects |
| [`docs/assets/03_PLAYTEST_MODEL_REVIEW.md`](03_PLAYTEST_MODEL_REVIEW.md) | Live Godot review + raw scale numbers |

**Strategy locked:** Prefer **edit / kitbash** existing Quaternius-style models; **Grok Imagine** for concepts, textures, icons; **Blender** only for true gaps (blade, glide, race reshape). No Shadowrun IP in assets.

---

## 1. Executive summary

### Progress

1. Cut branch **`feat/asset-pipeline-inventory`**.
2. Wrote a full **asset inventory** mapping every gameplay need to asset *types*.
3. Searched and documented **prospective harvest sources** with cross-race compatibility rules.
4. Configured **Godot MCP on port 9292** (leaving 9090 free for other agents).
5. Ran **live `model_review`** against in-repo placeholders: 22 packs, 185 models loaded; raw AABB scales measured for key prospects.
6. Decided which models are **ready to promote** vs which gaps still need a fill path.

### Bottom line

| Question | Answer |
|----------|--------|
| Can we start putting models in the game? | **Yes** — Human bodies, sci-fi gun set, grenade, crystals, cyber props, robot Familiar. |
| Is the full EA visual kit closed? | **No** — blade, glide harness, Dwarf, production Elf/Troll, VFX/UI/anims still need work. |
| Do we need more random asset shopping? | **Mostly no.** Gaps are known and have concrete fill options. |

---

## 2. What was done (chronological)

### 2.1 Planning & inventory

- Documented races, weapons, Manifestations, Augments, corpses, Familiar, maps, UI, SFX, animations.
- Classified each need by asset type (`CHAR_MESH`, `VIEWMODEL`, `VFX_PART`, `ICON`, etc.) and priority P0–P3.
- Agreed hybrid pipeline: kitbash 3D first; Imagine for 2D/direction; Blender for hero gaps.

### 2.2 Compatibility rules

- **Shared across races:** guns, blade, grenades, Null, fields, Familiar, UI, VFX, SFX.
- **Separate mesh required (production):** Dwarf, Troll; Elf preferred separate (ears / proportions).
- **Safe temporary scale:** Human → Elf height only (~×1.05–1.10) with ear attach — not a final Elf.
- **Unsafe:** Human ×0.75 as Dwarf; Human ×1.3 as Troll.
- **Augments:** socket props + shaders (`socket_back`, `socket_head`, …) so chrome works on Elf/Dwarf/Troll — never Human-only armor suits.

### 2.3 Source catalog

- Primary: **Quaternius CC0** (already under `models/placeholders/`).
- Secondary: Standout7 LOWPO free elves, KayKit anims, Kenney UI/audio, OGA Free Firearm library, Imagine icons.
- Avoid as primary: toon shooter kit, unclear-license Sketchfab rips, style-mismatched realistic packs.

### 2.4 Live Godot test (MCP 9292)

| Item | Detail |
|------|--------|
| Scene | `res://scenes/dev/model_review.tscn` |
| Port | **9292** (`GODOT_MCP_PORT`) |
| Engine | Godot 4.7.1 Compatibility |
| Result | 22 packs, 185 models; Steam offline OK; MCP responsive after grid load |
| Artifacts | `.scratch/model_review_test/` (screenshots + `raw_scale_report.json`) |
| Write-up | `03_PLAYTEST_MODEL_REVIEW.md` |

**Important caveat:** `model_review` **normalizes** each model so max dimension ≈ 2 m for browsing. Production scale decisions use **raw** measurements only.

### 2.5 Tooling

- Game: already supported `GODOT_MCP_PORT`.
- Node bridge (`tools/godot-mcp`): now reads `GODOT_MCP_PORT`.
- `.mcp.json`: sets `"GODOT_MCP_PORT": "9292"`.
- `docs/TESTING.md`: notes the override.

---

## 3. What we found

### 3.1 Style spine (confirmed in-engine)

- **Keep:** Ultimate modular men/women + sci-fi modular guns + cyberpunk game kit + magic crystals.
- **Archive / don’t mix as production runners:** toon shooter kit (chibi / cartoon clash).
- **Skip / ref only:** most ultimate space kit.

One artist language (Quaternius low-poly) is enough for a coherent first ship if we stay inside that family for bodies and guns.

### 3.2 Raw scale findings (meters, unnormalized)

#### Characters

| Asset | Height | Width | Finding |
|-------|--------|-------|---------|
| Modular men (Punk, SWAT, Worker) | **1.85–1.97 m** | ~1.68 | **Ideal Human male baseline** |
| Modular women (Sci-Fi, Soldier) | **1.83–1.85 m** | ~1.65 | **Ideal Human female / chrome** |
| Witch | ~2.05 m | ~1.65 | Elf-F **interim** only (fantasy silhouette) |
| Elf.fbx | **~4.1 m** | ~3.2 | Usable only after **~×0.46** scale (+ restyle) |
| Orc.glb | **~3.5 m** | ~4.7 | Monster; not a player lineage |
| Giant.glb | **~4.5 m** | ~6.5 | Troll proxy after **~×0.50–0.55** |
| Yeti.glb | **~2.4 m** | ~2.6 | Closer to Troll height; still “creature” |

#### Weapons & gear

| Asset | Finding |
|-------|---------|
| Sci-fi Pistol / SMG / AR / Sniper / Grenade | Proportions **good** vs ~1.9 m human — **primary gun set** |
| Ultimate Shotgun / Assault Rifle | Pathological AABB (width ~5–6 m) — **reorient or skip** |
| Knife (RPG pack) | ~3.1 m tall — **not** a combat blade |
| **Katana** | **Missing** from tested set |

#### Props / summon

| Asset | Finding |
|-------|---------|
| Crystal / Big_Crystal | Good Lifebloom / Tangle / Resonance props |
| Lootbox | Good Null Charge device base |
| Robot_Enemy | **~0.71 m** — strong **Familiar** size |
| Streetlight / Computer | Map dressing OK |

### 3.3 Discovery gaps in the review grid

- Pack discovery only lists folders with **`.glb`**.
- **Dwarf** stand-ins are largely **FBX** → did not appear as a pack row; still a content gap for production.
- Goblin stand-ins same pattern (not a player race anyway).

### 3.4 Coverage vs inventory

| Domain | Ready to integrate? | Notes |
|--------|---------------------|-------|
| Human M/F bodies | **Yes** | Promote modular keepers |
| Elf | Partial | Scale + restyle; female weak |
| Dwarf | **No production mesh** | Must author or find GLB |
| Troll | Partial stand-in | Scale Giant; still monster look |
| Guns v1 | **Yes** | Sci-fi modular |
| Blade | **Gap** | Author / find |
| Glide harness | **Gap** | Author / kitbash |
| Grenade / Null shell | **Yes** (kitbash Null) | |
| Field props | **Yes** | Crystals |
| Familiar | **Yes** v0 | Robot_Enemy |
| Ability VFX | Code-only | Godot + Imagine |
| UI icons / HUD | Debug UI | Imagine + Kenney |
| Anims | Partial on modular | UAL/KayKit download path known |
| Maps | Graybox + cyber props | Layout labor, not pack hunt |
| Audio | Not playtested this pass | CC0 packs identified |

---

## 4. What we need to do to fill the gaps

Work is ordered for **maximum playable look** with minimum open questions.

### Phase A — Promote keepers (no new downloads)

**Goal:** Meshes actually appear on runners / weapons / fields in-game.

| # | Task | Detail | Done when |
|---|------|--------|-----------|
| A1 | Promote Human bodies | Punk, SWAT, Worker, Sci-Fi woman, Soldier → `models/characters/` | GLBs outside placeholders; attribution note |
| A2 | Promote guns | Sci-fi Pistol, SMG, AR, Sniper, Grenade → `models/weapons/` | Same |
| A3 | Promote props | Crystal, Big_Crystal, Lootbox, Robot_Enemy, cyber kit subset → `models/props/` / `env/` | Same |
| A4 | Wire WeaponRig | Assign meshes to pistol/smg/rifle/sniper/grenade nodes | Visible in arena / first person or TP |
| A5 | Wire fields / Familiar / Null | Crystal on Lifebloom/Tangle; robot on Familiar; lootbox→Null | Scenes no longer pure primitives |
| A6 | Team readability | Color band / material override / outline | Enemies vs allies readable at range |

**Estimate:** Mostly file moves + scene mesh assignment; no design unknowns.

---

### Phase B — Author two hero gaps (Blender)

**Goal:** Signature fantasy that placeholders don’t provide.

| # | Task | Spec | Done when |
|---|------|------|-----------|
| B1 | **Combat blade** | Low-poly katana, ~1.0–1.2 m blade, Quaternius edge language, grip origin, TP-readable | In `models/weapons/`, blade weapon uses it in third person |
| B2 | **Glide harness + wings** | Hard-surface fins + backpack; parents to `socket_back`; scales with torso | Visible when gliding; works on Human (then other races via socket) |

Optional same pass:

| # | Task | Spec |
|---|------|------|
| B3 | FP arms v0 | Extract/simplify modular arms; Human+Elf shared |

---

### Phase C — Lineage stand-ins (scale + restyle)

**Goal:** All four lineages visible in lobby/arena even if not final art.

| # | Lineage | Action | Target height |
|---|---------|--------|---------------|
| C1 | **Elf M** | Elf.fbx (or GLB export) × **~0.46**; cyber retexture; ear emphasis | ~1.85–2.0 m |
| C2 | **Elf F** | Witch modular interim **or** Standout7 free elf restyle | Same |
| C3 | **Troll M** | Giant × **~0.52** (or Yeti ~1.0); desaturate “monster,” add chrome/cloth | ~2.2–2.5 m |
| C4 | **Dwarf M** | **Highest remaining body risk:** Blender reshape modular human (short limbs, wide) **or** import true dwarf GLB | ~1.15–1.35 m |
| C5 | Capsules / hit zones | Per-lineage collision heights | Matches mesh feet-to-head |
| C6 | Shared sockets | `socket_hand_*`, `socket_back`, `socket_head`, `socket_chest` on every body | Guns/wings/augments attach without per-race meshes |

**Female Dwarf / Troll:** after male stand-ins (P1).

---

### Phase D — Motion & presentation

| # | Task | Source / approach |
|---|------|-------------------|
| D1 | Download Quaternius UAL / UAL2 (optional KayKit) | Locomotion + melee retarget |
| D2 | Blade swing / block / death clips | Retarget onto all bodies |
| D3 | Glide airborne pose | Short clip or wing bone + idle |
| D4 | Corpse = death pose of race body | Replace primitive corpse mesh |
| D5 | FP weapon idle/fire/reload | AnimationPlayer on viewmodels |

---

### Phase E — VFX, UI, audio (parallel tracks)

These do **not** block mesh promote, but block “feels like CounterSpell.”

| # | Task | Approach |
|---|------|----------|
| E1 | Imagine art bible (8–12 frames) | Neon chrome + Resonance crystal hybrid |
| E2 | Imagine icon sheet | Full buy roster (weapons + abilities) |
| E3 | Godot VFX pass | Repulse, Glide trail, Wraith, Slip, Null dome first |
| E4 | Kenney UI chrome + Resonance pips | Replace debug HUD gradually |
| E5 | CC0 SFX pack import | Free Firearm + Kenney sci-fi/UI |

---

### Phase F — Optional targeted downloads (only if Phase C fails)

| Need | Prospect | When to pull |
|------|----------|--------------|
| Better Elf set | Standout7 LOWPO free elves (CC0) | If scaled Quaternius Elf still unusable |
| True Dwarf | Poly Pizza / LOWPO / commission | If reshape looks wrong |
| Katana mesh | Free CC0 katana **only if** faster than Blender blockout | Prefer Blender for style match |
| Anim library | Quaternius UAL2 | Before polish playtests |

Do **not** open a new megapack hunt for Humans or sci-fi guns.

---

## 5. Gap checklist (status board)

Copy/update as work lands.

### P0 — blocks signature / full roster look

| Gap | Status | Owner path | Blocker for |
|-----|--------|------------|-------------|
| Human bodies in game | Ready to promote | Phase A | — |
| Gun meshes in game | Ready to promote | Phase A | — |
| Combat blade mesh | **Open** | Phase B1 | Melee fantasy |
| Glide harness mesh | **Open** | Phase B2 | Mobility fantasy |
| Dwarf body | **Open** | Phase C4 | 4th lineage |
| Elf production scale/restyle | **Open** | Phase C1–C2 | Elf readable |
| Troll production stand-in | **Open** | Phase C3 | Troll readable |
| Shared sockets on bodies | **Open** | Phase C6 | Cross-race Augments |

### P1 — full EA polish

| Gap | Status | Path |
|-----|--------|------|
| Familiar final art | v0 ready (robot) | A5 then polish |
| Lifebloom/Tangle hero props | Crystal v0 ready | A5 + VFX |
| Null Charge final device | Lootbox kitbash | A5 |
| Ability VFX suite | Open | Phase E3 |
| UI icons / HUD art | Open | Phase E2/E4 |
| Locomotion + blade anims | Partial | Phase D |
| FP arms | Open | B3 |
| Female dwarf/troll | Open | After C |
| Corpse = race death mesh | Open | D4 |
| CTF objective prop | Open | Kitbash device / banner |

### P2 — deferred / later

| Gap | Status |
|-----|--------|
| Minigun / Rocket meshes | Deferred design; kitbash when promoted |
| Music / ambient | Catalog only |
| 2–4 map art pass | Layout + cyber kit |
| Cosmetics | Later |

---

## 6. Compatibility reminder (do not regress)

When filling gaps:

1. **One gun set** for all races — never four race-specific ARs for EA.
2. **Glide / Smart Rig / Overclock** = sockets + materials, not Human-only armor.
3. **Familiar** does not scale with caster race.
4. **Fields / grenades / Null** are world-space shared.
5. Verify new meshes next to Human Punk at raw scale in arena (not only in normalized review grid).
6. Keep **GL Compatibility** materials simple; re-check in Godot after Blender.

---

## 7. Definition of “first art integration complete”

A practical milestone for the next sessions:

- [ ] Human M/F visible as TP bodies in arena  
- [ ] All v1 guns + grenade use promoted meshes  
- [ ] Blade mesh + third-person swing readable  
- [ ] Glide shows harness/wings  
- [ ] Elf / Dwarf / Troll stand-ins selectable (even if ugly)  
- [ ] Lifebloom/Tangle/Null/Familiar not pure debug shapes  
- [ ] Buy menu has placeholder **icons** (Imagine ok)  
- [ ] Repulse + Glide have *some* VFX (even simple)  

Meeting this does **not** require perfect race art or full SFX.

---

## 8. Recommended next session (single focus)

**Session goal:** Phase A promote + wire, then B1 blade blockout if time.

1. Create `models/characters/`, `models/weapons/`, `models/props/` keepers from list in §4 Phase A.  
2. Point `fps_controller` / weapon nodes / ability scenes at them.  
3. Arena smoke: Human + rifle + crystal field + robot Familiar.  
4. Start Blender katana matching Punk’s poly language.  
5. Update this file’s checklist as items close.

---

## 9. Artifact index

| Location | Contents |
|----------|----------|
| `docs/ASSET_INVENTORY.md` | Master needs list |
| `docs/assets/00–02_*.md` | Compatibility, sources, prospects |
| `docs/assets/03_PLAYTEST_MODEL_REVIEW.md` | Live test detail |
| `docs/assets/04_ASSET_PROGRESS_AND_GAPS.md` | **This report** |
| `.scratch/model_review_test/` | Screenshots, raw_scale_report.json |
| `.scratch/model_review_9292.log` | Godot launch log |
| `models/placeholders/` | Current harvest base (CC0 Quaternius) |
| `.mcp.json` | `GODOT_MCP_PORT=9292` |

---

## 10. One-paragraph status for stakeholders

We inventory’d the full CounterSpell art surface, mapped free/CC0 prospects, and live-tested the in-repo Quaternius set under Godot 4.7 on a dedicated MCP port (9292). Human modular characters and sci-fi modular guns measure at correct FPS scales and should be promoted into the game immediately. Signature gaps remain: combat blade and glide harness (author in Blender), Dwarf body (reshape or find), and production-quality Elf/Troll (scale + restyle stand-ins). Ability VFX, HUD icons, and full animation libraries have known fill paths and can run in parallel. No further broad asset hunting is required before integration work starts.

---

*Update §5 checklists as promote/author work lands. Prefer PRs that close a Phase A/B row over new prospect research.*
