# Compatibility, Scale & Race Fit Rules

**Companion to:** `docs/ASSET_INVENTORY.md`, `docs/assets/01_SOURCE_CATALOG.md`, `docs/assets/02_INVENTORY_PROSPECTS.md`  
**Date:** 2026-07-27  
**Goal:** Pick assets that work **together** across Human / Elf / Dwarf / Troll without dead-end modular pieces (e.g. a chrome arm that only fits a human torso).

---

## 1. Style lock (non-negotiable for harvest)

| Rule | Why |
|------|-----|
| Production spine is **cell-shaded stylized 3D** | Locked in `docs/PRD.md` §1. Canonical ref: `docs/assets/references/style/human_male_runner_tpose_front.png` |
| Quaternius low-poly remains the **prototype harvest family** | Already in-repo; replace toward the cell-shaded lock, do not treat as final look |
| Second-tier OK if **re-materialized** to match the lock | Standout7 LOWPO, KayKit, Kenney 3D — restyle albedo/edge hardness to cell-shaded charcoal + muted teal |
| Avoid mixing **toon-chibi**, **realistic PBR hero**, and **voxel** as primary characters | Instant visual clash in multiplayer |
| GL **Compatibility** materials only | Project renderer constraint |
| No trademark IP names in files or textures | Original IP |

**Primary harvest family:** Quaternius (CC0)  
**Secondary (same poly budget, retarget/retexture):** KayKit (CC0), Standout7 LOWPO free tiers (CC0), Kenney 3D (CC0)  
**Not primary characters:** pure Mixamo realism without retarget + restyle (anims only)

---

## 2. Target scales (Godot / Blender: 1 unit = 1 m)

| Lineage | Standing height (approx) | Mass / silhouette notes | Hit capsule notes |
|---------|--------------------------|-------------------------|-------------------|
| **Human** | 1.70–1.85 m | Baseline | Standard |
| **Elf** | 1.80–2.00 m | Slimmer torso/limbs; longer legs optional | Slightly taller capsule; thinner radius |
| **Dwarf** | 1.15–1.35 m | **Wide** shoulders/hips vs height; short limbs | Short capsule; **do not** only scale Human |
| **Troll** | 2.20–2.55 m | Thick torso, large head/hands | Tall + fat capsule |

**Weapon grip height** should track a shared **socket** (hand bone), not world Y, so short/tall races hold guns correctly.

---

## 3. Resize vs separate model (decision table)

### 3.1 Character bodies

| Asset | Human | Elf | Dwarf | Troll | Rule |
|-------|-------|-----|-------|-------|------|
| Full body mesh | Base | **Separate mesh preferred** (ears, proportions) | **Separate mesh required** | **Separate mesh required** | Uniform scale of Human → Elf (1.05–1.10) is OK as **temporary** only |
| Head / ears | Base | **Separate head or ear attach** | Separate head (broad) | Separate head (large) | Ear/horn detail never scales from Human |
| Hands / feet | Base | Slimmer optional | Shorter thicker | Larger | Shared gloves often fail; prefer per-race hands or loose gauntlets |
| Death / corpse | Same mesh + death pose | Same per race | Same | Same | One death clip retargeted if skeleton shared |
| First-person arms | Shared Human arms OK early | Slimmer optional | **Separate short arms** or heavy FOV cheat | **Separate bulky arms** or shared + scale (looks wrong) | FP arms: Human+Elf can share; Dwarf/Troll need variants |

**Summary:**

- **Safe uniform scale:** Human → temporary Elf height only (ears still need attach).  
- **Unsafe uniform scale:** Human → Dwarf (becomes child proportions); Human → Troll (skinny giant).  
- **Always separate body assets for production:** Dwarf, Troll, final Elf.

### 3.2 Weapons (guns + blade)

| Asset | Shared across races? | How |
|-------|----------------------|-----|
| Pistol / SMG / Rifle / Shotgun / Sniper world + viewmodel | **Yes — one mesh family** | Parent to hand socket; optional ±5–15% scale for Troll/Dwarf readability |
| Combat blade | **Yes — one mesh** | Length fixed for balance readability; Troll may use same blade (power fantasy) |
| Minigun / Rocket (deferred) | **Yes — one mesh** | Scale up slightly for Troll third-person only if needed |
| Dropped weapon props | Shared | Same mesh as world weapon |

**Do not** author four race-specific gun meshes for EA. One Quaternius sci-fi gun set + material variants is enough.

### 3.3 Equipment & wearables (critical for Augments)

| Asset | Shared? | Fit rule |
|-------|---------|----------|
| **Glide Harness / wings** | **One modular attach set** | Socket on upper back / spine; **scale with torso** (not full body root alone). Re-skin only. |
| Grenade / Null Charge (held + world) | Shared | Hand socket; no race mesh |
| Smart Rig “laser” | Shared VFX | Not a body mesh |
| Pulse Sight overlay | Shared UI/shader | Not a body mesh |
| Overclock chrome veins | Shared **shader / decal** on any body | Avoid mesh that only wraps Human UV |
| Cyber Eye implant (optional TP prop) | **Attach prop** | Head socket; scale with head bone |
| Full-body chrome plates (optional) | Prefer **shader/decal** first | If mesh armor: needs **per-race** or highly elastic modular pieces |

**Rule of thumb for Augments:**  
Implement chrome as **socketed props + materials**, never as a complete replacement mesh that assumes Human proportions. That is how an Augment stays compatible with Elf / Dwarf / Troll.

### 3.4 Placed fields, summons, world props

| Asset | Shared? | Notes |
|-------|---------|-------|
| Lifebloom node, Tangle crystal, Null field dome | Shared | World-space; no race fit |
| Familiar | Shared one mesh | Not scaled to caster race |
| CTF objective, env props | Shared | — |
| Corpse | **Per race body** | Same as character mesh |

### 3.5 Animations

| Clip type | Human / Elf | Dwarf | Troll |
|-----------|-------------|-------|-------|
| Locomotion (walk/run/jump) | Shared humanoid set + retarget | **Retarget + stride scale**; may need shorter stride clips | **Retarget + slower heavier clips** preferred |
| Weapon fire / reload (TP) | Shared | Shared retarget | Shared retarget |
| Blade swing / block | Shared | Shared (arm length retarget) | Shared |
| Glide / airborne | Shared root motion careful | Shared | Shared |
| Death | Shared | Shared | Shared |

**Animation source strategy:** One humanoid animation library (Quaternius Universal Animation Library / KayKit Character Animations / Mixamo as filler) retargeted onto each race skeleton.  
**Do not** buy four full animation sets for EA.

### 3.6 UI / VFX / SFX

All **shared** across races. Race only affects body VFX attach points (chest bone for heal, head for Pulse, etc.).

---

## 4. Skeleton / modular socket plan (compatibility backbone)

Adopt a **shared socket convention** on every playable body, even if meshes differ:

| Socket name | Bone / attach | Used by |
|-------------|----------------|---------|
| `socket_hand_r` / `socket_hand_l` | Hand | Weapons, grenade, Null Charge, blade |
| `socket_back` | Upper spine | Glide Harness wings |
| `socket_head` | Head | Eye implant prop, team marker |
| `socket_chest` | Chest | Smart Rig / Overclock glow pivot |
| `socket_hip` | Pelvis | Holstered weapon (optional) |
| `socket_foot_l/r` | Feet | Footstep dust (optional) |

If a harvested character lacks sockets, **add empty Nodes in Blender/Godot** before shipping. Augments then remain race-agnostic.

### Recommended body pipeline

```
Human male/female  ← Quaternius Ultimate Modular Men/Women (primary)
Elf male/female    ← Quaternius Elf + Standout7 free elves OR modular women SciFi/Witch restyled
Dwarf male/female  ← Dedicated short humanoid (LOWPO / Poly Pizza / Blender kitbash from scaled + reshaped modular)
Troll male/female  ← Quaternius Giant / bulk humanoid restyled (not yeti-demon if avoidable)

All share: humanoid bone map for retarget + the sockets above
```

---

## 5. What we will **not** do

- Equip a Human-only cyber arm mesh on Elf without rebinding weights.  
- Scale Human 0.75× and call it Dwarf for production.  
- Mix KayKit cute proportions as the only Troll body next to Quaternius Humans without a restyle pass.  
- Ship four unrelated gun art styles (realistic AR + toon SMG + sci-fi sniper).  
- Bake Wraith / Glide visuals into the body mesh (keep VFX separate so races share effects).

---

## 6. Quick test before accepting a prospect

1. Drop next to Human modular man in `model_review.tscn`.  
2. Same unit scale? Same edge hardness?  
3. Can a gun parent to its hand without clipping at rest?  
4. Can a simple box “wing” parent to spine and look OK if scaled with torso?  
5. License commercial OK (prefer **CC0**)?  
6. Godot Compatibility import clean?

If any fail, mark prospect as **kitbash-required** or reject.

---

## 7. Resize cheat sheet (engine)

| Situation | Transform approach |
|-----------|-------------------|
| Temporary Elf from Human | Uniform scale 1.05–1.10 + ear mesh attach |
| Temporary “tall” Troll (playtest only) | Uniform 1.25–1.35 + thicker capsule; replace mesh before EA |
| Weapon in Troll hand | Optional local scale 1.1–1.2 on weapon only |
| Weapon in Dwarf hand | Local scale 0.9–1.0; prefer no change for readability |
| Glide wings on all races | Scale wings with `socket_back` parent; author at Human size |
| Familiar | Never scale with caster |
| Fields / grenades | World scale fixed |

---

*When adding a new pack to `01_SOURCE_CATALOG.md`, note which of these rules it satisfies.*
