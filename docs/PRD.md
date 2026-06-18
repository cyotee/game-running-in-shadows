# Product Requirements Document (PRD)
## Running in Shadows

**A spiritual successor FPS inspired by Shadowrun — cyberpunk meets urban fantasy.**

**Project Codename / Repo:** game-running-in-shadows  
**Working Title:** Running in Shadows  
**Status:** Draft v0.1 (Initial)  
**Date:** 2026-06-17  
**Owner:** [Project Lead]  
**Engine:** Godot 4.4+  
**Distribution:** Steam (primary)

---

## 1. Executive Summary & Vision

**Elevator Pitch:**  
Fast-paced first-person shooter set in a gritty near-future where magic has returned and megacorporations rule from the shadows. Play as a "Runner" — a deniable operative — combining modern firearms, street magic, cybernetic augmentations, and Grid hacking in competitive and (later) co-operative play.

**Core Fantasy:**  
The unique tension of Shadowrun: high-tech guns and chrome against spells, spirits, and the supernatural. A world of neon, rain, corporations, and street-level operators who get the dirty work done.

**Why Now:**  
The 2007 official Shadowrun FPS had passionate fans but limited content and is now a preservation project. The modern Shadowrun experience is almost entirely turn-based tactical RPGs. There is strong demand for a modern, fluid FPS take on the genre. Godot + GodotSteam makes a high-quality Steam release achievable for a small team without Unity/Unreal licensing friction.

**Success Vision:**  
- Ship a polished, replayable competitive PvP experience on Steam as Early Access.  
- Leverage Steam infrastructure for lobbies, achievements, progression, and community.  
- Evolve into a hybrid title with PvE "runs" and a single-player campaign over 1–3 years.  
- Build a sustainable indie commercial title while respecting the source material as a loving spiritual successor (original IP and terminology).

---

## 2. Background & Opportunity

### Historical Context
- **Shadowrun (2007)**: FASA Studio multiplayer-only FPS (Xbox 360 + PC). Class-based, objective modes, light cyberpunk elements. Criticized for lack of content (9 maps, 3 modes) despite interesting ideas. Community still plays it.
- Current official games (Harebrained Schemes / Paradox): Excellent turn-based RPG trilogy (Returns, Dragonfall, Hong Kong). Deep lore but no modern FPS.
- Genre appeal: Cyberpunk is resurgent (Cyberpunk 2077, Shadowrun TTRPG community). Magic + guns + hacking is a powerful, under-served FPS niche.

### IP Approach (Critical)
This is a **spiritual successor using original IP**.  
- No use of "Shadowrun", specific canonical megacorp names (Aztechnology, Ares, etc.), dragons, exact spell lists, or protected terminology as proper nouns.  
- Use evocative but original terms: "Runners", "the Corps", "the Grid" (for the Matrix), metahumans / specific fantasy races with original lore framing, "Awakening" or "the Merge".
- Goal: Capture the feeling and gameplay fantasy without legal risk for a public GitHub project and Steam release.

---

## 3. Goals & Success Metrics

**Primary Goals (MVP / First EA Release)**
- Deliver responsive, fun FPS core gameplay (movement, gunplay, basic abilities).
- Implement 2–3 competitive modes (Arena/Deathmatch + Capture the Flag as stated priority).
- Robust multiplayer foundation supporting both Steam P2P (lobbies/friends) and dedicated servers.
- Full Steam integration: overlay, achievements, stats, cloud, rich presence.
- Polished enough for paid or "Coming Soon" Steam page + playtests with real players.
- Professional, maintainable Git repository and Godot project structure.

**Post-EA / 1–3 Year Vision**
- PvE co-op "shadowruns" (mission-based, extraction or objective).
- Single-player campaign with narrative, hub, and runner customization.
- Progression systems (cosmetics, loadouts, unlocks) leveraging Steam features.
- User-generated content path (maps/modes via Steam Workshop if viable).
- Steam Deck verified + controller support.
- Sustainable revenue on Steam.

**Measurable Success Criteria (Examples)**
- 4–8 maps/modes in first EA release.
- Sub-100ms responsive feel on good connections (with prediction/reconciliation where needed).
- >100 concurrent players during launch window or consistent playtests.
- High "would recommend" or positive review rate in EA.
- Zero major legal/IP complaints.
- Clean, documented codebase that new contributors or future team members can onboard into.

---

## 4. Target Audience & Platforms

- **Primary:** Fans of cyberpunk, Shadowrun TTRPG, and hybrid fantasy-shooters. Players who enjoy class/ability-based PvP (think older Team Fortress, modern The Finals, or Valorant with magic).
- **Secondary:** FPS players looking for something different from military realism; Steam Deck / controller users.
- **Platforms (Phase 1):** Windows + Linux via Steam. macOS secondary. Steam Deck as day-one consideration.
- **Monetization:** Initially premium purchase (or EA pricing). Later cosmetics / battle-pass style via Steam Inventory if desired. Avoid pay-to-win.

---

## 5. Gameplay Overview & Pillars

### Core Pillars
1. **Gun + Magic + Chrome:** Primary weapons feel great. Spells are impactful but have costs/risks (essence, cooldowns, line-of-sight, counters). Cyberware grants powerful active or passive abilities with trade-offs.
2. **Asymmetric Fantasy Roles:** Archetypes (Street Samurai, Combat Mage, Decker, Rigger, Shaman, etc.) that play differently but can be viable in the same match.
3. **Tactical Mobility & Verticality:** Wall-running, grappling, spirit leaps, drone assists, hacking doors/terrain — movement is part of the power fantasy.
4. **The Grid Matters:** Hacking is not just a minigame on the side — deckers can influence the physical fight (disable cameras, open doors, stun enemies, create distractions) in real time or parallel.
5. **Gritty Noir Tone:** Dark, stylish, with humor. Rain-slicked streets, corporate brutality, runner camaraderie.

### Launch Modes (Prioritized)
- **Arena / Team Deathmatch**
- **Capture the Flag** (explicitly requested starting point)
- Later: King of the Hill / Payload / Extraction variants, then full PvE runs.

### Early Access Scope (High-Level Features)
- 3–5 archetypes with distinct gun + ability kits.
- 4–6 maps (mix of close-quarters and larger objective maps).
- Basic loadout / cosmetic unlocks.
- Matchmaking via Steam lobbies + manual server browser or direct connect for dedicated.
- Killcams / replay basics, scoreboard, voice/text chat via Steam.
- Anti-cheat considerations (start with basic server authority + report tools; evaluate VAC/EAC later).

---

## 6. Feature Roadmap (Phased)

**Phase 0 — Foundation (Current)**
- Godot 4.4+ project + GodotSteam GDExtension integrated.
- Basic FPS controller (CharacterBody3D + mouse look, sprint, crouch, jump, weapon switching).
- Weapon system (hitscan + projectiles, recoil, spread).
- Simple ability framework (fireball spell, cyber dash, hack pulse, etc.).
- Git structure, CI basics if useful, docs.

**Phase 1 — Multiplayer Core + Steam (MVP for EA)**
- Steam initialization (with dev fallback).
- Steam Lobbies + SteamMultiplayerPeer (P2P).
- Basic dedicated server path (GodotSteam Server builds).
- Authoritative or semi-authoritative replication for important state (positions with reconciliation, health, scores).
- Match flow: lobby → map vote or fixed → round → results.
- 2 modes fully playable (Arena + CTF).
- Basic UI: main menu, lobby, HUD, scoreboard.
- Steam: achievements, stats, rich presence, cloud saves.

**Phase 2 — Early Access Polish & Content**
- More maps, archetypes, weapons, VFX/SFX.
- Netcode iteration (prediction, lag compensation, bandwidth optimization).
- Progression, cosmetics, Steam Inventory hooks.
- Controller + Steam Input support.
- Steam Deck testing + verified.
- Store page, trailers, community management.

**Phase 3 — Expansion**
- PvE co-op runs (AI security forces, spirits, drones; objectives; extraction or defense).
- Single-player campaign (mission structure, light RPG choices, hub).
- Advanced Grid mechanics and cybercombat.
- Mod / map support.
- Additional monetization features.

**Out of Scope (Initial PRD)**
- Cross-play with consoles in v1 (later consideration).
- Full MMO-scale or battle-royale.
- VR (unless strong pivot).
- Official Shadowrun license or direct lore copy.

---

## 7. Technical Architecture & Constraints

### Engine & Core
- **Godot 4.4 or newer** (GDExtension support, improved 3D, Multiplayer API).
- Primary language: GDScript (fast iteration). Evaluate C# for performance-critical netcode later if needed.
- 3D rendering: Forward+ or Mobile renderer as appropriate. Target 60+ fps on mid-range hardware + Steam Deck.
- Physics: Godot 3D physics (or Jolt if addon provides better determinism).

### Multiplayer & Networking (Key Challenge)
- Godot High-Level Multiplayer API (MultiplayerSynchronizer, Spawner, RPCs).
- Transport options:
  - **Primary dev path:** SteamMultiplayerPeer (GodotSteam ecosystem) for seamless P2P via Steam relay + friends.
  - Dedicated servers using GodotSteam Server variant.
- **FPS Netcode Realities:** Built-in replication is a good start but competitive FPS usually requires client prediction + server reconciliation + lag compensation. Plan to evaluate or integrate community solutions (e.g. netfox or custom) early.
- Topology: Start with small player counts (4v4–8v8). Scale later.
- Anti-cheat: Server authority for damage/score. Consider future Easy Anti-Cheat or custom + player reports. VAC requires additional integration work.

### Steam Infrastructure
- **GodotSteam GDExtension** (current recommended: 4.19+ or latest compatible with Godot 4.4+).
- Required Steamworks features (roadmap):
  - Steam Overlay
  - Lobbies & Matchmaking (via lobbies + P2P)
  - Achievements & Stats
  - Cloud
  - Rich Presence
  - Leaderboards (optional early)
  - Inventory & DLC hooks (post-EA)
  - Steam Input
- **Development without paid app yet:**
  - Use AppID **480** (Spacewar) for local testing and editor.
  - `steam_appid.txt` (gitignored) in project root for editor/standalone runs.
  - Full Steamworks SDK access requires Steamworks partner signup + $100 Steam Direct fee per app (recoupable after $1,000 revenue).
- Dedicated server: Use GodotSteam Server builds. Document how to package and run headless.

### Asset & Pipeline
- Models: Blender → glTF 2.0 (embedded or separate).
- Audio: Godot import pipeline; consider OpenAL or built-in.
- Version control: Git + Git LFS for large binaries (audio, models, textures). Document in README.
- Addons policy: Minimal. Document every addon with license and update process. GodotSteam is core.

### Performance & Quality
- Target: Smooth 1080p/60 on recommended specs.
- Accessibility: Remappable controls, colorblind options, subtitles, reduced motion where possible.
- Localization: Plan for English first; structure strings for easy translation.

---

## 8. Development Environment & Setup (Steam / GodotSteam)

See also `README.md` for step-by-step.

**Minimum for contributors:**
1. Godot 4.4+ (or exact version pinned in project).
2. Clone repo.
3. Add GodotSteam GDExtension (AssetLib or manual from godotsteam releases).
4. Obtain Steamworks SDK redistributables (after partner access) and place per GodotSteam docs.
5. For local non-Steam testing: Place `steam_appid.txt` containing `480`.
6. Run Steam client in background for full features during dev.

**When you have a real AppID:**
- Update Project Settings → Steam → Initialization.
- Remove or gitignore steam_appid.txt for release builds.
- Register the app in Steamworks, set up store page, build pipelines with SteamPipe.

Detailed GodotSteam initialization, callbacks, lobbies, and multiplayer peer setup will live in code + dedicated docs/ guides.

---

## 9. Risks, Assumptions & Dependencies

**High Risks (Address Early)**
- **Netcode quality for competitive FPS.** This is the hardest part for small teams. Prototype multiplayer feel immediately. Budget time for iteration and possibly custom prediction code.
- **Content production (art, animation, sound, VFX, maps).** Placeholder art will get you far in prototype, but EA requires significant investment. Plan outsourcing or very strong solo artist.
- **Scope creep.** PvP + dedicated servers + later PvE + SP is a lot. Ruthlessly cut for first release.
- **IP / legal missteps.** Stick strictly to original IP. Have a second pair of eyes review names/lore before public builds.
- **Steam review & discoverability.** EA games need strong vertical slice + marketing.

**Assumptions**
- Small team can deliver tight, fun core loop in 6–12 months of focused work.
- Players will accept "spiritual successor" branding and original setting.
- GodotSteam remains actively maintained (it is, as of 2026 research).
- We can reach acceptable netcode with Godot's tools + community help.

**Dependencies**
- GodotSteam + SteamMultiplayerPeer GDExtensions.
- Steamworks partner account (future).
- Quality free or commissioned assets that fit the tone.
- Community playtesters (Discord, Steam forums).

---

## 10. Legal, Licensing & Publishing Notes

- Game will be released under appropriate license for code/assets (MIT for code to start; asset licenses documented).
- No claim of official affiliation with Shadowrun, Catalyst Game Labs, Topps, Microsoft, Harebrained, or Paradox.
- Store page and marketing must clearly position as "inspired by" or "spiritual successor."
- Follow Steam Direct process: $100 fee per app (recoupable), tax/bank setup, 30-day review period in some cases, content review.
- Age rating, privacy policy (for any telemetry or Steam data usage), and accessibility statements required for Steam.

---

## 11. High-Level Timeline (Indicative — Adjust in Planning Docs)

- **Month 0–2:** Repo + GodotSteam setup, basic FPS prototype (single player + local multiplayer), first abilities.
- **Month 2–5:** Networked PvP foundation (lobbies, sync, one mode playable over internet), Steam features core.
- **Month 5–9:** Second mode (CTF), more archetypes/maps, polish, internal + closed playtests.
- **Month 9–12+:** Early Access launch prep, marketing assets, more content, dedicated server support.
- **Year 1–2 (Post EA):** PvE, campaign foundations, live ops.
- **Year 2–3:** Full features, expansions.

Use shorter milestones in actual project tracking (GitHub issues, project board).

---

## 12. Appendices & References

**Key External Resources (to be kept up-to-date)**
- GodotSteam: https://godotsteam.com/ (initialization, lobbies, multiplayer peer)
- Steamworks docs: https://partner.steamgames.com/
- Godot 4 Networking: Official high-level multiplayer docs + community FPS tutorials (DevLogLogan style, netfox, etc.).
- Shadowrun lore (for inspiration only): Use wikis and books for tone/feel, never copy protected text or names.
- Git best practices: Godot official version control docs + github/gitignore Godot template.

**Related Internal Docs (to create)**
- Technical Design / Architecture doc
- Game Design Document (GDD) with detailed archetype kits, map specs, economy
- Art bible / style guide
- Contribution guide
- Steam build & deployment runbook

---

**End of Initial PRD.**  
This document will evolve. Update version history below.

**Version History**
- v0.1 — 2026-06-17 — Initial draft after research and requirement clarification. Focused on PvP starting point, Steam + Godot, spiritual successor approach, realistic scope warnings.