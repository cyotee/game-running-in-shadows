# Placeholder Model Review Set

Temporary **CC0** models from **Quaternius** (via [Poly Pizza](https://poly.pizza/)) for style and compatibility review.

**Total:** ~140 GLB files · ~50 MB · single artist for visual cohesion.

These are **not** final art. Keep only the packs that pass review; delete the rest.

---

## How to review in Godot

1. Open the project in Godot 4.6+.
2. Wait for imports (first open may take a minute).
3. Run scene: `res://scenes/dev/model_review.tscn`
4. Controls:
   - **WASD** / mouse — orbit the camera (same as FPS look if mouse captured)
   - **Q / E** — previous / next pack row focus
   - **R** — reload grid
   - **Esc** — free/capture mouse
5. Or open individual `.glb` files in the FileSystem dock and drag into a test scene.

---

## Packs included

| Folder | Role | Notes for *CounterSpell* |
|--------|------|--------------------------------|
| `characters/ultimate_modular_men` | Runner bodies | Strong candidate: textured modular humans (Punk, SWAT, Worker, Astronaut…) |
| `characters/ultimate_modular_women` | Runner bodies | Includes **Sci Fi Character** + Witch — good mage/chrome contrast |
| `characters/animated_men` | Simpler humans | Lower poly, flatter; useful scale/animation check |
| `characters/toon_shooter_kit` | Alt style | More cartoony — compare vs modular men (may clash) |
| `characters/animated_enemies` | Critter enemies | Snake/spider/etc. — optional PvE later, not core |
| `weapons/scifi_modular_guns` | Sci-fi firearms | **Primary gun candidate** for chrome runners |
| `weapons/scifi_gun_pack` | Futuristic guns | Ray/Lightning guns — Manifestation-flavored weapons |
| `weapons/ultimate_guns_*` | Modern firearms | Street-level guns; same low-poly language |
| `cyberpunk/cyberpunk_game_kit` | Env props | Neon street dressing (AC units, turrets, computers) |
| `cyberpunk/robots_mechs` | Chrome stand-ins | Robots/mechs for Augment / Rigger placeholders |
| `cyberpunk/ultimate_space_kit` | Hard-surface | Spaceships/rovers — style ref more than usable kit |
| `props/magic` | Spells / mage | Staff, crystals, potions, wizard meshes |
| `props/ultimate_rpg_items` | Melee/magic props | Shields, scythe, skull — secondary |

---

## Compatibility checklist

Review all packs **together** in the review scene and score:

1. **Silhouette language** — same edge hardness / blockiness?
2. **Color / material** — flat vertex colors vs textured atlases (modular characters are textured; many guns are flat).
3. **Scale** — character ~1.7–2 m tall next to a pistol/rifle?
4. **Theme mix** — cyberpunk props + fantasy staff should still feel like one world (or look intentionally hybrid).
5. **Animation readiness** — modular men/women are more production-ready than static wizards.

### Likely cohesive core set (recommendation to start)

If you want one coherent placeholder kit without mixing styles:

| Use | Pick |
|-----|------|
| Characters | `ultimate_modular_men` + `ultimate_modular_women` (Sci Fi, Punk, Witch, Soldier) |
| Guns | `scifi_modular_guns` + a few `ultimate_guns` pistols/SMGs |
| Magic props | `props/magic` staff + crystals |
| Chrome / cyber | `robots_mechs` robot limbs + `cyberpunk_game_kit` street props |
| Skip / archive | `toon_shooter_kit` (style drift), `animated_enemies` (unless needed), most of `ultimate_space_kit` |

---

## License

All models in this review set are **CC0 1.0** (public domain) from Quaternius unless a specific file’s source page says otherwise. See `ATTRIBUTION.md`.

Credit is not required but appreciated: [quaternius.com](https://quaternius.com/)

---

## After decision

1. Move keepers to final folders, e.g. `models/characters/`, `models/weapons/`.
2. Delete rejected packs to keep the repo lean.
3. Consider **Git LFS** before committing large textured characters (`*.glb` notes in root `.gitignore`).
4. Record final choices in `docs/ABILITY_TUNING_SHEET.md` or a short `docs/ART_DIRECTION.md`.
