---
name: blender-mcp
description: >
  Drive a live Blender 4.5 LTS session via the project Blender MCP server
  (ahujasid/blender-mcp). Use when connecting or troubleshooting Blender MCP,
  creating or editing meshes/materials/scenes in Blender from the agent,
  running Blender Python through MCP, installing the BlenderMCP addon, or when
  the user mentions Blender MCP, uvx blender-mcp, Poly Haven via Blender, or
  viewport control of Blender. Slash: /blender-mcp. Pair with godot-blender-models
  when exporting assets for Godot.
---

# Blender MCP (game-dcc)

## When this applies

- User wants AI-assisted modeling **inside Blender**
- Need to inspect or modify the current Blender scene
- Setup / connection failures for Blender MCP
- **Not** for Godot glTF import rules alone — load **`godot-blender-models`** for export/pipeline

## Stack (this repo)

| Piece | Location / value |
|-------|------------------|
| MCP client config | `.mcp.json` → server key **`blender`** |
| Server launch | `uvx blender-mcp` (full path to `uvx` in config) |
| Socket | `localhost:9876` (`BLENDER_HOST` / `BLENDER_PORT`) |
| Addon (vendored) | `tools/blender-mcp/addon.py` |
| Setup notes | `tools/blender-mcp/README.md` |
| Blender binary (macOS) | `/Applications/Blender.app/Contents/MacOS/Blender` |
| Project Blender version | **4.5.12 LTS** (not 5.1 Lab MCP) |
| Telemetry | Disabled via `DISABLE_TELEMETRY=true` |

Godot is a **separate** MCP (`godot` in `.mcp.json`). Do not expect Blender tools under the Godot server.

## Prerequisites before tool calls

1. **Blender is open** with a file the user cares about (or a scratch `.blend`).
2. Addon installed once: Preferences → Add-ons → Install → `tools/blender-mcp/addon.py` → enable **Blender MCP**.
3. Sidebar (**N**) → **BlenderMCP** → **Connect to Claude** (socket listening).
4. Agent has reloaded MCP config so `blender` tools exist (`search_tool` for blender if unsure).

If tools fail with connection refused / timeout: the addon is not connected, or port 9876 is blocked/in use. Ask the user to click Connect again; do not assume a headless Blender without the addon.

## Operating rules

1. **Save first** — `execute_blender_code` (and similar) can destroy work. Prefer explicit save paths under the project or user-confirmed locations.
2. **Small steps** — create geometry, verify with scene info / screenshot, then materials/transforms. Break complex builds into ticks.
3. **Units** — Blender default 1 unit = 1 meter for this game. Characters ~1.7–2.0 m tall.
4. **IP** — Use clear, project-appropriate names in object, material, and file names.
5. **Export is separate** — MCP models in Blender; game-ready delivery is **export `.glb`** (see `godot-blender-models`). Do not leave assets only in `.blend` unless the user asked for direct `.blend` import.
6. **One MCP client** — avoid two clients fighting the same Blender socket.
7. **Optional asset APIs** (Poly Haven, Sketchfab, Hyper3D, etc.) — only if the user wants them; respect licenses and do not commit proprietary third-party assets without attribution notes.

## Typical agent workflow

```
1. Confirm Blender MCP tools available
2. get_scene_info / list objects (or equivalent tool)
3. Create or edit objects with clear names (e.g. weapon_smg_body)
4. Apply Principled BSDF-friendly materials
5. Apply transforms; set origin sensibly (feet center for characters, grip for weapons)
6. Screenshot / describe for user approval
7. Hand off to godot-blender-models for glTF export + Godot verify
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `spawn uvx ENOENT` | Config must use absolute `uvx` path (`which uvx`); restart client |
| Connection timeout | Addon Connect button; check port 9876 free; one client only |
| Tools missing | Reload `.mcp.json`; ensure server key is `blender` |
| Python / dep install fails | `uv cache clean blender-mcp`; pin `--python 3.11` if needed |
| Wrong Blender version docs | Ignore official Lab MCP (needs 5.1+); stay on community blender-mcp |

Upstream: https://github.com/ahujasid/blender-mcp

## After modeling

Load **`godot-blender-models`** and export to the correct `models/` path, then verify with Godot MCP or `res://scenes/dev/model_review.tscn`.
