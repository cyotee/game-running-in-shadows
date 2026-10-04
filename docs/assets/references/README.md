# Art references

Canonical production look for CounterSpell. Locked in `docs/PRD.md` §1 (v0.12).

## Style lock

**Cell-shaded** stylized 3D: hard color regions, inked edge breaks, readable FPS silhouettes. Charcoal tactical clothing, muted teal trim, small chrome. Not photoreal PBR, not chibi, not voxel.

| File | Use |
|------|-----|
| `style/human_male_runner_tpose_front.png` | Canonical Human male Runner T-pose front. Match new assets to this. |
| `style/human_male_runner_tpose_side.png` | Same character, left side. Mesh reconstruction aid. |
| `style/human_male_runner_tpose_back.png` | Same character, back. Mesh reconstruction aid. |

Quaternius models under `models/placeholders/` are prototyping stand-ins until replaced.

Meshes (rigged GLB, ~1.8 m):

- `models/characters/human/male/runner_tactical.glb`
- `models/characters/human/male/runner_tactical_walk.glb`

| Asset | Meshy task |
|-------|------------|
| Front | `01a07f54-c3cf-7674-8353-0ea866542a11` (text-to-image) |
| Side | `01a07f80-f045-72ee-9539-79d5c4b997c7` (image-to-image) |
| Back | `01a07f80-e815-7427-bff2-b8fd43019bdd` (image-to-image) |
| Mesh | `01a07f82-8a17-7244-9f8d-2f2ff6d12b78` (multi-image-to-3d, Meshy 7) |
| Remesh | `01a07f88-309e-734a-b70c-2835e1169fc8` (quad, 25k, 1.8 m) |
| Rig | `01a07f8a-558c-709e-a5e8-e9405c6b1392` |
