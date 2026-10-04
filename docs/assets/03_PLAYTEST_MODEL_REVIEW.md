# Live Model Review — Prospective Assets

**Date:** 2026-07-27  
**Branch:** `feat/asset-pipeline-inventory`  
**Scene:** `res://scenes/dev/model_review.tscn`  
**MCP port:** **9292** (`GODOT_MCP_PORT=9292`, not 9090 / 19090)  
**Artifacts:** `.scratch/model_review_test/` (screenshots + `raw_scale_report.json`)  
**Godot:** 4.7.1 Compatibility · Steam init failed (expected offline) · MCP OK  

---

## 1. Session setup

| Item | Value |
|------|--------|
| Godot PID (session) | Launched with `GODOT_MCP_PORT=9292` |
| Log | `.scratch/model_review_9292.log` |
| Node MCP bridge | Patched to honor `GODOT_MCP_PORT` (src + build); `.mcp.json` sets `9292` |
| Control path | TCP JSON to `127.0.0.1:9292` (same protocol as `tests/e2e/net_smoke.py`) |

Restart the **godot** MCP server process after `.mcp.json` change so built-in `game_*` tools also hit 9292. This session used direct TCP.

---

## 2. Grid load results

| Metric | Result |
|--------|--------|
| Packs discovered (`.glb` folders) | **22** |
| Model nodes in grid | **185** |
| Runtime load | Success (all Quaternius-style placeholders) |
| Note | `model_review` **normalizes** each mesh so max dimension ≈ 2 m (browseability). Raw scales measured separately. |

### Packs present

```
characters/animated_enemies
characters/animated_men
characters/toon_shooter_kit          ← style clash (archive)
characters/ultimate_modular_men      ← Human male keepers
characters/ultimate_modular_women    ← Human female / elf-F interim
cyberpunk/cyberpunk_game_kit
cyberpunk/extra
cyberpunk/robots_mechs               ← Familiar candidate
cyberpunk/ultimate_space_kit         ← skip / ref
props/magic                          ← Lifebloom / Tangle props
props/ultimate_rpg_items             ← Knife ≠ katana
races/elf/female
races/elf/male
races/human/female
races/human/male
races/orc/male
races/troll/female
races/troll/male
weapons/scifi_gun_pack
weapons/scifi_modular_guns           ← primary gun language
weapons/ultimate_guns_pack
weapons/ultimate_guns_sample
```

**Not in grid (FBX-only / no GLB in folder):** dwarf stand-ins under `races/dwarf/` (FBX only — discovery walks for `.glb`). Goblin stand-ins same.

---

## 3. Raw scale measurements (unnormalized)

Loaded key prospects with `GLTFDocument` / `load()` **without** review normalization. Heights in meters (Y extent of mesh AABB in world space).

### Characters (lineage prospects)

| File | Height (m) | Width (m) | Verdict |
|------|------------|-----------|---------|
| `Punk.glb` (modular man) | **1.97** | 1.68 | **Human male baseline — keep** |
| `SWAT.glb` | **1.85** | 1.68 | Keep (tactical runner) |
| `Worker.glb` | **1.87** | 1.68 | Keep |
| `Sci_Fi_Character.glb` (woman) | **1.85** | 1.65 | **Human female / chrome runner — keep** |
| `Witch.glb` | **2.05** | 1.65 | Elf-F **interim** only (fantasy hat) |
| `Soldier.glb` (woman) | **1.83** | 1.65 | Keep |
| `Elf.fbx` | **4.10** | 3.24 | **Too large** — needs ~0.45–0.48 scale → ~1.9 m; not drop-in |
| `Orc.glb` | **3.48** | 4.68 | Monster bulk; **not** player; Troll kitbash only after heavy scale/reshape |
| `Giant.glb` | **4.53** | 6.47 | Troll proxy: scale ~**0.50–0.55** → ~2.3–2.5 m |
| `Yeti.glb` | **2.44** | 2.55 | Closer to Troll height; still “monster” read |

**Dwarf:** no GLB in review grid. FBX scale-down stand-ins exist on disk but were not runtime-sampled this pass.

### Weapons

| File | H / W / D (m) | Verdict |
|------|---------------|---------|
| `Scifi_Pistol.glb` | 0.56 / 0.93 / 0.18 | **Good** pistol size vs ~1.9 m human |
| `Scifi_Smg.glb` | 0.74 / 2.20 / 0.18 | SMG length OK; use as primary SMG |
| `Scifi_AR.glb` | 0.75 / 1.55 / 0.13 | **Good** rifle |
| `Scifi_Sniper.glb` | 0.55 / 2.51 / 0.18 | Long sniper — OK |
| `Scifi_Grenade.glb` | 0.30 / 0.18 / 0.14 | **Good** throwable |
| `Shotgun.glb` (ultimate) | 0.95 / **5.78** / 0.25 | **Axis/export issue** — treat as ~length-on-X; reorient in Blender |
| `Pistol.glb` (ultimate) | 1.16 / 1.82 / 0.32 | Oversized vs scifi pistol; prefer scifi modular |
| `Assault_Rifle.glb` (ultimate) | 1.60 / **5.42** / 0.20 | Same reorient need; prefer scifi modular AR |
| `Knife.glb` (rpg) | **3.11** / 0.64 / 0.26 | Fantasy prop scale; **not** combat blade |

**Blade gap confirmed:** no usable katana-scale mesh in tested set.

### Props / env / summon

| File | H (m) | Verdict |
|------|-------|---------|
| `Crystal.glb` | 0.82 | Lifebloom / field prop — good |
| `Big_Crystal.glb` | 1.65 | Hero field / objective — good |
| `Staff.glb` | 2.68 | Tall mage prop; optional Manifestation flavor |
| `Robot_Enemy.glb` | **0.71** | **Familiar-sized** chrome minion — strong candidate |
| `Lootbox.glb` | 0.51 | Null Charge device base — kitbash |
| `Computer.glb` | 1.01 | Env / console |
| `Streetlight.glb` | 2.87 | Map dressing |

---

## 4. Visual / cohesion notes (from screenshots)

- **Ultimate modular men/women** share one low-poly language, readable silhouettes, textured outfits (Punk, SWAT, Worker, Sci-Fi, Witch). Confirmed in-game as the **style spine**.
- **Toon shooter kit** sits in the same grid and reads cartoony (hazmat chibi) — **archive** per inventory; do not mix as production runners.
- Cyberpunk kit props (crates, servers, gears) sit behind character rows and match the chrome side of the hybrid world.
- Review grid normalizes scale, so **do not** use review screenshots alone for “is Giant troll-sized?” — use raw numbers above.

Screenshots:  
`.scratch/model_review_test/pack_characters_ultimate_modular_men.png`  
`.scratch/model_review_test/pack_characters_ultimate_modular_women.png`  
`.scratch/model_review_test/overview_pack0.png`  
plus `focus_*.png` / `raw_scale_lineup.png` (camera focus on raw lineup was partial; trust JSON measures).

---

## 5. Compatibility implications (validated)

| Decision | Live evidence |
|----------|---------------|
| Human bodies share one scale | Modular men/women all ~1.85–2.05 m |
| Guns can be **one set** for all races | Sci-fi modular lengths sensible vs Human; attach hand socket + optional ±scale |
| Elf FBX needs **scale + restyle**, not uniform Human resize only | 4.1 m raw; ears/proportion still separate issue |
| Giant/Orc cannot be pure “Human ×1.3” | 3.5–4.5 m and very wide — scale down + mesh reshape for Troll |
| Dwarf still **missing GLB** in review path | Promote FBX→glb or author |
| Blade / Glide not in pack | Still **author** (Blender) |
| Familiar | `Robot_Enemy` ~0.7 m fits minion better than full humanoid |
| Overclock/chrome as mesh armor | Avoid — body proportions differ once Elf/Troll scaled; stick to sockets/shaders |

---

## 6. Promote / reject shortlist

### Promote next (production folders)

| Asset | From | Action |
|-------|------|--------|
| Human M runners | modular men: Punk, SWAT, Worker, (Hoodie) | Copy → `models/characters/` |
| Human F runners | modular women: Sci_Fi, Soldier, Suit | Same |
| Gun set | scifi_modular: Pistol, Smg, AR, Sniper, Grenade | → `models/weapons/` |
| Field props | Crystal, Big_Crystal | → `models/props/` |
| Null device base | Lootbox | Kitbash → Null Charge |
| Familiar v0 | Robot_Enemy | → `models/characters/` or `props/` |
| Env dress | cyberpunk_game_kit subset | → `models/env/` |

### Scale-fix then use

| Asset | Scale (approx) | Role |
|-------|----------------|------|
| Elf.fbx | ×0.46 | Elf male stand-in |
| Giant.glb | ×0.52 | Troll male stand-in |
| Yeti.glb | ×0.95–1.0 | Alt troll bulk |

### Reject / defer for production

| Asset | Why |
|-------|-----|
| toon_shooter_kit | Style clash |
| ultimate_space_kit | Not street/Grid |
| Knife / Claymore as blade | Wrong fantasy + scale |
| ultimate_guns Shotgun/AR as-is | Bad axis / giant AABB — fix or skip |
| Orc as player race | Not a lineage; too wide |

### Still missing (confirm live)

- Katana / combat blade  
- Glide harness / wings  
- Production dwarf GLB  
- Female elf (dedicated), female troll polish  
- Lifebloom/Tangle hero art beyond crystals  

---

## 7. MCP port recipe (reuse)

```bash
# Game (asset agent)
export GODOT_MCP_PORT=9292
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/dev/model_review.tscn

# Or arena
# GODOT_MCP_PORT=9292 Godot --path . res://scenes/levels/test_arena.tscn
```

`.mcp.json` already sets `GODOT_MCP_PORT=9292` for the Node bridge. Leave **9090** free for other agents/playtests.

---

## 8. Next tests (recommended)

1. Instance Human Punk + Scifi_AR in `test_arena` at player spawn; check grip vs camera.  
2. Scale Giant ×0.52 next to Punk; capsule fit.  
3. Blender: katana 1.0–1.2 m blade length; glide fins on back socket.  
4. Import dwarf FBX → glb; re-run raw height.  
5. Download S7-ELF free tier; drop into review and re-measure.

---

*Raw numbers: `.scratch/model_review_test/raw_scale_report.json`*
