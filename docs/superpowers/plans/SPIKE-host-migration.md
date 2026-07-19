# SPIKE: True Host Migration (feasibility)

**Status:** Not started. Timebox: 2 sessions.
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
