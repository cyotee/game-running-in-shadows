# G11 — Layer-1 Anti-Cheat Audit

**Status:** EXECUTED 2026-07-20

## Scope
Verify authority validation on state-mutating paths; land structured input-trace logging.

## Findings

| Path | Authority model | Status |
|------|-----------------|--------|
| Health / death / kills | Host MatchState + in-tick take_damage | OK |
| Resonance spend/reserve | Simulated on each peer with shared input | OK (cheats limited to own pool under rollback) |
| Match phase / scores | Host-only MatchState RPCs | OK |
| Economy wages | Host-only | OK |
| Ping service | Host-authoritative store | OK |
| CTF objective | Host-only mutations | OK |
| Weapon hits | Hitscan from shooter tick + mutate victim | OK (Layer-1; no client-reported damage API) |
| Placed fields / grenades / corpses / familiars | Spawner + deterministic sim | OK |

## Input trace
- Autoload `InputTrace` (`scripts/dev/input_trace.gd`) ring buffer of edge actions.
- Recorded from `PlayerInput._gather` for jump/repulse/glide/fire/slip/wraith/reclaim/familiar/augments.
- Disabled when `COUNTERSPELL_RELEASE=1` or `counterspell/release_build`.

## Deferred
- Server-side statistical anomaly detection (post-EA).
- EAC binary integration (G13 hooks only for now).
