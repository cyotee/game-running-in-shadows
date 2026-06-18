# Running in Shadows

**A spiritual successor to the Shadowrun FPS experience — built in Godot with Steam infrastructure.**

Fast-paced cyber-fantasy first-person shooter where runners blend guns, magic, chrome, and Grid hacking.

> **Status:** Early development / repository foundation. See [docs/PRD.md](docs/PRD.md) for the full product requirements.

## Vision (Short)

- Start with competitive PvP: Arena and Capture the Flag.
- Release on Steam as Early Access.
- Later expand to co-op PvE "runs" and a single-player campaign.
- Original IP (inspired by, not affiliated with Shadowrun or its owners).

Repo name and branding deliberately avoid direct trademarks.

## Tech Stack

- **Engine:** Godot 4.4+
- **Language:** GDScript (primary)
- **Steam Integration:** GodotSteam GDExtension + SteamMultiplayerPeer
- **Networking:** Godot High-Level Multiplayer (P2P via Steam + dedicated server path)
- **Platforms:** Windows, Linux (Steam Deck support planned), macOS secondary

## Quick Start (Development)

### Prerequisites
1. Godot 4.4 or newer (editor).
2. A Steam client running in the background (for full features).
3. (Optional but recommended for real Steam features later) Steamworks partner account + App ID.

### Setup Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/game-running-in-shadows.git
   cd game-running-in-shadows
   ```

2. Open the project in Godot.

3. Install GodotSteam GDExtension:
   - Preferred: Search "GodotSteam" in the Asset Library inside Godot and install the latest compatible GDExtension version.
   - Or download manually from https://godotsteam.com/ or Codeberg releases and place in `addons/godotsteam/`.

4. Steamworks SDK binaries:
   - For local development with App ID 480 (Spacewar), the editor can often work with the plugin-provided libraries.
   - When you have real SDK access, copy the required `steam_api*.dll` / `.so` / `.dylib` into the appropriate addon subfolders (follow GodotSteam docs exactly).

5. For running outside Steam during development:
   - Create a file named `steam_appid.txt` in the project root containing just:
     ```
     480
     ```
   - **Do not commit this file** (it is gitignored).

6. **Add the Steam manager autoload** (required):
   - Go to **Project > Project Settings > Globals > Autoload**
   - Add `res://scripts/steamworks.gd` with the name `SteamManager` (recommended)

7. Restart the Godot editor after installing or updating the GodotSteam GDExtension.
8. Launch the project while the Steam client is running. Watch the Output panel for the initialization message.

The SteamManager script has been updated specifically for Godot 4.6 + latest GodotSteam.

### Verifying Steam Works
- You should see your Steam persona name or successful init logs.
- Use `Steam.run_callbacks()` (usually in an autoload `_process`).
- Test lobbies and P2P once the multiplayer systems are implemented.

See `docs/` for more detailed guides (to be expanded):
- Steam & GodotSteam setup
- Multiplayer architecture decisions
- Building dedicated servers
- Exporting for Steam

## Repository Structure

```
.
├── .github/                  # Issue templates, workflows
├── addons/                   # GodotSteam and other addons (committed)
├── assets/                   # Art, textures, materials (consider LFS)
├── audio/                    # SFX, music
├── models/                   # Or combine under assets/
├── scenes/                   # Godot scenes (organize by feature)
├── scripts/                  # GDScript (or autoloads, systems)
├── docs/                     # PRD, design docs, guides
│   └── PRD.md
├── exports/                  # Build outputs (gitignored)
├── builds/                   # Dedicated server builds etc.
├── .gitignore
├── .gitattributes
├── project.godot             # Created when you save the Godot project
├── LICENSE
└── README.md
```

We follow Godot best practices: scene-per-folder where practical, clear autoloads, documented addons.

## Current Priorities (from PRD)

1. Solid Godot + GodotSteam foundation in this repo.
2. Responsive FPS prototype (movement + shooting).
3. Multiplayer core (Steam P2P lobbies + basic replication).
4. First two modes: Arena + Capture the Flag.
5. Steam features: Overlay, achievements, cloud, rich presence.

See the [PRD](docs/PRD.md) for full roadmap, risks (especially netcode), and scope guidance.

## Contributing

TBD — for now, open issues or discussions. Code style and architecture decisions will be documented as the project grows.

Before submitting larger changes, check that they align with the PRD goals and current phase.

## Legal & Attribution

This is an original work and a **spiritual successor** only. It is not affiliated with, endorsed by, or licensed from The Topps Company, Catalyst Game Labs, Microsoft, Harebrained Schemes, Paradox, or any owners of the Shadowrun IP.

All names, lore, mechanics, and content here are original or generically inspired to capture the cyberpunk-fantasy "runner" fantasy.

## Next Steps for the Team

- Finish reading [docs/PRD.md](docs/PRD.md).
- Initialize the actual Godot `project.godot` and first scenes (FPS controller + test level).
- Set up a basic Steam autoload and verify initialization.
- Prototype a single weapon + one magic ability.
- Create first networked test (two players in same map moving around).
- Expand the docs with architecture decisions and playtest notes.

---

**Let's build something runners would be proud of.** 

Questions? Open an issue or start a discussion.