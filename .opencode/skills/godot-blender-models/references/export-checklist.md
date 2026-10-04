# Blender → Godot export checklist (game-dcc)

Quick copy for each asset ship.

## Pre-export

- [ ] Scale correct (1 unit = 1 m; humanoid ~1.7–2.0 m)
- [ ] Transforms applied
- [ ] Origin correct (feet / grip / contact)
- [ ] Facing: character front toward -Y in Blender (glTF +Z front)
- [ ] Triangulate / Apply Modifiers ready
- [ ] Armature at rest pose
- [ ] Principled BSDF materials; backface cull considered
- [ ] Names clean; no IP-violating trademarks
- [ ] No reliance on Blender-only lights or non-exported Geometry Nodes without realization

## Export

- [ ] Format: **.glb**
- [ ] Target path under `models/characters|weapons|props|env/`
- [ ] Selected objects / correct collection only
- [ ] Animation: NLA strips if animated
- [ ] Textures embedded or relative paths valid

## Godot

- [ ] Import succeeds (no errors in Output)
- [ ] Looks correct in **GL Compatibility**
- [ ] Scale check in `model_review.tscn` or arena
- [ ] Wrapper `.tscn` if game logic / collision needed
- [ ] Attribution updated if third-party
