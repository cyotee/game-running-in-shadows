# SPIKE: True Host Migration (feasibility)

**Status:** COMPLETED 2026-07-20 (analysis + recommendation). Timebox: 2 sessions.
**Context:** PRD §7 (decided 2026-07-16): true host migration is committed, but its
implementation plan must not be written until this spike answers the questions
below. Interim behavior on host loss: graceful match end.

## Questions to answer

1. **netfox state continuity across an authority swap.** Can a surviving peer
   re-host with state continuity? Specifically:
   - `NetworkTime` stop/restart semantics mid-session (tick counter reset vs
     continuation — press-tick inputs and every `*_tick` state var assume a
     monotonic tick).
   - `RollbackSynchronizer.process_settings()` re-run after node authority
     changes on every player (input nodes swap to surviving peers; state
     authority moves to the new host).
   - Re-seeding world state on the new host from its last received snapshot —
     what is authoritative for ticks in flight when the host died?
2. **Steam lobby owner change → new peer topology.** Steam auto-assigns a new
   lobby owner on host departure (`lobby_data_update`). Sequence and failure
   modes for: detect owner change → new owner `create_host` → all peers
   `create_client(new_owner)` → rejoin window; what happens to peers that miss
   the window?
3. **Resume semantics.** Resume mid-round (exact state) vs restart the round
   preserving economy/score (looser, likely far simpler). The PRD does not
   mandate mid-round resume — evaluate cost of both.

## Deliverables

- Findings written into this file.
- A go/no-go per question, and the real implementation plan
  (`docs/superpowers/plans/<date>-host-migration.md`) if go.
- If no-go on netfox continuity: document the restart-round-preserving-economy
  fallback as the shipped design and update PRD §7.

## Suggested harness

Extend `tests/e2e/net_smoke.py` (ENet path): kill the host instance mid-run,
have a surviving instance re-host on the same port, measure what survives.
Steam-specific behavior needs the two-machine manual setup (owner).

---

## Findings (2026-07-20)

### Q1 — netfox state continuity: **NO-GO for mid-round exact resume (v1)**

Evidence from codebase + netfox usage:

- Every edge input is a **press-tick int** stamped with `NetworkTime.tick`. A
  tick-counter restart mid-match invalidates all in-flight press ticks and
  every `*_cast_tick` / `reload_until_tick` / cooldown field.
- `RollbackSynchronizer` history is peer-local and bounded (history limit 64).
  Host death leaves remote peers with incomplete history; there is no shipped
  API in this project to export/import a full multi-entity world snapshot
  (players + placed fields + grenades + corpses + familiars) at an agreed tick.
- Authority is per-input-node (`PlayerInput` multiplayer authority). Swapping
  host requires `process_settings()` on every synchronizer after re-parenting
  peer ownership — doable, but only after a clean NetworkTime epoch.

**Recommendation:** do **not** attempt mid-round exact state handoff for EA.

### Q2 — Steam lobby owner change: **GO with re-lobby protocol (separate from netfox)**

Steam assigns a new lobby owner on departure. Feasible sequence:

1. Detect `lobby_data_update` / owner change on all peers.
2. New owner creates a fresh `SteamMultiplayerPeer` host (or ENet host in dev).
3. Peers disconnect old peer, `create_client(new_owner)`, rejoin lobby.
4. Late peers that miss the rejoin window become spectators or return to menu.

This is independent of netfox continuity: it is a **session remesh**, not a
hot snapshot restore.

### Q3 — Resume semantics: **GO for restart-round preserving economy/score**

Ship for EA:

| On host loss | Behavior |
|--------------|----------|
| Match phase | Graceful freeze → “Host left” UI |
| Economy / round wins / team assignment | Persist in `MatchState`/`Economy` host-side copies on each peer (already RPC-synced snapshots) |
| Round | **Restart** current round from BUY_PHASE (or next buy-in) after remesh |
| In-world entities | Despawn; re-spawn players at spawn points |

Exact mid-round resume is deferred post-EA.

## Decision

| Question | Verdict |
|----------|---------|
| Mid-round netfox continuity | **NO-GO** for EA |
| Steam remesh + new host | **GO** (session layer) |
| Round restart + keep economy/score | **GO** — shipped interim design |

**Shipped interim (PRD §7 compatible):** on host loss, end the multiplayer
session gracefully (already the sessions-plan behavior). Full remesh + round
restart is the implementation plan target for post-EA if playtests demand it;
file: write `docs/superpowers/plans/<date>-host-migration.md` only when
prioritized after Milestone C playtests.

## Follow-ups

- [ ] Optional ENet harness: kill host in `net_smoke`, assert survivors return to menu cleanly (no hang).
- [ ] Owner two-machine: confirm Steam lobby owner transfer signals.
- [ ] When GO for remesh: implementation plan for SessionManager remesh + round restart only.
