# Match Flow & Arena/TDM (Gap G2, includes G1 crouch) Implementation Plan

> **For agentic workers:** execute with superpowers:executing-plans. Scope from
> the master plan's G1 + G2 briefs; decided design cited from PRD §5/§7 and
> MECHANICS_REFERENCE §7/§11 — do not re-litigate.

**Goal:** Round-based Arena/TDM on the match session: buy-phase stub → round
live → round end → results; death (bodies stay down until round end — corpse
system arrives in G6), team assignment, elimination/kill scoring, match end;
spectators buy in at round boundaries; plus crouch (G1).

**Architecture:** Match flow is **host-authoritative plain state** (not
rollback state): only the host mutates `MatchState`, replicating snapshots via
RPC — round flow is not per-tick predicted gameplay. Death, however, IS
simulation: `is_dead` + `last_attacker_peer` are rollback state set inside
`_rollback_tick`; kill events reach the match layer only on fresh ticks.
Crouch is a level input driving a deterministic per-tick speed multiplier and
collider swap (two CollisionShape3D nodes toggled by `disabled`).

## MatchConfig additions

```gdscript
	"movement.crouch_speed_mult": 0.55,
	"match.buy_phase_s": 15.0,
	"match.round_time_s": 180.0,
	"match.round_end_s": 5.0,
	"match.rounds_to_win": 6.0,
	"match.team_count": 2.0,
```

## Tasks

- [ ] **Task 1 — Crouch (G1):** `crouch` InputMap action (keyboard Ctrl;
  controller slot reserved for a later layout pass); `PlayerInput.crouch`
  level input (+ registration); `_rollback_tick` speed multiplier; standing/
  crouched collision shapes toggled deterministically from input; camera
  height view-only lerp. Tests: crouch slows movement; shape toggle follows
  input.
- [ ] **Task 2 — Death as simulation state:** controller rollback state
  `is_dead: bool`, `last_attacker_peer: int`; `take_damage` records attacker;
  in `_rollback_tick`, health 0 → `is_dead = true`, frozen in place (corpse
  placeholder — body persistence is a pillar), fresh-tick `died` signal.
  `reset_for_round(spawn_position)` restores health/resonance/ammo/bleed and
  clears death. Tests: lethal damage freezes + signals once; reset revives.
- [ ] **Task 3 — MatchState machine:** `scripts/match/match_state.gd` node in
  match_session: BUY_PHASE → ROUND_LIVE → ROUND_END → (BUY_PHASE | MATCH_END);
  tick-count timers on the host; team assignment round-robin over peers; kill
  scoring (from `died` signals, host only); round win = enemy team eliminated
  or timer expiry (higher kill count wins, draw = no point); match end at
  `rounds_to_win`. Spectator promotion + `reset_for_round` on entering
  BUY_PHASE. State replicated to clients via RPC snapshot. Offline path: single
  team of one, rounds still cycle (dev). Tests with shortened config timers:
  full state cycle, scoring, elimination win, match end.
- [ ] **Task 4 — Debug match HUD + docs:** state/timer/score line appended to
  the debug HUD (real HUD is G4); arena label update; TESTING/CLAUDE/PRD notes;
  cspell; full suite + three-peer E2E green.

**Anti-cheat Layer 1 (PRD §6):** all match-flow mutations are host-side only
(clients send nothing new); death derives from server-simulated health;
respawn/score paths are host functions — no client-reported anything.
