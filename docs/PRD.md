# Product Requirements Document (PRD)
## CounterSpell

**A spiritual successor FPS inspired by Shadowrun — cyberpunk meets urban fantasy.**

**Project Codename / Repo:** game-running-in-shadows  
**Working Title:** CounterSpell (named 2026-07-16 — a play on our Counter-Strike inspiration and the counter-web design)  
**Status:** Draft v0.7  
**Date:** 2026-07-16  
**Owner:** [Project Lead]  
**Engine:** Godot 4.7.1 (pinned)  
**Distribution:** Steam (primary)

---

## 1. Executive Summary & Vision

**Elevator Pitch:**  
Fast-paced first-person shooter set in a gritty near-future where magic has returned and megacorporations rule from the shadows. Play as a "Runner" — a deniable operative — combining modern firearms, street magic, cybernetic augmentations, and Grid hacking in competitive and (later) co-operative play.

**Core Fantasy:**  
The unique tension of Shadowrun: high-tech guns and chrome against spells, spirits, and the supernatural. A world of neon, rain, corporations, and street-level operators who get the dirty work done.

**Why Now:**  
The 2007 official Shadowrun FPS had passionate fans but limited content and is now a preservation project. The modern Shadowrun experience is almost entirely turn-based tactical RPGs. There is strong demand for a modern, fluid FPS take on the genre. Godot + GodotSteam makes a high-quality Steam release achievable without Unity/Unreal licensing friction — and AI-assisted development (implementation + automated testing agents) makes the scope tractable for a solo developer.

**Team Reality (v0.4):**  
This is a **solo project built with AI agents** (Claude Code performs implementation and automated testing against the running game). Scope, timeline, and success metrics throughout this document are calibrated to that reality: quality-gated milestones over calendar dates, playtest quality over player counts, and ruthless content scoping.

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
- Deliver responsive, fun FPS core gameplay (movement, gunplay, basic abilities) with **client prediction from day one** — movement tech is a pillar, so networked feel is non-negotiable.
- Implement 2 competitive modes: Arena/Deathmatch + Capture the Flag.
- Multiplayer foundation on Steam P2P (lobbies/friends); dedicated servers deferred to Phase 2.
- Full Steam integration: overlay, achievements, stats, cloud, rich presence.
- Polished enough for paid or "Coming Soon" Steam page + playtests with real players.
- Professional, maintainable Git repository and Godot project structure with automated test coverage (GdUnit4 + live-game agent testing).

**Post-EA / 1–3 Year Vision**
- PvE co-op "shadowruns" (mission-based, extraction or objective).
- Single-player campaign with narrative, hub, and runner customization.
- Progression systems (cosmetics, loadouts, unlocks) leveraging Steam features.
- User-generated content path (maps/modes via Steam Workshop if viable).
- Steam Deck verified + controller support.
- Sustainable revenue on Steam.

**Measurable Success Criteria (rightsized for solo + AI, v0.4)**
- 2–4 maps and 2 modes in first EA release, each polished rather than numerous.
- Sub-100ms responsive feel on good connections (client prediction + reconciliation).
- A recurring playtest cohort (8–16 players) that comes back voluntarily; positive qualitative feedback on movement/combat feel.
- The signature movement tech (Repulse + Glide launch) is cited by playtesters as a highlight.
- High "would recommend" or positive review rate in EA.
- Zero major legal/IP complaints.
- Clean, documented codebase with automated tests that new contributors or future team members can onboard into.

---

## 4. Target Audience & Platforms

- **Primary:** Fans of cyberpunk, Shadowrun TTRPG, and hybrid fantasy-shooters. Players who enjoy class/ability-based PvP (think older Team Fortress, modern The Finals, or Valorant with magic).
- **Secondary:** FPS players looking for something different from military realism; Steam Deck / controller users.
- **Platforms (Phase 1):** Windows + Linux via Steam. macOS secondary. Steam Deck as day-one consideration.
- **Monetization:** Initially premium purchase (or EA pricing). Later cosmetics / battle-pass style via Steam Inventory if desired. Avoid pay-to-win.

---

## 5. Gameplay Overview & Pillars

### Core Pillars
1. **Gun + Magic + Chrome:** Primary weapons feel great. Manifestations are impactful but have costs/risks (Resonance, cooldowns, line-of-sight, counters). Augments grant powerful active or passive abilities with trade-offs.
2. **Asymmetric Lineages, Open Builds:** Four lineages (Human, Elf, Dwarf, Troll) with distinct passives and stats — but abilities and weapons are bought per round by anyone, so roles emerge from purchases, not locked classes. Loadouts are shopping-list shortcuts, never restrictions (see "Loadouts" below and MECHANICS_REFERENCE.md).
3. **Tactical Mobility & Verticality:** Repulse launches, glide descents, blinks, leaps — movement tech is part of the power fantasy and a core skill expression.
4. **The Grid Matters (Post-EA):** Hacking that influences the physical fight (disable cameras, open doors, stun enemies, create distractions) remains a defining long-term pillar, but ships **no earlier than Phase 3**. EA contains no Grid mechanics; the Decker archetype and Grid systems are designed then.
5. **Gritty Noir Tone:** Dark, stylish, with humor. Rain-slicked streets, corporate brutality, runner camaraderie.

### Launch Modes (Prioritized)
- **Arena / Team Deathmatch**
- **Capture the Flag** (explicitly requested starting point)
- Later: King of the Hill / Payload / Extraction variants, then full PvE runs.

### Early Access Scope (High-Level Features)
- 4 lineages (Human, Elf, Dwarf, Troll) with distinct passives; shared buy-phase pool of Manifestations, Augments, and weapons (see MECHANICS_REFERENCE.md).
- 2–4 maps (mix of close-quarters and larger objective maps), each polished.
- Loadout system (see below) + basic cosmetic unlocks.
- Matchmaking (decided 2026-07-16): Steam lobbies with friends + overlay invites AND an in-game public lobby browser (filterable `requestLobbyList`). Players may join mid-match: they connect, spectate until the current round ends, then buy in. **True host migration** — if the P2P host drops, a surviving peer assumes authority and the match continues. Cap: 16 players (8v8), a MatchConfig tunable.
- Scoreboard and post-round stats; killcams/replays deferred to Phase 2. Voice/text chat via Steam.
- Anti-cheat per the layered decision in §7: validation discipline from day one; EAC + Steam ban infrastructure land at EA launch.

### Loadouts (Shopping-List Shortcuts) — decided 2026-07-15
Loadouts are **ordered shopping lists, not classes or kits**. They are never mutually exclusive and never restrict what a player can buy or use.

- The game ships with **default loadouts**; players can **define and save their own**.
- Each loadout is a list of items (weapons, Manifestations, Augments) in a **player-configured priority order**.
- **Purchase semantics:** buying a loadout walks the list in priority order and purchases each item the player does not already own and can still afford. Items already owned are skipped; when funds run out, remaining items are simply not bought.
- Selecting a loadout when all its items are owned does nothing.
- Loadouts pair with **loadout-specific binding config sets** (see MECHANICS_REFERENCE.md §11) so a saved loadout can carry its own key/controller mappings.
- Open tuning question: when an item is unaffordable, whether to stop or skip-and-continue down the list (current design: skip and continue) — validate in playtests.

---

## 6. Feature Roadmap (Phased)

**Phase 0 — Foundation (Current)**
- Godot 4.7.1 project + GodotSteam GDExtension integrated. ✅
- Basic FPS controller (CharacterBody3D + mouse look, sprint, jump; Repulse + Glide prototype). ✅ (crouch, weapon switching pending)
- Testing infrastructure: GdUnit4 + SceneRunner suites, live-game agent testing via godot-mcp. ✅
- **Netcode spike: integrate netfox (or equivalent) and rebuild the FPS controller on predicted movement** — before more gameplay code accrues on the unpredicted controller. ✅ (see docs/superpowers/plans/2026-07-15-netfox-integration.md)
- Weapon system (hitscan + projectiles, recoil, spread). ✅ (hitscan framework + Pistol/SMG/Shotgun/Rifle/Sniper + Combat Blade melee/third-person; projectiles and view-kick recoil in follow-ups)
- Resonance resource system + ability framework (Repulse, Glide Harness first; see MECHANICS_REFERENCE.md §10). ✅ (Resonance + costs + archetype stats; framework grows with each Manifestation)
- Git structure, CI (headless test runs), docs.

**Phase 1 — Multiplayer Core + Steam (MVP for EA)**
- Steam initialization (with dev fallback). ✅ (SteamManager autoload)
- Steam Lobbies + SteamMultiplayerPeer (P2P). ✅ code-complete 2026-07-19 (GodotSteam 4.20.1; SessionManager + lobby browser + 16-player match session + join-in-progress spectators; live two-machine Steam verification pending)
- **Client prediction + server reconciliation from day one** (netfox: predicted movement, snapshot interpolation, lag compensation), host-authoritative over Steam P2P.
- Buy phase + economy + loadout system (shopping-list semantics, §5).
- Match flow: lobby → map vote or fixed → buy phase → round → results.
- Anti-cheat Layer 1: authority-side validation rules written with each mechanic (movement caps, Resonance costs, cooldowns); input-trace logging hooks.
- 2 modes fully playable (Arena + CTF with variable objective item).
- Basic UI: main menu, lobby, buy menu, HUD (Resonance display), scoreboard.
- Steam: achievements, stats, rich presence, cloud saves.

**Phase 2 — Early Access Polish & Content**
- More maps, weapons, VFX/SFX; remaining lineage passives tuned.
- Dedicated server path (GodotSteam Server builds) + server browser.
- Netcode iteration (bandwidth optimization, host-migration or server fallback).
- Killcams/replay basics.
- Progression, cosmetics, Steam Inventory hooks.
- Steam Input action manifest + per-game Deck configs (native controller support shipped in Milestone A ✅ — decided 2026-07-16 for early testability).
- Steam Deck testing + verified.
- Anti-cheat Layer 2: EAC via EOS (P2P client-protection + Proton flag), Steamworks game bans + player reporting, VAC baseline. EAC runs only in release/public builds — dev builds stay unprotected so tooling (godot-mcp, debuggers) keeps working.
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
- **Godot 4.7.1 (pinned; 4.7 or newer)** (GDExtension support, improved 3D, Multiplayer API).
- Primary language: GDScript (fast iteration). Evaluate C# for performance-critical netcode later if needed.
- 3D rendering: Forward+ or Mobile renderer as appropriate. Target 60+ fps on mid-range hardware + Steam Deck.
- Physics: Godot 3D physics (or Jolt if addon provides better determinism).

### Multiplayer & Networking (Key Challenge)
- **Committed architecture (v0.4): client prediction + reconciliation from day one**, built on netfox (or equivalent if evaluation fails) over Godot's High-Level Multiplayer API. Rationale: movement tech (Repulse launches, glide, blinks) is a core pillar — retrofitting prediction onto unpredicted movement code means rewriting it; building on it from the start does not.
- Transport & topology (updated 2026-07-16):
  - **MVP:** GodotSteam 4.20+ built-in MultiplayerPeer (merged upstream; separate extension retired), P2P via Steam relay; the lobby host is the authority. Fallback transport if it misbehaves: expressobits/steam-multiplayer-peer (Steam Sockets). ENet path retained for dev/E2E testing.
  - **Player cap: 16 (8v8)** as a MatchConfig tunable. Risk: host upload at 60 tps × 15 connections is unproven — measure in playtests; the knobs are tickrate, state-property count, and the cap itself.
  - **Session resilience (decided):** join-in-progress (spectate → buy in at next round) and **true host migration** on host loss. Migration requires a feasibility spike (netfox authority handoff + peer re-mesh) before its implementation plan is written; graceful match-end is the interim behavior until it lands.
  - **Phase 2:** Dedicated servers using GodotSteam Server variant.
- Physics-heavy abilities (Repulse impulses, glide state, persistent objects like Lifebloom/Tangle) must be designed as predicted-or-reconciled from the outset — see MECHANICS_REFERENCE.md §10 Netcode Considerations.
- **Anti-cheat (decided 2026-07-16)** — layered, matching the P2P → dedicated topology:
  - **Layer 1 (Phase 0–1, free, built-in):** authority-side validation written alongside each mechanic in the netfox tick simulation — movement caps, Resonance costs, cooldowns, no client-reported hits — plus structured input-trace logging so behavioral (aimbot/impossible-input) detection is possible later without a client footprint.
  - **Host-gap honesty:** in P2P the authority is a player's machine; host authority protects everyone *except from the host*. MVP mitigations: P2P play is friends/lobbies (chosen hosts); cross-match progression lives in Steam stats/cloud (never host-writable); clients log/flag physically impossible host behavior. Dedicated servers (Phase 2) are the trust escape hatch for players who want a neutral authority.
  - **Layer 2 (Phase 2 / EA launch):** **Easy Anti-Cheat via Epic Online Services** (free) using the epic-online-services-godot GDExtension — client-protection in **P2P mode** (every peer including the host is validated) and server mode for dedicated; enable the Wine/Proton flag for Steam Deck/Linux. Plus Steamworks `ICheatReportingService` game bans + player reporting; enable VAC's module as a free baseline.
  - **Rejected:** BattlEye (paid, enterprise-oriented); open-source client-side anti-cheat (structurally ineffective); GD Anti Cheats for multiplayer — its value-obfuscation streams conflict with netfox rollback state properties, don't address FPS cheats (aimbot/wallhack), and duplicate a weaker version of EAC's memory protection. Revisit GD Anti Cheats only if the Phase 3 single-player campaign stores local saves worth protecting (its actual design domain).

### Steam Infrastructure
- **GodotSteam GDExtension** (current recommended: 4.19+ or latest compatible with Godot 4.7+).
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
1. Godot 4.7.1 (the pinned project version — see `docs/SETUP.md`).
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
- **Netcode quality for competitive FPS.** Mitigation committed (v0.4): netfox-based prediction from day one, starting with a Phase 0 spike that rebuilds the FPS controller on predicted movement before more gameplay accrues. Residual risk: netfox fit for physics-impulse abilities (Repulse) — validate in the spike.
- **Content production (art, animation, sound, VFX, maps).** The single biggest solo-developer risk. Current mitigation: cohesive CC0 placeholder set (Quaternius) for all prototyping; budget for commissioned/outsourced art before any public build. Maps rightsized to 2–4 for EA.
- **Scope creep.** PvP + dedicated servers + later PvE + SP is a lot for a solo developer even with AI agents. Ruthlessly cut for first release; the Grid pillar is already deferred to Phase 3.
- **IP / legal missteps.** Stick strictly to original IP. Have a second pair of eyes review names/lore before public builds.
- **Steam review & discoverability.** EA games need strong vertical slice + marketing.
- **Bus factor / burnout (solo).** Keep the repo, docs, and tests good enough that the project survives gaps in momentum and can onboard collaborators at any point.

**Assumptions**
- A solo developer + AI agents (implementation, automated testing against the running game) can deliver a tight, fun, networked core loop; the timeline is quality-gated rather than fixed (see §11).
- Players will accept "spiritual successor" branding and original setting.
- GodotSteam and netfox remain actively maintained (both are, as of mid-2026).
- We can reach acceptable netcode with Godot's tools + community solutions.

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
- **Title diligence (2026-07-16):** "CounterSpell" adopted as the working title. Known existing uses: two Steam titles ("Counterspell" app 2211960, an arcade endless-runner; "Counter Spell" app 351230, an older RPG/stealth hybrid), a Hack Club game-jam brand, and a TCG store — the word itself is generic fantasy-gaming vocabulary (WotC owns Counterspell *cards*, not the word as a game title). Before the Steam page: run a formal trademark screen, and plan a **distinguishing subtitle** (e.g. "CounterSpell: [subtitle]") for discoverability and mark distinctiveness.

---

## 11. High-Level Timeline (Quality-Gated — Solo + AI Cadence)

Project start: June 2026. Milestones advance when their quality gate is met, not on calendar dates; the durations below are rough planning guides only.

- **Milestone A — Predicted Core (next):** netfox spike passes — FPS controller rebuilt on predicted movement, Repulse + Glide combo feels right over simulated latency. Resonance resource + first weapon.
  - *Gate:* the signature combo is testable over a network and still feels good.
- **Milestone B — Networked Loop:** Steam lobbies (friends + invites + public browser) + P2P, Arena mode playable end-to-end with friends over the internet, buy phase + loadouts functional, join-at-next-round spectating. Host-migration spike runs here; migration itself may land in Milestone C.
  - *Gate:* a full match with remote players completes without manual intervention, including a mid-match joiner entering at a round boundary.
- **Milestone C — Two Modes + Playtests:** CTF with variable objective item, 2 polished maps, recurring external playtest cohort.
  - *Gate:* playtesters return voluntarily and movement/combat feel scores well.
- **Milestone D — EA Launch Prep:** Steam page, marketing assets, achievements/cloud/rich presence complete, EAC/EOS integration + Steam ban wiring, content polish.
  - *Gate:* vertical slice strong enough to justify the Steam Direct fee and public scrutiny; anti-cheat verified on Windows and Steam Deck/Proton.
- **Post-EA:** dedicated servers, more content, then PvE / campaign / Grid (Phase 3).

Use shorter milestones in actual project tracking (GitHub issues, project board).

---

## 12. Appendices & References

**Key External Resources (to be kept up-to-date)**
- GodotSteam: https://godotsteam.com/ (initialization, lobbies, multiplayer peer)
- Steamworks docs: https://partner.steamgames.com/
- Godot 4 Networking: Official high-level multiplayer docs + community FPS tutorials (DevLogLogan style, netfox, etc.).
- Shadowrun lore (for inspiration only): Use wikis and books for tone/feel, never copy protected text or names.
- Git best practices: Godot official version control docs + github/gitignore Godot template.

**Source Game Research — Shadowrun (2007 FPS) mechanics** (see Appendix 12.A for the raw reference):
- Shadowrun 2007 FPS — Shadowrun Wiki (Fandom): https://shadowrun.fandom.com/wiki/Shadowrun_2007_FPS
- Shadowrun (2007 video game) — Wikipedia: https://en.wikipedia.org/wiki/Shadowrun_(2007_video_game)
- Shadowrun (2007) — Hardcore Gaming 101: https://www.hardcoregaming101.net/shadowrun-2007/
- Shadowrun Q&A: Magical Races, Abilities, and Technology — GameSpot: https://www.gamespot.com/articles/shadowrun-qanda-magical-races-abilities-and-technology/1100-6165066/

See [docs/MECHANICS_REFERENCE.md](MECHANICS_REFERENCE.md) for how we are translating this inspiration into original systems and numbers.

---

## 12.A Source Game Mechanics Reference — Shadowrun (2007 FPS) (Raw Reference)

> **Purpose:** A verified reference of the mechanics from the original **Shadowrun (2007)** FASA Studio FPS.  
> This is research/inspiration only. See [MECHANICS_REFERENCE.md](MECHANICS_REFERENCE.md) for our actual design decisions, original names, and proposed numbers.  
> Names and values here are the *source game's*, not ours. We reproduce *feel and structure*, not protected terminology. Sources at end of appendix.

### Core Resource — Essence (the load-bearing mechanic)
Essence is the unifying resource that ties races, magic, and tech together:
- Magic costs **essence** to cast, and essence also drives **health regeneration**.
- Using **Tech consumes/penalizes essence** — creating a deliberate magic-vs-chrome tension separate from the money economy.
- Each **race** has a different essence pool, regen behavior, and tech penalty, which defines its identity.

**Design takeaway:** Essence is the spine. Our equivalent resource (see GDD) should be designed first, since races, magic, tech, and regen all hang off it.

### Playable Races
| Race | Strengths | Trade-offs |
|------|-----------|------------|
| **Human** | 2nd fastest, 2nd most health, **no essence penalty for using Tech** | No special ability, no health regeneration. The chrome/tech-friendly race. |
| **Elf** | Fastest movement, fastest essence regen; heals via essence when not under fire | Fragile; magic-leaning. |
| **Dwarf** | **Immune to headshots**, most essence, **saps essence** from enemies and magical objects | — |
| **Troll** | Most health; **defense increases the more it is hit** | Increasing defense **slows it further**; least essence; poor caster. |

### Magic Abilities
- **Resurrection** — revive dead allies (the defining mechanic; bodies can be destroyed to deny it — see modes).
- **Tree of Life** — summon a tree that heals anyone beneath it.
- **Teleport** — blink through walls, floors, ceilings, and enemies.
- **Smoke** — become smoke; weapon fire passes through you.
- **Gust** — push characters, objects, and projectiles away.
- **Summon** — call an astral creature to fight for you.
- **Strangle** — grow crystals that block movement and trap characters.

### Tech / Cyberware
- **Smart Link** — increased accuracy, zoom on every weapon, prevents friendly fire.
- **Wired Reflexes** — permanent speed boost.
- **Enhanced Vision** — see nearby enemies through walls for a short time.
- **Glider** — backpack wings: jump higher, fall slower, high maneuverability.
- **Anti-Magic Generator** — suppresses enemy magic (the tech counter to casters).

### Weapons
Mostly conventional FPS armaments: **pistol** (sidearm), **SMG**, **rifle**, **shotgun**, **sniper rifle**, **minigun**, **rocket launcher**, plus the standout **Katana** (switches to third-person; can deflect attacks and backstab).

### Game Modes
- **Attrition** — team deathmatch. The **artifact is the only thing that can destroy bodies**; a destroyed body cannot be resurrected.
- **Raid** — one team defends the artifact, the other attacks.
- **Extraction** — both teams race to grab the artifact and carry it to their extraction point.

### Economy (Counter-Strike-style)
- Base **wage** earned each round; **winners earn more than losers**, compounding advantage.
- Buy **weapons, Tech, and Magic** with limited funds before each round.
- **Drop your weapon on death**; **pick up** enemies' dropped weapons.

### Sources
- Shadowrun 2007 FPS — Shadowrun Wiki (Fandom): https://shadowrun.fandom.com/wiki/Shadowrun_2007_FPS
- Shadowrun (2007 video game) — Wikipedia: https://en.wikipedia.org/wiki/Shadowrun_(2007_video_game)
- Shadowrun (2007) — Hardcore Gaming 101: https://www.hardcoregaming101.net/shadowrun-2007/
- Shadowrun Q&A: Magical Races, Abilities, and Technology — GameSpot: https://www.gamespot.com/articles/shadowrun-qanda-magical-races-abilities-and-technology/1100-6165066/

**Related Internal Docs**
- [Mechanics Reference](MECHANICS_REFERENCE.md) — Detailed translation of source inspiration into our original systems (resource, archetypes, abilities, interactions, numbers)
- [Ability Tuning Sheet](ABILITY_TUNING_SHEET.md) — Live scratch pad for testing numbers, playtest notes, and investigations. Use to decide when to promote stable values.
- Technical Design / Architecture doc
- Game Design Document (GDD) with archetype kits, map specs, economy, and mode rules
- Art bible / style guide
- Contribution guide
- Steam build & deployment runbook

---

**End of Initial PRD.**  
This document will evolve. Update version history below.

**Version History**
- v0.1 — 2026-06-17 — Initial draft after research and requirement clarification. Focused on PvP starting point, Steam + Godot, spiritual successor approach, realistic scope warnings.
- v0.2 — 2026-06-28 — Added Appendix 12.A: verified Source Game Mechanics Reference for Shadowrun (2007 FPS) — essence resource, races, magic, tech, weapons, modes, and economy — with cited sources, to inform original-IP mechanics design.
- v0.3 — 2026-06-29 — Linked new [MECHANICS_REFERENCE.md](MECHANICS_REFERENCE.md) and clarified the role of Appendix 12.A as raw source data.
- v0.4 — 2026-07-15 — Owner clarifications applied: (1) archetypes are lineages + open buy phase, with loadouts specified as non-restrictive priority-ordered shopping lists; (2) Grid pillar explicitly deferred post-EA (Phase 3); (3) netcode committed to client prediction from day one (netfox) over Steam P2P, dedicated servers moved to Phase 2; (4) scope/metrics/timeline rightsized for solo developer + AI agents, timeline converted to quality-gated milestones.
- v0.5 — 2026-07-16 — Anti-cheat decision recorded (§7): layered approach — authority-side validation + input-trace logging from Phase 1, EAC via EOS (P2P client-protection mode, Proton/Deck flag) + Steamworks game bans at EA launch; host-gap mitigations documented; GD Anti Cheats rejected for multiplayer (revisit only for Phase 3 local saves).
- v0.6 — 2026-07-16 — Session/matchmaking decisions (§5, §7): public lobby browser + friends/invites; join-in-progress via spectate-then-buy-in at round boundaries; TRUE host migration committed (spike first, graceful-end interim); 16-player (8v8) cap as tunable; transport = GodotSteam 4.20 built-in MultiplayerPeer with expressobits fallback documented.
- v0.7 — 2026-07-16 — Game named **CounterSpell** (owner decision); all docs and project config renamed from the "Running in Shadows" working title. Title diligence recorded in §10 (existing Steam titles noted; formal trademark screen + distinguishing subtitle required before the Steam page). Also this date: full ability/cybernetics designs (MECHANICS_REFERENCE §4.A), cybernetic slot system, weapon damage types, controller support pulled into Milestone A.