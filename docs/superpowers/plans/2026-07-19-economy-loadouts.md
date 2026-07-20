# Buy Phase, Economy & Loadouts (Gap G3) Implementation Plan

> **For agentic workers:** execute with superpowers:executing-plans. Decided
> design from PRD §5 (loadouts = priority-ordered shopping lists,
> skip-and-continue, decided 2026-07-15) and MECHANICS_REFERENCE §4/§7/§11
> (wages with winner compounding; cybernetic slot exclusivity + permanence).

**Goal:** Host-authoritative per-player money with round wages/bonuses, a
buy-phase purchase path for weapons (abilities join in G5 through the same
API), shopping-list loadouts, the cybernetic slot framework (Eye/Full Body,
permanent once bought), and a debug-grade buy menu.

**Architecture:** `Economy` is host-authoritative plain state (like
`MatchState`): money/ownership dicts mutated only on the host, synced by RPC;
clients send exactly one RPC (`request_buy`) that the host validates
(anti-cheat Layer 1: phase check, funds check, slot check — nothing
client-reported). Weapon grants must apply INSIDE the tick simulation
(rig slots are rollback state), so the controller gains `queue_grant` pending
vars consumed on the next fresh tick — same pattern as `reset_for_round`.

## MatchConfig additions

```gdscript
	"economy.start_money": 800.0,
	"economy.wage_base": 1000.0,
	"economy.wage_win_bonus": 600.0,
	"economy.kill_bonus": 200.0,
	"price.pistol": 0.0, "price.smg": 600.0, "price.shotgun": 1200.0,
	"price.rifle": 1600.0, "price.sniper": 2800.0, "price.blade": 1200.0,
```

## Tasks

- [ ] **Task 1 — In-tick weapon grants:** `FPSController.queue_grant(key,
  slot)`; pending list applied on fresh ticks (mirrors respawn). Match-session
  spawns start pistol-only (`default_slot1 = ""` on spawned players); the
  test arena keeps its free rifle for dev.
- [ ] **Task 2 — Economy node:** `scripts/match/economy.gd` in match_session:
  `money_of(peer)`, `award_round_wages(winning_team)` (base + win bonus +
  kill bonus × kills-that-round), `try_buy(peer, item) -> bool` (BUY_PHASE
  only, funds, cyber-slot exclusivity via a `CYBER_SLOTS` map — empty for
  weapons today, G5 fills it; permanence: cyber items never re-buyable),
  `apply_loadout(peer, items)` (skip-and-continue walk), `request_buy` RPC.
  Kill counting hooks off `MatchState`. RPC money sync to clients.
- [ ] **Task 3 — Buy menu (debug-grade):** panel in match_session CanvasLayer:
  money label, weapon list with prices, Buy + "Buy Default Loadout" buttons;
  visible only during BUY_PHASE (phase signal).
- [ ] **Task 4 — Verification + docs:** GdUnit for economy rules and loadout
  semantics; full suite + E2E; live offline check; master plan/PRD notes.

**Noted gap for G6 (corpses):** weapon drop-on-death was listed by the master
plan as "handled by the weapons plan" but was not in that plan's shipped
scope — corpse inventory (G6) is the natural home; recorded there.
