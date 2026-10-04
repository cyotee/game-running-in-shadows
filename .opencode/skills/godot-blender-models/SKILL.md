---
name: godot-blender-models
description: >
  Author and deliver 3D models for game-dcc (Godot 4.7, GL Compatibility)
  from Blender 4.5 LTS. Use when exporting glTF/glb, importing .blend into Godot,
  setting up character/weapon/prop scale and origins, materials for Compatibility
  renderer, animation NLA export, model folder layout, replacing placeholders,
  or Blender→Godot pipeline work. Triggers: glTF, glb, Blender export, Godot
  import, model review, FPS mesh, armature, low-poly asset. Slash:
  /godot-blender-models. Pair with blender-mcp when driving Blender live.
---

# Godot models from Blender (game-dcc)

## Project constraints

| Constraint | Value |
|------------|--------|
| Engine | Godot **4.7.1** (pinned) |
| Renderer | **GL Compatibility** — keep materials simple; always verify in Godot, not only EEVEE |
| Blender | **4.5.x LTS** at `/Applications/Blender.app` |
| Preferred exchange | **glTF 2.0 binary (`.glb`)** |
| Placeholders | `models/placeholders/` (CC0 Quaternius) — temporary |
| Review scene | Optional `res://scenes/dev/model_review.tscn` when added |
| Naming | Clear project names; keep assets under `models/` |

## Folder conventions

Prefer shipping production art outside placeholders:

```
models/
  characters/     # player, NPCs, creatures
  weapons/        # weapons and combat gear
  props/          # interactables and set dressing
  env/            # larger level pieces (if any)
  placeholders/   # review-only CC0; do not treat as final
```

Name files `snake_or_kebab_case.glb` (e.g. `character_player.glb`, `weapon_rifle.glb`).
Keep textures either embedded in `.glb` (default for small assets) or beside the
file with relative paths for shared atlases.

When replacing a placeholder, leave a short note in `models/placeholders/ATTRIBUTION.md`
or pack README if removing licensed files; keep final custom art attribution elsewhere if needed.

## Coordinate / facing conventions (Godot)

- Godot: right-handed, **Y-up**, camera looks down **-Z**.
- Oriented assets (characters, guns): **+Z is front** in Godot/glTF (character faces camera by default).
- In **Blender**, that maps to character facing **-Y** before export (Blender Y-forward glTF export).
- Maps/terrain: +X east, -Z north in Godot terms.

When rotating characters in code, prefer `look_at(..., use_model_front=true)` and `Vector3.MODEL_*` constants.

## Authoring checklist (before export)

1. **Scale** — 1 Blender unit = 1 m. Standing humanoid ≈ **1.7–2.0 m**. Dwarf stand-ins historically ~0.75–0.85 height scale (see `models/placeholders/races/`).
2. **Apply transforms** — Ctrl-A → All Transforms (or apply scale/rot); avoid non-uniform scale on armatures.
3. **Origin** — characters: between feet on ground plane; weapons: grip / mount point as agreed; props: contact center.
4. **Mesh** — triangulate for stable results (Triangulate modifier or export triangulate). Prefer quads while modeling; triangles on export.
5. **Modifiers** — enable **Apply Modifiers** on export (except leave armature deformation non-destructive as needed for rigs).
6. **Rest pose** — skeleton at rest/T-pose for bind; do not export a posed deform as the only bind pose.
7. **Materials** — **Principled BSDF** only for portable PBR. Enable **Backface Culling** when appropriate (Blender default off → Godot often imports cull Disabled, costing fill rate).
8. **UVs** — one clear UV set for albedo; UV2 only if lightmaps planned later.
9. **Naming** — clear data-block names (no `Cube.003` in finals). No trademark IP terms.
10. **Lighting** — do **not** rely on Blender lights in-game; light in Godot.

## glTF export settings (recommended default)

**File → Export → glTF 2.0 (.glb)**

| Area | Setting |
|------|---------|
| Format | **glTF Binary (.glb)** |
| Include | Selected Objects (when exporting one asset) or active collection |
| Transform | **+Y Up** (exporter default for Godot) |
| Data → Mesh | Apply Modifiers; UVs; normals; vertex colors if used |
| Data → Material | Export; images automatic/embedded for single-file assets |
| Animation | **NLA Strips** for authored clips; avoid dumping every unused Action |
| Armature | Prefer deformation bones for game export; shape keys need “deformation bones only” when using blend shapes |

Export destination: the appropriate `models/...` path **inside the Godot project** so import runs automatically.

### Alternative: direct `.blend` import

Godot can import `.blend` by shelling out to Blender → glTF.

- Set **Editor Settings → Filesystem → Import → Blender → Blender Path** to  
  `/Applications/Blender.app/Contents/MacOS/Blender` if auto-detect fails.
- Whole team needs Blender installed; no import on web/Android editors.
- Fine for solo fast iteration; for shared “published” assets prefer explicit `.glb`.

## Import verification in Godot

1. Focus Godot editor after adding/updating the file (import).
2. Open the `.glb` in the inspector / advanced import settings if LODs or materials need tweaks.
3. Drop into `res://scenes/dev/model_review.tscn` or `test_arena` for scale next to placeholders.
4. Check **GL Compatibility**: no missing textures, no pure-specular wildness, reasonable cull.
5. Optional: drive placement/screenshots via **Godot MCP** (`godot` server).

Collision: usually author simple colliders in Godot (Capsule/Box/Convex) rather than high-poly mesh collision from Blender unless intentionally exported.

## Animation notes

- One logical clip per NLA track (idle, run, fire, …).
- Export with NLA strips; clean unused actions.
- In Godot, prefer **AnimationPlayer** / **AnimationTree** on an instanced scene wrapper (`.tscn`) rather than editing the imported scene as the only source of truth — instance the mesh and add game nodes in a parent scene.
- FPS viewmodels may use separate lower-poly arms; third-person bodies are separate assets.

## Materials & Compatibility renderer

- Stick to base color, roughness, metallic, normal (ORM-friendly).
- Avoid complex node graphs that glTF cannot represent; bake or simplify.
- Emissive for neon/chrome accents is fine if exported; re-tune intensity in Godot.
- Shared game materials: dummy material slots in glTF + Godot material override / import script later if needed.

## Genre-specific guidance

| Asset type | Guidance |
|------------|----------|
| Character body | Readable silhouette at medium distance; head/torso hit zones matter later |
| Weapons | Clear iron sights / silhouette; origin at grip; keep polycount modest for multiplayer |
| Blade | Distinct length for melee range readability |
| Signature props | Silhouette and materials should match the game art direction |
| Env props | Match the project art direction and poly budget |

Meshes should not encode balance (e.g. do not scale a gun longer to change effective range).

## Poly / performance budget (starting targets)

Tune later with profiling; initial soft targets for Compatibility multiplayer:

| Class | Soft triangle budget (order of magnitude) |
|-------|-------------------------------------------|
| Character body | 5k–15k |
| FPS weapon | 1k–5k |
| Small prop | 0.2k–2k |
| Hero prop | higher OK if rare |

Prefer LODs only when needed; one mid-poly LOD is enough early.

## Workflow with Blender MCP

1. Load **`blender-mcp`** skill; ensure addon connected.
2. Build/edit in Blender.
3. Export `.glb` with this skill’s checklist (MCP may run export via Blender Python if reliable; otherwise instruct user / use export operator carefully).
4. Verify in Godot.

## Docs / upstream

- Godot formats: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html  
- Export considerations: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html  
- Blender Studio pipeline essay: https://studio.blender.org/blog/our-workflow-with-blender-and-godot/  
- Project review README: `models/placeholders/README.md`
