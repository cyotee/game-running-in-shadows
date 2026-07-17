# Development Setup Guide

This document complements the README and PRD.

## 1. Godot Version
Pinned: **Godot 4.7.1 stable**. Update this file when the project standard changes.

## 2. GodotSteam (Core Dependency)

You have successfully installed the GodotSteam GDExtension (I can see the full `addons/godotsteam/` folder with platform binaries and `godotsteam.gdextension`).

Follow the latest instructions at https://godotsteam.com/ for any updates.

Key points for Godot 4.7:

1. The GDExtension should automatically make the global `Steam` class available after you restart the editor.
2. You do **not** need to manually autoload the core `Steam` object.
3. The custom wrapper script (`scripts/steamworks.gd`) is still useful for clean initialization and running callbacks.

### How to add the Steam manager as an Autoload (Godot 4.7)

**Correct path:**

1. Go to **Project → Project Settings**
2. In the left sidebar click **Globals**
3. Select the **Autoload** section (or use the search bar at the top of the window and type `autoload`)
4. Click the folder icon
5. Choose `res://scripts/steamworks.gd`
6. Set the **Name** to `SteamManager` (recommended) or `Steamworks`
7. Click **Add**

The script is now updated for Godot 4.7 + current GodotSteam GDExtension. It:
- Uses `steamInitEx()`
- Emits signals (`steam_initialized`)
- Runs callbacks safely in `_process`
- Includes useful helper methods (rich presence, achievements, etc.)
- Has clear error messages

The `[steam]` section in `project.godot` can help with some auto behavior in newer GodotSteam, but the autoload gives you explicit control and better logging.

### Verifying that GodotSteam is working

Create a temporary test script (or use the console) and try:

```gdscript
func _ready():
    if Engine.has_singleton("Steam"):
        print("Steam singleton exists!")
        print(Steam.getPersonaName())   # Should work if Steam client is running
    else:
        print("Steam not registered yet")
```

`Steam` is usually provided automatically by the GDExtension. Your `Steamworks` autoload is mainly for managing init + `_process` callbacks.

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
