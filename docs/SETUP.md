# Development Setup Guide

This document complements the README and PRD.

## 1. Godot Version
Pin to a specific 4.4.x or newer stable. Update this file when the project standard changes.

## 2. GodotSteam (Core Dependency)

Follow the latest instructions at https://godotsteam.com/

Typical flow:
1. Install the GDExtension via AssetLib or release zip.
2. The `.gdextension` file should be present and configured.
3. Copy Steam API binaries from the official Steamworks SDK (you need partner access for full use).
4. Test initialization using the `scripts/steamworks.gd` autoload (add it in Project Settings > Autoload).

### Development App ID
Use **480** (Spacewar) until you have a real App ID.

Create `steam_appid.txt` (gitignored) in project root containing:
```
480
```

### Project Settings Steam Section
The `project.godot` has initial values. You can also set them in editor under **Project > Project Settings > Steam**.

## 3. Multiplayer Peer
For Steam P2P:
- Use `SteamMultiplayerPeer` (separate GDExtension from the GodotSteam ecosystem, or included in newer bundles).
- See tutorials on godotsteam.com and community videos for `create_lobby`, `join_lobby`, and handing the peer to `multiplayer.multiplayer_peer`.

Dedicated servers use the server variant of GodotSteam.

## 4. Building & Exporting
- Create export presets in the editor.
- For Steam releases you will use SteamPipe (via Steamworks SDK tools or third-party like DepotDownloader / SteamCMD wrappers).
- Document your export presets and build script here later.

## 5. Git & Assets
- Large assets → consider `git lfs track`.
- Never commit personal `steam_appid.txt`.
- Run `git status` before commits — `.godot/` and imports must stay ignored.

## 6. Testing Steam Features Locally
- Steam client must be running and logged in.
- For overlay to appear, the game usually needs to be launched via Steam or have correct AppID handling.
- Friends list testing: invite friends who also have the game (or AppID 480 for early tests).

## 7. Common Gotchas
- Call `Steam.run_callbacks()` every frame from an unpausable node.
- Some features only work when the game is "subscribed" / owned in Steam.
- Editor may need restart after adding GDExtensions.

Update this document as the team learns more.
