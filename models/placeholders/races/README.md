# Player Race Placeholder Options

Mapped to **CounterSpell** races: **Human / Elf / Orc / Troll / Dwarf** × **male / female**.

Location: `models/placeholders/races/`  
Style baseline: **Quaternius** low-poly (same family as the rest of the review set).

---

## Coverage matrix

| Race | Male | Female | Notes |
|------|------|--------|-------|
| **Human** | Excellent | Excellent | Modular + animated casual/soldier/worker |
| **Elf** | Good (true Elf mesh) | Weak stand-ins | Only one dedicated `Elf.fbx`; females are witch/wizard stand-ins |
| **Orc** | Good | Gap | Quaternius Orc + Orc Enemy; no free female orc in-pack |
| **Troll** | Good stand-ins | Gap | Giant / Yeti / Demon as bulk proxies (not true trolls) |
| **Dwarf** | Weak stand-ins | Weak stand-ins | No true free dwarf in Quaternius; use short-scaled humans |
| *(bonus)* **Goblin** | Yes | Yes | Not a player race; useful short/green humanoid ref |

---

## What’s in each folder

### Human — ready to use
| Path | Files |
|------|--------|
| `human/male/` | `Casual_Male.fbx`, `Casual2_Male.fbx`, `Soldier_Male.fbx`, `Worker_Male.fbx`, `BaseCharacter.fbx`, modular GLBs (Punk, SWAT, Worker, Casual), animated men |
| `human/female/` | Matching FBX casual/soldier/worker + modular Suit / Soldier / SciFi / Worker |

**Recommendation:** Pick modular men/women for production placeholders (textured, animated-friendly). Use casual FBX for lighter prototype bodies.

### Elf
| Path | Files |
|------|--------|
| `elf/male/` | **`Elf.fbx`** (best true elf), `Wizard_standin.fbx`, wizard GLBs |
| `elf/female/` | `Witch_standin.fbx`, `Modular_Witch_standin.glb` |

**Gap:** No dedicated female elf mesh in free Quaternius set.  
**Options:** (1) Scale/recolor male Elf, (2) use Witch modular as interim, (3) grab free LOWPO Elf pack (CC0) from Standout 7 — free tier is 3 elves (Classic/Fire/Ice; genders unclear until import).

### Orc
| Path | Files |
|------|--------|
| `orc/male/` | **`Orc.glb`**, `Orc_Enemy.glb` |
| `orc/female/` | *(empty — gap)* |

**Interim female orc:** Use `goblin_standin/female/Goblin_Female.fbx` scaled up, or wait for custom/LOWPO premium.  
**Also available free (external):** [LOWPO Orc free pack](https://standout7.itch.io/orc-low-poly) (CC0, 3 orcs + weapons; mostly male-presenting).

### Troll
| Path | Files |
|------|--------|
| `troll/male/` | **`Giant.glb`** (best bulk humanoid), Yeti A/B, Demon A/B/Blue, Mech bulk stand-in |
| `troll/female/` | *(empty — gap)* |

These read more “monster/brute” than Shadowrun-style troll metahuman. Fine for **scale / hitbox / resonance tank** prototypes; plan custom or kitbash for final art.

### Dwarf
| Path | Files |
|------|--------|
| `dwarf/male/` | `Viking_Male_scale_down_standin.fbx`, `Worker_Male_scale_down_standin.fbx` |
| `dwarf/female/` | Matching female Viking/Worker stand-ins |

**Not true dwarves** — same body as humans. For prototype:
- Uniform scale ≈ **0.75–0.85** height
- Optional wider XZ scale for stockiness
- Lower camera / capsule height in controller

**Better free option (paid tier for dwarf):** [LOWPO Fantasy Heroes](https://standout7.itch.io/fantasy-heroes) free = Knight/Wizard/Hero; **Dwarf Warrior is in premium (~$3.59)**.

---

## Best free “complete set” strategy

### Path A — Stay 100% Quaternius (already in repo)
| Race | Male pick | Female pick |
|------|-----------|-------------|
| Human | Modular Punk or Casual | Modular Soldier or Suit |
| Elf | `Elf.fbx` | Modular Witch (temp) |
| Orc | `Orc.glb` | Goblin female scaled (temp) or recolor male orc |
| Troll | `Giant.glb` | Scaled Giant / Yeti (temp) |
| Dwarf | Viking male @ 0.8 scale | Viking female @ 0.8 scale |

**Pros:** One art style, already downloaded, CC0.  
**Cons:** Female elf/orc/troll and real dwarves are faked.

### Path B — Add LOWPO free packs (same stylized low-poly family)
Download free tiers (name-your-price $0) from [standout7.itch.io](https://standout7.itch.io/):

| Pack | Free content | Helps |
|------|--------------|--------|
| [Elf](https://standout7.itch.io/low-poly-elf) | 3 elves + weapons | Elf roster |
| [Orc](https://standout7.itch.io/orc-low-poly) | 3 orcs + weapons | Orc roster |
| [Fantasy Heroes](https://standout7.itch.io/fantasy-heroes) | Knight/Wizard/Hero | Human classes |
| [Female pack](https://standout7.itch.io/lowpo-female) | Medieval females | Human/Elf F |
| [Villagers](https://standout7.itch.io/villagernpc) | NPC humans | Civilians |
| [Goblins](https://standout7.itch.io/goblin-lowpoly-assets) | Goblins | Extra short race ref |

Premium (~$4) unlocks **Dwarf Warrior + Elf Archer** in Fantasy Heroes, plus more orc/elf variants.

**Pros:** Closer to full race roster; CC0; Godot-ready.  
**Cons:** Slight style drift vs Quaternius modular (both low-poly but not identical).

### Path C — Custom / Mixamo later
Use Quaternius/KayKit **Universal Base** proportions + Mixamo anims; sculpt race silhouettes in Blender (best long-term for M/F × 5 races).

---

## How to review in Godot

1. Import project (Godot 4.x imports `.fbx` and `.glb`).
2. Drag candidates into `test_arena` or the model review scene.
3. Compare side-by-side at real scales:
   - Human = 1.0
   - Elf ≈ 0.95–1.05 (slimmer)
   - Dwarf ≈ 0.75–0.85 (stocky)
   - Orc ≈ 1.05–1.15
   - Troll ≈ 1.2–1.4 (or larger for Giant mesh)

---

## License

| Source | License |
|--------|---------|
| Quaternius Ultimate Animated Character Pack (via [OpenGameArt](https://opengameart.org/content/animated-characters-pack)) | CC0 |
| Quaternius models via Poly Pizza | CC0 |
| Modular men/women already in placeholders | CC0 |
| Standout 7 LOWPO (if you add later) | CC0 (free tiers; check page) |

---

## Suggested next step

1. Open Godot and review `races/human`, `elf/male/Elf.fbx`, `orc/male/Orc.glb`, `troll/male/Giant.glb`.
2. Decide if Path A stand-ins are enough for FPS prototype, or pull free LOWPO Elf/Orc packs for better variety.
3. Budget custom or premium only for: **female orc, female troll, true dwarf M/F** (largest free gaps).
