# Blender MCP (project setup)

Connects a live **Blender 4.5 LTS** session to AI agents via the
[Model Context Protocol](https://modelcontextprotocol.io/), using the open-source
server **[ahujasid/blender-mcp](https://github.com/ahujasid/blender-mcp)**.

This folder vendors only the **Blender addon** (`addon.py`). The MCP process is
started by the client via `uvx blender-mcp` (see repo-root `.mcp.json`).

## Prerequisites

| Tool | Notes |
|------|--------|
| **Blender 4.5.12 LTS** | Installed at `/Applications/Blender.app` (this machine) |
| **uv / uvx** | `brew install uv` or [astral.sh/uv](https://docs.astral.sh/uv/). Full path used in `.mcp.json` so GUI clients find it |
| **Python 3.10+** | Managed by `uvx` when launching the server |

Official Blender Lab MCP requires **Blender 5.1+** — do **not** use it with 4.5 LTS.

## One-time Blender addon install

1. Open Blender 4.5 LTS.
2. **Edit → Preferences → Add-ons → Install from Disk…** (or **Install…**).
3. Select this file:

   ```
   tools/blender-mcp/addon.py
   ```

4. Enable **Interface: Blender MCP** (or “Blender MCP”).
5. Optional: in the addon preferences, disable telemetry if shown.

Updating the addon later: re-download from upstream and replace `addon.py`, then
reinstall / re-enable if Blender does not pick up the change:

```bash
curl -fsSL -o tools/blender-mcp/addon.py \
  https://raw.githubusercontent.com/ahujasid/blender-mcp/main/addon.py
```

## Per-session connection

1. Start Blender and open your `.blend` work file.
2. In the 3D Viewport, press **N** for the sidebar → **BlenderMCP** tab.
3. Click **Connect to Claude** (starts the socket server on **localhost:9876**).
4. Ensure the agent MCP client has loaded the `blender` entry from `.mcp.json`
   (restart Grok / Claude / Cursor after editing that file if tools do not appear).
5. Only run **one** Blender MCP client connection at a time.

## Agent config (repo `.mcp.json`)

```json
"blender": {
  "command": "/Users/cyotee/.local/bin/uvx",
  "args": ["blender-mcp"],
  "env": {
    "BLENDER_HOST": "localhost",
    "BLENDER_PORT": "9876",
    "DISABLE_TELEMETRY": "true"
  }
}
```

On another machine, change `command` to that host’s `which uvx` path if needed.

## Security

- The MCP can execute **arbitrary Python inside Blender**. Save work first.
- Prefer a non-sensitive `.blend` / project when experimenting.
- Telemetry is disabled via `DISABLE_TELEMETRY=true` in `.mcp.json`.

## Pairing with Godot

1. Author / edit in Blender (optionally via Blender MCP).
2. Export **glTF Binary (`.glb`)** into `models/…` (see skill `godot-blender-models`).
3. Verify in Godot with the existing **godot** MCP and/or
   `res://scenes/dev/model_review.tscn`.

## Skills

| Skill | When to load |
|-------|----------------|
| `.grok/skills/blender-mcp/` | Connecting MCP, troubleshooting, driving Blender from the agent |
| `.grok/skills/godot-blender-models/` | Export, scale, materials, folder layout for CounterSpell |

## Upstream

- Repo: https://github.com/ahujasid/blender-mcp  
- Site: https://blendermcp.org/  
- License: see upstream `LICENSE` (MIT)
