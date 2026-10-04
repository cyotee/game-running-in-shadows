# Product Requirements Document (PRD)
## Playtest Combat Visualization Suite

**Project:** CounterSpell  
**Document type:** Feature PRD (playtest / dev tooling)  
**Status:** Draft v0.2 (open questions locked 2026-07-25)  
**Date:** 2026-07-25  
**Owner:** Project Lead  
**Related:** `docs/PRD.md` (parent), `docs/superpowers/plans/2026-07-25-playtest-combat-viz.md`, `scripts/dev/playtest_viz.gd`, `docs/TESTING.md`, G13 release strip  

---

## 1. Executive summary

Mechanics currently ship ahead of production art. `PlaytestViz` already draws MatchConfig-accurate field radii and brief hitscan lines, but humans still struggle to answer basic feel questions in motion: *Did I fire? Did the ray land? Head or limb? Am I Wraithed? Where did Slip take me? What killed me?*

This PRD defines a **full combat debug visualization suite**—visual only, gated to playtest/dev—so solo and multiplayer human playtests can evaluate gun feel, ability readability, and spatial interactions without waiting for Milestone D VFX/SFX.

**Ship intent (locked):** Dev / playtest only. Master switch remains `MatchConfig debug.playtest_viz` (default **on** in development). Must be **forced off** in release builds alongside MCP and other G13 strip rules. Not a substitute for production combat presentation.

**Network intent (locked):** When viz is enabled, **all peers in the match should see combat flashes** (tracers, hit pips, muzzle stubs, ability state silhouettes on remote bodies) so multiplayer playtests share a common picture. FX are **view-only** and **must never enter netfox rollback state**.

**Audio:** Out of scope for this PRD (separate plan).

---

## 2. Problem statement

### 2.1 Current state (baseline)

| Capability | Status |
|------------|--------|
| Field radii (Lifebloom / Tangle / Null) | Disc + sphere |
| Familiar aggro / melee volumes | Disc + sphere |
| Grenade detonation shells | Flash spheres |
| Repulse volume | Flash sphere |
| Hitscan tracer | ~0.08 s line; yellow body / grey miss |
| Blade swing line | Short flash |
| Player capsule / viewmodel stubs | Basic silhouettes |
| Corpse loot disc | Present |

### 2.2 Gaps for human feel testing

1. **Hitscan too brief** — easy to miss while turning or spraying.  
2. **No gun-fired signal** — no muzzle stub; weapons are hard to distinguish.  
3. **No zone-quality feedback** — head vs body vs limb not shown; no damage pip.  
4. **Ability states weak** — Wraith / Glide / Overclock / Slip / Reclaim hard to read mid-fight.  
5. **Grenade in-flight weak** — blast flash only; arc not obvious.  
6. **Multi-actor soup** — auras lack peer/team color coding; hard to attribute.  
7. **No combat event history** — no last-N debug log for “what just happened.”  
8. **Local-only flashes today** — `is_fresh` path draws tracers only on the simulating peer; other players in a lobby often see no rays.

### 2.3 Why now

- Vertical-loop tuning is blocked more by **readability** than by missing systems.  
- Multiplayer Steam/ENet playtests need **shared** debug viz so feedback is comparable across machines.  
- Keeping this under `debug.playtest_viz` preserves G13 release discipline and avoids shipping programmer art as product presentation.

---

## 3. Goals & non-goals

### 3.1 Goals

1. A human playtester can **reliably identify** gunfire, hitscan path, hit quality, ability fields, and key ability states without production VFX.  
2. In multiplayer with viz enabled, **all peers see the same combat flashes** (best-effort, not rollback-authoritative).  
3. All radii/distances remain **MatchConfig-accurate** where they represent gameplay volumes.  
4. Toggle and release strip: one config key (+ release force-off) fully disables the suite.  
5. Implementation stays **data-driven** via MatchConfig for durations, colors, and limits (no new hard-coded feel constants outside DEFAULTS).  
6. Automated tests cover enable/disable, material paths, and “FX does not mutate rollback state.”

### 3.2 Non-goals

- Production VFX/SFX, particles art pass, or store-page visuals.  
- Audio stubs (clicks, hits, ability pops)—separate PRD/plan.  
- Changing combat math, TTK philosophy, or ability rules (viz only).  
- Perfect spectator cinema / killcam polish.  
- Replacing placeholder character/weapon models (`models/placeholders/`).  
- Making debug viz cheat-resistant in public ranked play (release builds strip it).

### 3.3 Success metrics (playtest)

| Metric | Target |
|--------|--------|
| “I can tell when I fired” | ≥ 90% of playtest moments without relying on ammo counter alone |
| “I can tell if a shot hit and roughly where” | Head vs body vs miss distinguishable on most engagements |
| “I know my active movement/ability state” | Wraith / Glide / Overclock readable on own body and remotes |
| Multiplayer parity | Host and client both report seeing each other’s tracers in a 2-peer lobby with viz on |
| Performance (dev) | No sustained hitch > 5 ms attributable to FX on 16-player greybox; FX pool/cap enforced |
| Release safety | `COUNTERSPELL_RELEASE=1` (or project release flag) → viz never draws |

---

## 4. Decisions (owner-locked for this PRD)

| Decision | Choice |
|----------|--------|
| Audience / ship | **Dev / playtest only** |
| Scope wave 1 | **Full combat debug suite** (see §5) |
| Audio | **Visual only** |
| Multiplayer visibility | **All peers see tracers/hits** (and other ephemeral combat FX) when viz enabled |
| Master switch | `debug.playtest_viz` (> 0.5 = on); release builds force off |
| Netcode boundary | FX are **not** rollback state; unreliable/view RPCs or equivalent presentation channel only |

---

## 5. Feature requirements

### 5.1 Master controls

| ID | Requirement |
|----|-------------|
| VIZ-01 | `PlaytestViz.enabled()` remains the single gate used by all new FX. |
| VIZ-02 | MatchConfig keys under `debug.viz.*` tune durations, opacities, caps (see §7). |
| VIZ-03 | Release strip (G13): when release mode is active, `enabled()` is always false regardless of MatchConfig file overrides on disk where feasible; document host-override behavior for private playtest builds. |
| VIZ-04 | Optional runtime toggle (dev): keybind or Dev Arsenal checkbox “Playtest Viz” flips `debug.playtest_viz` without restart. Nice-to-have for first delivery; required before broad external playtests. |

### 5.2 Hitscan & weapons (combat core)

| ID | Requirement |
|----|-------------|
| GUN-01 | Hitscan tracer duration baseline **0.25–0.35 s** (tunable), not 0.08 s. |
| GUN-02 | Tracer colors: **miss**, **limb**, **body**, **head** (four distinct hues). Map from hit zone meta already used by damage. |
| GUN-03 | On hit player/familiar: world-space **hit marker** (small cross or diamond) at impact for ~0.2 s + optional floating **damage pip** (debug text or number mesh) showing rounded damage. |
| GUN-04 | **Muzzle flash stub**: short-lived sphere/cone at fire origin (camera/weapon socket) per shot; duration ~0.05–0.1 s. |
| GUN-05 | Shotgun pellets: either one tracer per pellet (capped) or cone fan + single “pellet count” pip; must not explode draw cost (cap via `debug.viz.max_tracers_per_tick`). |
| GUN-06 | Blade: keep swing line; add **hit** color if contact connects; optional arc disc for `weapon.blade.arc_deg` (debug). |
| GUN-07 | Weapon class tint on muzzle/tracer optional secondary channel (pistol vs SMG vs rifle vs sniper) for identity—table in MatchConfig. |

### 5.3 Ability state silhouettes

| ID | Requirement |
|----|-------------|
| ABL-01 | **Wraith:** local + remote body tint/outline (e.g. desaturated / high alpha ghost). Visible to all peers when viz on. |
| ABL-02 | **Glide:** subtle trail or ring while `is_gliding`; readable from third person. |
| ABL-03 | **Overclock active:** warm/red pulse tint while active drain window; distinct from passive reservation. |
| ABL-04 | **Slip:** short-lived **destination ghost** sphere at blink landing + optional start→end line. |
| ABL-05 | **Reclaim cast:** flash sphere/disc at caster using `reclaim.radius_m` for cast duration. |
| ABL-06 | **Smart Rig:** debug aim assist ray or wedge (length/tunable); must not imply false hitscan damage. |
| ABL-07 | **Pulse Sight:** existing reveal behavior may stay; add optional pulse wave ring for cast feedback if missing. |
| ABL-08 | Fields (Lifebloom / Tangle / Null): keep radius disc+sphere; add **owner peer color** accent so multi-caster soup is attributable. |

### 5.4 Projectiles & world objects

| ID | Requirement |
|----|-------------|
| PRJ-01 | Grenade **in-flight trail** or periodic position pings; keep dual detonation shells. |
| PRJ-02 | Familiar: keep aggro/melee volumes; add simple facing indicator or state label (FOLLOW / GUARD / HUNT) as billboard text when viz on. |
| PRJ-03 | Corpse: keep loot disc; optional drag-link line while dragged. |
| PRJ-04 | Ping markers (G7): ensure consistent palette with combat log; no regression. |

### 5.5 Verbose combat log HUD

| ID | Requirement |
|----|-------------|
| LOG-01 | When viz on, HUD shows a **last N events** list (default N=8, tunable), e.g. `SMG body 7 → peer 3`, `Slip 8.2m`, `Tangle pull`, `cast_denied repulse`. |
| LOG-02 | Local player always gets their own events; optional filter “all peers” for host debugging. |
| LOG-03 | Log is view-only UI; not authoritative, not used for scoring. |
| LOG-04 | Clear log on round reset / scene change. |

### 5.6 Multiplayer / networking

| ID | Requirement |
|----|-------------|
| NET-01 | Ephemeral FX (tracers, muzzle, hit markers, slip ghosts, state tints) are **presentation-only**. |
| NET-02 | **Do not** register FX nodes or flash state on `RollbackSynchronizer`. |
| NET-03 | When `debug.playtest_viz` is enabled for a peer, that peer both **emits** and **renders** FX. Host config should drive session policy: recommended default—if host has viz on, clients treat viz as on for the match (document sync mechanism: lobby property, MatchConfig host push, or explicit `debug.viz.replicate=1`). |
| NET-04 | Prefer **unreliable RPC** (or netfox-friendly presentation channel) with compact payloads: `from`, `to`, `kind`, `zone`, `damage`, `peer_id`, `weapon_key`. Rate-limit and drop under congestion. |
| NET-05 | Emit FX on **authority-confirmed or is_fresh-local** paths carefully to avoid double-draw: local predicted flash once; remote peers draw from RPC; do not redraw full history on every rollback resim. |
| NET-06 | Remote player **state silhouettes** (Wraith/Glide/Overclock) derived from already-replicated rollback state on remote avatars—prefer local inference over FX RPC when state is already synced. |
| NET-07 | Spectators (join-in-progress) receive the same presentation channel when viz is session-enabled. |
| NET-08 | Cap concurrent FX meshes per peer (`debug.viz.max_active_fx`) with oldest-first eviction. |

### 5.7 Performance & Compatibility renderer

| ID | Requirement |
|----|-------------|
| PERF-01 | Continue GL Compatibility–safe materials (unshaded alpha, no exotic features). |
| PERF-02 | Reuse `PlaytestViz` material cache; extend prewarm list for new variants (ShaderPrewarm). |
| PERF-03 | Pool or hard-cap ImmediateMesh tracers; no unbounded allocate-per-SMG-bullet without eviction. |
| PERF-04 | Headless: `enabled()` stays false (existing behavior). |

### 5.8 Accessibility / readability

| ID | Requirement |
|----|-------------|
| ACC-01 | Color palette must remain distinguishable in deuteranopia-friendly pairing where possible (shape + color for head vs body). |
| ACC-02 | Damage pips optional via `debug.viz.show_damage_pips` for clutter control. |
| ACC-03 | Combat log font scales with DisplayConfig UI scale. |

---

## 6. User experience

### 6.1 Solo arena (`test_arena`)

1. Launch with default `debug.playtest_viz = 1`.  
2. Fire weapons → visible muzzle stub + longer tracer; hits show zone color + optional damage pip.  
3. Cast Slip → ghost at destination; Wraith → body tint; place Lifebloom → colored owner disc.  
4. Open combat log strip → last events readable.  
5. Toggle viz off → all ephemeral FX and log hide; gameplay unchanged.

### 6.2 Multiplayer lobby

1. Host enables viz (default on in dev).  
2. Two players fire at each other → **both** see tracers and hit markers.  
3. One player Wraiths → other sees ghost tint on remote capsule.  
4. Release build / release flag → neither peer draws suite even if old `user://match_config.json` has viz on.

### 6.3 Failure modes

| Situation | Behavior |
|-----------|----------|
| RPC flood | Drop excess FX; never stall tick |
| Viz off mid-match | Stop new FX; expire existing timers |
| Headless CI | No draws, tests still pass |
| Missing weapon socket | Muzzle falls back to camera origin |

---

## 7. MatchConfig keys (proposed)

All new keys under `debug.viz.*` or extend existing `debug.playtest_viz`. Baselines are starting points for the tuning sheet.

| Key | Proposed default | Purpose |
|-----|------------------|---------|
| `debug.playtest_viz` | `1` | Master enable (existing) |
| `debug.viz.tracer_duration_s` | `0.28` | Hitscan/blade line lifetime |
| `debug.viz.hit_marker_duration_s` | `0.2` | Impact pip |
| `debug.viz.muzzle_duration_s` | `0.07` | Muzzle stub |
| `debug.viz.show_damage_pips` | `1` | Floating damage |
| `debug.viz.combat_log_lines` | `8` | HUD log depth |
| `debug.viz.max_active_fx` | `64` | Mesh cap |
| `debug.viz.max_tracers_per_tick` | `12` | Shotgun/SMG safety |
| `debug.viz.replicate` | `1` | Emit/receive peer FX when viz on |
| `debug.viz.show_state_silhouettes` | `1` | Wraith/Glide/Overclock tints |
| `debug.viz.show_slip_ghost` | `1` | Slip destination |
| `debug.viz.owner_color_seed` | `1` | Stable peer→color mapping |

Exact color RGBA values live as MatchConfig floats or a single documented palette table in the implementation plan (avoid magic colors scattered in weapon scripts).

---

## 8. Architecture

### 8.1 Components

```
PlaytestViz (autoload)          — materials, attach_*, flash_*, pools, caps
PlaytestFxBus (new, optional)   — encode/decode FX events; RPC / multiplayer API
WeaponBase / Blade / Grenade    — emit FX events on fire/hit (presentation path only)
FPSController                   — state silhouettes from local replicated state; Slip/Reclaim flashes
PlacedField / Familiar / Corpse — owner coloring; labels
PlayerHud                       — combat log strip when viz on
ShaderPrewarm                   — include new material variants
MatchConfig                     — debug.viz.* DEFAULTS
G13 release strip               — force disabled
```

### 8.2 Event flow (hitscan, multiplayer)

1. Rollback sim applies damage as today (authoritative path unchanged).  
2. On presentation-safe moment (`is_fresh` local and/or confirmed fire):  
   - Local: `PlaytestViz.flash_*` immediately.  
   - If `debug.viz.replicate` and multiplayer: send unreliable FX payload to others.  
3. Remotes: `PlaytestFxBus` receives → `PlaytestViz.flash_*` only (no damage).  
4. Rollback resimulation **must not** spam additional FX (guard with tick+peer dedupe or “only is_fresh / only RPC”).

### 8.3 IP / presentation

Use CounterSpell terms only (Resonance, Manifestations, etc.). No source-IP trademarks in log strings or labels.

---

## 9. Phased delivery

### Phase A — Local combat readability (foundation)

- Longer tracers + zone colors  
- Hit marker + damage pip  
- Muzzle stub  
- MatchConfig keys + material cache/prewarm  
- Tests for enable gate and zone color mapping  
- **Exit:** solo arena gunfights are legible without ammo HUD

### Phase B — Ability silhouettes & world objects

- Wraith / Glide / Overclock tints  
- Slip ghost, Reclaim radius flash  
- Grenade trail, Familiar state label, field owner colors  
- Combat log HUD  
- **Exit:** full vertical loop ability readability solo

### Phase C — Multiplayer replication

- `PlaytestFxBus` + unreliable FX channel  
- Host/session viz policy  
- Dedupe, caps, spectator path  
- Two-instance E2E check (ENet or Steam) that peer B sees peer A tracer  
- **Exit:** 2-peer playtest shares combat picture

### Phase D — Polish & strip

- Dev Arsenal toggle  
- Palette/accessibility pass  
- Release-strip verification test  
- Update README + `ABILITY_TUNING_SHEET` playtest notes  
- **Exit:** G13-safe; docs match behavior

Phases A→B may merge in one implementation plan if staffing is a single agent sprint; Phase C must not ship half-broken double-draw.

---

## 10. Testing requirements

| Layer | Requirement |
|-------|-------------|
| Unit | `PlaytestViz.enabled()` false headless; true when config on (non-headless test or inject) |
| Unit | Zone→color mapping pure function tests |
| Unit | FX pool eviction at `max_active_fx` |
| Integration | SceneRunner: fire pistol → tracer node exists when viz on; absent when off |
| Integration | Damage pip value matches `take_zone_damage` result for a known shot (presentation query / log entry) |
| Net | Two-instance: A fires, B receives ≥1 FX RPC / draws tracer (E2E script or godot-mcp dual instance) |
| Regression | Full GdUnit suite green; no new rollback state properties for FX |
| Release | Release-mode test asserts viz disabled |

---

## 11. Documentation updates

| Doc | Update |
|-----|--------|
| `README.md` playtest viz table | Expand to full suite + multiplayer note |
| `docs/TESTING.md` | How to toggle viz; E2E FX check |
| `docs/ABILITY_TUNING_SHEET.md` §9 | Playtest readability pass log when implemented |
| `docs/PRD.md` | One-line Phase 0/1 reference to this feature PRD (optional) |
| G13 / release strip plan | Explicit `PlaytestViz` + FX bus strip |

---

## 12. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| FX double-draw on rollback | is_fresh + RPC split; never flash inside pure resim without guard |
| Bandwidth on 16 peers × SMG | Caps, unreliable, pellet aggregation, rate limits |
| Viz used as wallhack-lite in public | Release force-off; friends-only playtests until EAC era |
| Color soup in multi-field fights | Owner color accents + combat log attribution |
| Scope creep into production VFX | Hard non-goal; Milestone D remains real art |
| `user://match_config.json` re-enables viz in release | Release path ignores or overrides debug keys |

---

## 13. Locked follow-ups (2026-07-25 owner)

1. **Session policy:** **Host-forced viz.** When the match host has viz enabled (or session policy bit set), all clients enable the suite for that match; clients do not independently opt out while the host requires it.  
2. **Damage pip authority:** **Confirmed only.** Pips show the damage value after the authoritative hit apply (host-confirmed / post-sim applied amount), not speculative predicted estimates. Offline authority = local sim apply is confirmation.  
3. **Smart Rig wedge:** **Phase B** (ability silhouettes wave) — in scope for first delivery.  
4. **Third-person blade offsets:** Leave default camera origin unless playtests show a problem; no special offset required for v1.

---

## 14. Acceptance criteria (PRD-level done)

1. Full suite in §5 implemented or explicitly deferred with owner sign-off (default: implement A–D).  
2. `debug.playtest_viz = 0` removes all new and old playtest combat FX.  
3. Release mode never draws the suite.  
4. Multiplayer: with viz on, peer B observes peer A hitscan tracer and a hit marker on a successful body shot in automated or documented manual 2-peer test.  
5. No FX-related rollback state; net_smoke / GdUnit gameplay suites remain green.  
6. README documents the suite and multiplayer behavior.  
7. Visual-only: no audio assets or bus requirements introduced by this PRD.

---

## 15. Appendix — palette sketch (non-final)

| Kind | Sketch |
|------|--------|
| Miss | Cool grey |
| Limb | Blue |
| Body | Yellow / amber |
| Head | Magenta or bright cyan (shape: larger marker) |
| Muzzle | White flash |
| Wraith | Desaturated blue body |
| Glide | Soft cyan ring |
| Overclock | Orange pulse |
| Slip ghost | Green sphere |
| Lifebloom owner | Green family |
| Tangle owner | Purple family |
| Null owner | Dark red family |

Final RGBA values → MatchConfig / tuning sheet during implementation.

---

## 16. Approval

| Role | Sign-off |
|------|----------|
| Owner (product) | Pending review of this draft |
| Implementation | Proceed via `docs/superpowers/plans/` plan after approval |

**Locked inputs from 2026-07-25 requirements interview:**

- Dev / playtest only  
- Full combat debug suite for first delivery  
- Visual only (no audio in this PRD)  
- All peers see tracers/hits when viz enabled  
