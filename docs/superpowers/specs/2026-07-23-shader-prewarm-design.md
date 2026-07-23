# Shader Pre-warm Pass — Design

**Date:** 2026-07-23
**Status:** Approved (design), implementing.

## Problem

On the macOS OpenGL **Compatibility** renderer (AMD Radeon Pro 5600M), the game
freezes ~1.3 s during active play, recurring roughly every 5–6 s. netfox reports
these as `Game stalled for ~1.3s, assuming it was a pause` followed by
`rollback ... past the history limit of 64` (an ~80-tick catch-up at 60 Hz — a
cosmetic downstream symptom in offline single-player).

### Root cause (evidence)

1. Renderer is `gl_compatibility` on the deprecated macOS OpenGL path — a known
   source of slow, main-thread shader compilation.
2. No gameplay per-frame heavy work exists (`playtest_viz.gd` is event-driven,
   the MCP server `_process` early-returns, no timers/`_process` run heavy work
   on a ~5 s cadence).
3. A running-but-idle instance produced **zero** stalls over 18 s (only the
   initial ~7.7 s load stall) — ruling out timers, GC, and background-window
   throttling.
4. Therefore the hitches are **activity-triggered**: the Compatibility renderer
   compiles each shader variant synchronously the first time it is drawn. The
   only runtime material-creation site in gameplay is `PlaytestViz`
   (`unshaded_mat` → sphere/disc aura, plus the vertex-color tracer), which is
   on by default and produces new variants the first time you fire, throw a
   grenade, Repulse, or place a field.

**Caveat:** the mid-play stall was not reproduced live (the in-game MCP command
channel kept dropping), so the cause is strongly-evidenced but not
live-confirmed. The material list is a trivial extension point if a different
source surfaces.

## Goal

Move the effect-material compile cost off mid-play frames and into the initial
load, where a stall is already expected. **Scope: effect materials only** —
the `PlaytestViz` variants. Level geometry and placeholder-model materials
already compile during the initial load.

## Design

New autoload `ShaderPrewarm` (`scripts/dev/shader_prewarm.gd`). No `class_name`
(matches `PlaytestViz` / MCP-server convention — avoids LSP cache races).
Registered in `project.godot [autoload]` after `PlaytestViz`.

### Mechanism (variant-safe)

GL Compatibility compiles a variant only on its first **real draw in the target
viewport**. To guarantee parity with gameplay, warm **in the main viewport**
using the **exact material objects `PlaytestViz` produces** — not a SubViewport,
whose render-target state can yield a different variant that fails to pre-warm
the real one.

1. Wait until the active scene has a `Camera3D`; run **once per process**.
2. Skip if `DisplayServer.get_name() == "headless"` or `not PlaytestViz.enabled()`.
3. Build a temporary container parented to the active camera at local
   `(0, 0, -0.3)`, scaled tiny (sub-pixel), so it is inside the frustum (draws →
   compiles) but imperceptible. Children:
   - `SphereMesh` + `PlaytestViz.unshaded_mat(...)` — covers the sphere **and**
     disc aura (same variant: unshaded / alpha / cull-disabled).
   - `ImmediateMesh` line + the tracer material (`vertex_color_use_as_albedo`).
4. `await` 2–3 `RenderingServer.frame_post_draw` so each variant actually draws.
5. Free the container.

### Separation of concerns (for testability)

- `should_warm() -> bool` — gating predicate (false under headless / viz off).
- `target_materials() -> Array` — the variant list, sourced from `PlaytestViz`
  factory functions (reused, not duplicated → drift-resistant).
- `build_warm_nodes() -> Node3D` — container of `MeshInstance3D`s. Pure node
  construction; needs no display.
- `_perform_warmup()` — thin gated orchestration (attach to camera, await, free).

### Gating

Coupled to `PlaytestViz.enabled()`; if viz is off, those materials never appear
in play, so there is nothing to warm. **No new MatchConfig key.** Dev/prototype
only — same lifecycle as playtest_viz.

## Testing

Headless cannot render, so GdUnit verifies only the display-independent parts:

1. `should_warm()` is false under headless (test env is headless).
2. `target_materials()` returns materials whose flags match `PlaytestViz`'s
   factory output (unshaded / alpha / cull-disabled; tracer uses vertex color).
3. `build_warm_nodes()` returns a `Node3D` with ≥2 `MeshInstance3D` children,
   each carrying a `material_override`.
4. No orphans: adding the container to a node and freeing it leaves no children.

**Acceptance test (manual, owner-run):** launch the arena, fire / grenade /
Repulse / place a field, and confirm the first-use freeze is gone (absorbed into
load). GPU compilation cannot be asserted headlessly or over the MCP channel.

## Risks

- If the mid-play stutter comes from materials other than `PlaytestViz`, this
  pass won't fully cover it — extend `target_materials()`.
- Sub-pixel in-frustum draw must still issue a draw call (it does; compilation
  happens at draw-call submission regardless of pixel coverage).
