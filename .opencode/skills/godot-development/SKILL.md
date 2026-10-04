---
name: godot-development
description: Comprehensive skill for developing games and applications with Godot 4 engine. Covers setup, running projects, debugging crashes, GDExtensions (especially on macOS), GodotSteam integration, and best practices for the current project.
---

# Godot 4 Development Skill

## Purpose
This skill provides grounded, practical guidance for Godot 4 development based on official documentation and common troubleshooting patterns. Use it to:
- Set up and run Godot projects correctly.
- Diagnose and fix crashes where the game/editor window closes immediately.
- Handle GDExtensions and native addons (e.g., GodotSteam).
- Work with macOS-specific issues like quarantine and permissions.
- Follow recovery and debugging workflows.

Always prefer official docs over assumptions. Cite sources when possible.

## Core Principles from Official Docs
- Godot uses a scene-based architecture with nodes.
- Rendering: Use "gl_compatibility" for broad support (as in this project).
- Autoloads for singletons (e.g., SteamManager).
- GDExtensions for native code (like GodotSteam).
- Project crashes on launch are often due to plugins/GDExtensions, bad .gdextension, or init failures.

Key troubleshooting page: https://docs.godotengine.org/en/stable/tutorials/troubleshooting.html

## Running a Godot Project
1. Open the project in Godot 4.6+ editor (must match project's config_version and features).
2. Set main scene in Project Settings > Application > Run > Main Scene (e.g., res://scenes/levels/test_arena.tscn).
3. Press Play (F5) or use Scene > Run Current Scene.
4. From command line (for verbose logs on macOS):
   ```
   /Applications/Godot.app/Contents/MacOS/Godot --verbose --path /path/to/project
   ```
   Or to run a specific scene:
   ```
   /Applications/Godot.app/Contents/MacOS/Godot --path /path/to/project --scene res://scenes/levels/test_arena.tscn
   ```
5. For headless/testing: Use `--headless` flag.

Important: On macOS, launch Godot from the app bundle path above for full logs.

## Debugging Immediate Crashes / Window Closes on Start
From troubleshooting docs and community:

1. **Use Recovery Mode** (critical for crashing projects):
   - In Project Manager, select the project.
   - Click the dropdown next to "Edit" or "Run".
   - Choose "Edit in recovery mode".
   - This disables editor plugins, GDExtensions, and some features to isolate the cause.
   - Once open, disable suspicious addons (Project > Project Settings > Plugins).
   - Re-enable one by one.

2. **Check logs**:
   - Editor Output panel (bottom) for ERROR/SCRIPT ERROR even if window closes.
   - Run from terminal with `--verbose` or `--debug`.
   - macOS crash logs: Console.app or ~/Library/Logs/DiagnosticReports/.
   - Godot user data: ~/Library/Application Support/Godot/ (or equivalent).

3. **Common causes and fixes**:
   - **GDExtension failure** (very common with GodotSteam):
     - Rename .gdextension temporarily to test (e.g., godotsteam.gdextension.bak).
     - macOS quarantine: Run `xattr -dr com.apple.quarantine /path/to/project/addons/godotsteam/`
     - Ensure Steam client is running before Godot (for Steam init).
     - Restart editor after adding/updating GDExtension.
     - Check .gdextension for correct macos paths (debug/release).
   - **Autoload errors**: SteamManager or similar failing in _ready().
   - **Rendering**: Try switching to Compatibility renderer in Project Settings.
   - **Project file corruption**: Delete .godot/ folder and re-open (forces reimport).
   - **Missing main scene or resources**: Verify run/main_scene and imports.
   - **macOS Gatekeeper**: Drag app to Applications, or right-click > Open.

4. **For GDExtensions on macOS**:
   - Use Xcode command line tools.
   - Codesign if needed for export: `codesign --force --deep -s - path/to/dylib`
   - Architecture: Ensure universal or matching (arm64 for Apple Silicon).
   - Test with official export templates first.

5. **Steam/GodotSteam specific**:
   - Steam client must be running (background).
   - steam_appid.txt in project root for dev (contains 480 for Spacewar testing).
   - Initialization in autoload: Use steamInitEx(), check status == 0.
   - Restart editor after GDExtension install.
   - If init fails: Check Output for "Steam client not running" or GDExtension not found.
   - For multiplayer: Separate SteamMultiplayerPeer GDExtension.

## Best Practices for This Project (Running in Shadows)
- Pin to Godot 4.6 (GL Compatibility renderer).
- GodotSteam in addons/godotsteam/ — ensure all platform binaries present.
- Autoload: SteamManager from scripts/steamworks.gd.
- Main scene: scenes/levels/test_arena.tscn.
- Test with F5 in editor while Steam running.
- For debugging prototype (FPS controller, inputs): Use --verbose and check for input action errors or physics issues.
- Input map: Define actions in Project Settings > Input Map (e.g., move_*, jump, fire_primary, repulse, glide).
- If window closes on play:
  - Open in recovery mode.
  - Check for errors in fps_controller.gd or steamworks.gd _ready().
  - Verify collision shapes and nodes in test_arena.tscn.
  - Test without GodotSteam first.

## Command Line and Debugging Workflow
- Editor: Godot --editor --path .
- Run project: Godot --path . 
- Verbose + console on Mac: Use the MacOS/Godot binary.
- To capture crashes: lldb /path/to/Godot (advanced).
- Project recovery: Always try first for "instant crash on open".

## When to Escalate
- If recovery mode still crashes: Check Godot version match, reinstall editor.
- macOS Steam overlay issues: Launch via Steam or set correct AppID.
- Persistent GDExtension: Re-download GodotSteam matching Godot 4.6.
- Use official docs first: https://docs.godotengine.org/

Sources: Official Godot docs (troubleshooting, project manager, GDExtension), GitHub issues, GodotSteam docs, macOS dev forums.

Update this skill with new learnings from actual debugging sessions.