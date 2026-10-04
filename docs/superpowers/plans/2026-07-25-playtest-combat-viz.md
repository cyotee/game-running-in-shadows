# Playtest Combat Visualization Suite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make gunfire, hitscan quality, ability states, and fields human-readable in solo and multiplayer playtests via a full visual-only debug suite gated by `debug.playtest_viz`, with host-forced session policy, confirmed damage pips, and peer-visible FX.

**Architecture:** Extend `PlaytestViz` for pooled ephemeral meshes (tracers, muzzle, hit markers, ghosts). Add `PlaytestFxBus` (autoload) as a presentation-only multiplayer channel — unreliable RPCs, never rollback state. Local systems emit FX events after confirmed damage/state; host pushes `debug.viz.session_forced` so all peers share the same viz policy. HUD combat log is view-only. Smart Rig debug wedge lands in Phase B with other ability silhouettes.

**Tech Stack:** Godot 4.7.1, GDScript (typed), netfox (read replicated avatar state only), GdUnit4, existing `PlaytestViz` / `ShaderPrewarm` / G13 release flags.

**Spec:** `docs/PRD_PLAYTEST_COMBAT_VIZ.md` v0.2.

## Global Constraints

- IP: CounterSpell terms only (Resonance, Manifestations, Augments, Repulse, Glide, etc.) — never Shadowrun trademarks in log strings or labels.
- All tunables in `MatchConfig.DEFAULTS` under `debug.playtest_viz` / `debug.viz.*` — no hard-coded durations/colors outside DEFAULTS + palette helpers that read config.
- Visual only — no audio assets or AudioServer bus work.
- FX are **not** netfox rollback state: no `RollbackSynchronizer` entries, no `NetworkRollback.mutate` for meshes.
- **Host-forced viz:** host session bit wins; clients enable/disable suite from host policy for the match.
- **Confirmed damage pips only:** show damage after authoritative apply (offline: local apply is authority).
- **Smart Rig wedge:** Phase B (Task 5), not deferred.
- Release: `COUNTERSPELL_RELEASE=1` or `counterspell/release_build` → `PlaytestViz.enabled()` always false (same pattern as `InputTrace` / `McpInteractionServer`).
- Headless: `enabled()` false; logic tests still run.
- Typed GDScript; tests in `tests/` mirroring `scripts/`; suite gate exit 0 for touched suites.
- Scratch for agent evidence: project `.scratch/` or goal scratch only — not shared `/tmp`.

## Locked product decisions (do not re-litigate)

| Topic | Decision |
|-------|----------|
| Ship | Dev / playtest only |
| Scope | Full combat debug suite |
| Audio | None |
| Multiplayer FX | All peers see tracers/hits when session viz on |
| Session policy | **Host-forced** |
| Damage pips | **Confirmed only** |
| Smart Rig wedge | **Phase B** |

## File Structure

| Path | Role |
|------|------|
| `scripts/dev/playtest_viz.gd` | Materials, flash primitives, pool/cap, zone colors, release gate |
| `scripts/dev/playtest_fx_bus.gd` | **Create** — FX event encode/decode, host session force, unreliable RPC |
| `scripts/config/match_config.gd` | `debug.viz.*` DEFAULTS |
| `scripts/weapons/weapon_base.gd` | Emit confirmed hitscan FX via bus |
| `scripts/weapons/blade.gd` | Swing/hit FX via bus |
| `scripts/weapons/grenade.gd` | In-flight trail + keep detonation shells |
| `scripts/player/fps_controller.gd` | State silhouettes, Slip ghost, Reclaim flash, Smart Rig wedge, Repulse flash via bus |
| `scripts/abilities/placed_field.gd` | Owner-colored disc/sphere |
| `scripts/abilities/familiar.gd` | State billboard label |
| `scripts/abilities/corpse.gd` | Optional drag line |
| `scripts/ui/player_hud.gd` + `scenes/ui/player_hud.tscn` | Combat log strip |
| `scripts/ui/dev_arsenal.gd` | Viz toggle checkbox (dev) |
| `scripts/dev/shader_prewarm.gd` | Prewarm new material variants |
| `scripts/session/match_session.gd` | Wire `PlaytestFxBus.setup` / host policy push on match start |
| `project.godot` | Register `PlaytestFxBus` autoload |
| `tests/dev/test_playtest_viz.gd` | Extend enable/colors/pool |
| `tests/dev/test_playtest_fx_bus.gd` | **Create** — session force, RPC payload, no rollback |
| `tests/weapons/test_weapon_*.gd` / new `tests/dev/test_combat_fx_emit.gd` | Confirmed pip + tracer emission |
| `tests/ui/test_player_hud.gd` | Combat log |
| `tests/dev/test_release_strip.gd` | Viz forced off in release |
| `docs/PRD_PLAYTEST_COMBAT_VIZ.md` | Already updated |
| `README.md`, `docs/TESTING.md`, `docs/ABILITY_TUNING_SHEET.md` §9 | Docs |
| `tests/e2e/net_smoke.py` or small `tests/e2e/fx_smoke.py` | Optional 2-peer tracer observation |

---

### Task 1: MatchConfig keys + release-aware `PlaytestViz.enabled()`

**Files:**
- Modify: `scripts/config/match_config.gd` (`DEFAULTS`)
- Modify: `scripts/dev/playtest_viz.gd` (`enabled()`, helpers)
- Modify: `tests/dev/test_playtest_viz.gd` (or create if patterns live elsewhere)
- Test: `tests/dev/test_playtest_viz.gd`

**Interfaces:**
- Produces:
  - `PlaytestViz.enabled() -> bool` — false if headless OR release OR `debug.playtest_viz <= 0.5` OR (when session policy active and not forced) see Task 4; for Task 1 implement headless + release + config only.
  - MatchConfig keys listed below.

- [ ] **Step 1: Write the failing test**

Add to `tests/dev/test_playtest_viz.gd` (create suite if missing):

```gdscript
func test_enabled_false_in_release_mode() -> void:
	# Simulate release the same way InputTrace does.
	OS.set_environment("COUNTERSPELL_RELEASE", "1")
	# Force PlaytestViz to re-read if it caches; otherwise call enabled() which must check env each time.
	assert_bool(PlaytestViz.enabled()).is_false()
	OS.set_environment("COUNTERSPELL_RELEASE", "")


func test_debug_viz_defaults_exist() -> void:
	MatchConfig.reset_to_defaults()
	assert_float(MatchConfig.get_value("debug.playtest_viz")).is_equal(1.0)
	assert_float(MatchConfig.get_value("debug.viz.tracer_duration_s")).is_equal(0.28)
	assert_float(MatchConfig.get_value("debug.viz.hit_marker_duration_s")).is_equal(0.2)
	assert_float(MatchConfig.get_value("debug.viz.muzzle_duration_s")).is_equal(0.07)
	assert_float(MatchConfig.get_value("debug.viz.show_damage_pips")).is_equal(1.0)
	assert_float(MatchConfig.get_value("debug.viz.combat_log_lines")).is_equal(8.0)
	assert_float(MatchConfig.get_value("debug.viz.max_active_fx")).is_equal(64.0)
	assert_float(MatchConfig.get_value("debug.viz.max_tracers_per_tick")).is_equal(12.0)
	assert_float(MatchConfig.get_value("debug.viz.replicate")).is_equal(1.0)
	assert_float(MatchConfig.get_value("debug.viz.show_state_silhouettes")).is_equal(1.0)
	assert_float(MatchConfig.get_value("debug.viz.show_slip_ghost")).is_equal(1.0)
	assert_float(MatchConfig.get_value("debug.viz.host_force_session")).is_equal(1.0)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd -a ./tests/dev/test_playtest_viz.gd --ignoreHeadlessMode
```

Expected: FAIL on missing keys and/or release gate.

- [ ] **Step 3: Implement DEFAULTS + `enabled()`**

In `match_config.gd` `DEFAULTS`, after existing `debug.playtest_viz`:

```gdscript
	"debug.playtest_viz": 1.0,
	"debug.viz.tracer_duration_s": 0.28,
	"debug.viz.hit_marker_duration_s": 0.2,
	"debug.viz.muzzle_duration_s": 0.07,
	"debug.viz.show_damage_pips": 1.0,
	"debug.viz.combat_log_lines": 8.0,
	"debug.viz.max_active_fx": 64.0,
	"debug.viz.max_tracers_per_tick": 12.0,
	"debug.viz.replicate": 1.0,
	"debug.viz.show_state_silhouettes": 1.0,
	"debug.viz.show_slip_ghost": 1.0,
	"debug.viz.host_force_session": 1.0,
	"debug.viz.show_smart_rig_wedge": 1.0,
	"debug.viz.smart_rig_wedge_deg": 20.0,
	"debug.viz.smart_rig_wedge_range_m": 40.0,
	"debug.viz.grenade_trail_interval_s": 0.08,
```

In `playtest_viz.gd`:

```gdscript
func enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if _release_mode():
		return false
	return MatchConfig.get_value("debug.playtest_viz") > 0.5


func _release_mode() -> bool:
	return OS.get_environment("COUNTERSPELL_RELEASE") == "1" \
		or bool(ProjectSettings.get_setting("counterspell/release_build", false))
```

- [ ] **Step 4: Run tests — expect PASS**

Same command as Step 2. Expected: `0 failures`.

- [ ] **Step 5: Commit**

```bash
git add scripts/config/match_config.gd scripts/dev/playtest_viz.gd tests/dev/test_playtest_viz.gd
git commit -m "feat(viz): MatchConfig debug.viz keys and release-aware PlaytestViz gate"
```

---

### Task 2: PlaytestViz API — zone colors, longer tracers, muzzle, hit marker, pool

**Files:**
- Modify: `scripts/dev/playtest_viz.gd`
- Modify: `scripts/dev/shader_prewarm.gd` (include new materials)
- Test: `tests/dev/test_playtest_viz.gd`

**Interfaces:**
- Produces:
  - `zone_tracer_color(zone: String, hit_player: bool) -> Color`
  - `flash_line(tree, from, to, color, duration_s = -1)` — default duration from MatchConfig
  - `flash_muzzle(tree, origin: Vector3, color: Color = white)`
  - `flash_hit_marker(tree, pos: Vector3, damage: float, zone: String)`
  - `flash_slip_ghost(tree, pos: Vector3)`
  - `register_fx_node(node: Node) -> void` / pool eviction at `max_active_fx`
  - `owner_color(peer_id: int) -> Color`

- [ ] **Step 1: Failing tests for zone colors + pool**

```gdscript
func test_zone_tracer_colors_distinct() -> void:
	var miss := PlaytestViz.zone_tracer_color("", false)
	var limb := PlaytestViz.zone_tracer_color("limbs", true)
	var body := PlaytestViz.zone_tracer_color("body", true)
	var head := PlaytestViz.zone_tracer_color("head", true)
	assert_bool(miss != body).is_true()
	assert_bool(body != head).is_true()
	assert_bool(limb != head).is_true()


func test_flash_line_uses_config_duration_when_default() -> void:
	# Unit-level: duration resolution helper
	assert_float(PlaytestViz.tracer_duration()).is_equal_approx(0.28, 0.001)
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement API**

Core patterns (illustrative — match existing style in `playtest_viz.gd`):

```gdscript
var _active_fx: Array[Node] = []


func tracer_duration() -> float:
	return MatchConfig.get_value("debug.viz.tracer_duration_s")


func zone_tracer_color(zone: String, hit_player: bool) -> Color:
	if not hit_player:
		return Color(0.7, 0.75, 0.85, 0.55)
	match zone:
		"head":
			return Color(1.0, 0.2, 0.85, 0.95)
		"limbs":
			return Color(0.35, 0.55, 1.0, 0.9)
		_:
			return Color(1.0, 0.9, 0.2, 0.9)


func flash_line(tree: SceneTree, from: Vector3, to: Vector3, color: Color,
		duration_s: float = -1.0) -> void:
	if not enabled() or tree == null:
		return
	if duration_s < 0.0:
		duration_s = tracer_duration()
	# ... existing ImmediateMesh path ...
	_track_fx(mi, tree, duration_s)


func flash_muzzle(tree: SceneTree, origin: Vector3, color: Color = Color(1, 1, 1, 0.9)) -> void:
	if not enabled() or tree == null:
		return
	var r := 0.12
	flash_sphere(tree, origin, r, color, MatchConfig.get_value("debug.viz.muzzle_duration_s"))


func flash_hit_marker(tree: SceneTree, pos: Vector3, damage: float, zone: String) -> void:
	if not enabled() or tree == null:
		return
	# Small cross: two short flash_lines or a tiny sphere + Label3D for damage if show_damage_pips
	var dur := MatchConfig.get_value("debug.viz.hit_marker_duration_s")
	var col := zone_tracer_color(zone, true)
	# marker geometry...
	if MatchConfig.get_value("debug.viz.show_damage_pips") > 0.5:
		_spawn_damage_label(tree, pos, damage, dur)


func owner_color(peer_id: int) -> Color:
	var h := fmod(float(absi(peer_id) * 0.6180339887), 1.0)
	return Color.from_hsv(h, 0.55, 0.95, 0.35)


func _track_fx(node: Node, tree: SceneTree, duration_s: float) -> void:
	_active_fx.append(node)
	var cap := int(MatchConfig.get_value("debug.viz.max_active_fx"))
	while _active_fx.size() > cap:
		var old: Node = _active_fx.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	tree.create_timer(duration_s).timeout.connect(func() -> void:
		_active_fx.erase(node)
		if is_instance_valid(node):
			node.queue_free()
	)
```

Update `flash_line` callers that assumed free-on-timer only — unify on `_track_fx`.

Extend `gameplay_materials()` / ShaderPrewarm for head/limb colors if new materials appear.

- [ ] **Step 4: Tests PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(viz): tracers, muzzle, hit markers, FX pool, zone colors"
```

---

### Task 3: Confirmed gun/blade FX emission (local authority path)

**Files:**
- Modify: `scripts/weapons/weapon_base.gd` (`_hitscan`)
- Modify: `scripts/weapons/blade.gd`
- Create: `tests/dev/test_combat_fx_emit.gd` (or extend weapon tests)

**Interfaces:**
- Consumes: `PlaytestViz.*`, later `PlaytestFxBus.emit_hitscan(...)` (Task 4 may introduce bus first with local-only apply).
- **Confirmed damage rule:** Call hit marker **after** `take_zone_damage` / `take_familiar_damage` with the **actual damage amount applied** (same float passed into damage API, post-falloff). Do not invent a second estimate. Only emit presentation when `is_fresh` (local sim presentation frame) **or** when invoked from bus receive (Task 4).

- [ ] **Step 1: Failing test**

```gdscript
# tests/dev/test_combat_fx_emit.gd
func test_hitscan_zone_color_helper_maps_head() -> void:
	assert_that(PlaytestViz.zone_tracer_color("head", true)).is_not_equal(
		PlaytestViz.zone_tracer_color("body", true)
	)
```

Behavioral (SceneRunner) optional if headless skips meshes — prefer testing pure helpers + that weapon code calls a testable seam:

```gdscript
# In weapon_base, extract:
# func _present_hitscan_fx(from, hit_pos, zone, damage, hit_player, is_fresh) -> void
```

Unit-test `_present_hitscan_fx` via a stub counter on `PlaytestFxBus` once bus exists; for Task 3, implement presentation through `PlaytestViz` directly and:

```gdscript
func test_present_hitscan_skips_when_not_fresh() -> void:
	# Call seam with is_fresh=false; assert no increase in PlaytestViz active fx count if you expose active_count()
	pass
```

Expose `PlaytestViz.active_fx_count() -> int` for tests.

- [ ] **Step 2: Run — FAIL until seam exists**

- [ ] **Step 3: Wire `weapon_base.gd`**

Replace bare `flash_line` block with:

```gdscript
	var zone_name := ""
	var applied_damage := 0.0
	# ... inside hit branches, set zone_name from meta and applied_damage from computed dmg ...
	if is_fresh:
		_present_hitscan_fx(from, hit_pos, zone_name, applied_damage, hit_player)


func _present_hitscan_fx(
		from: Vector3, hit_pos: Vector3, zone: String, damage: float, hit_player: bool
) -> void:
	if not PlaytestViz.enabled():
		return
	var col := PlaytestViz.zone_tracer_color(zone, hit_player)
	var tree := _controller().get_tree()
	PlaytestViz.flash_line(tree, from, hit_pos, col)
	PlaytestViz.flash_muzzle(tree, from)
	if hit_player and damage > 0.0:
		PlaytestViz.flash_hit_marker(tree, hit_pos, damage, zone if zone != "" else "body")
	# Combat log + bus in later tasks — call hooks if available:
	if Engine.has_singleton("PlaytestFxBus") or true:
		if PlaytestFxBus != null and PlaytestFxBus.has_method("notify_hitscan"):
			PlaytestFxBus.notify_hitscan(
				_controller().get_multiplayer_authority(), from, hit_pos, zone, damage, hit_player,
				weapon_key
			)
```

**Note:** Until Task 4 registers the autoload, guard with `is_instance_valid` / optional call. Prefer implementing Task 4 immediately after Task 3 in the same agent session if imports break — order is Task 3 local viz first, Task 4 bus wraps `notify_*`.

Blade: on confirmed hit, colored line + hit marker with blade damage.

- [ ] **Step 4: Tests PASS; manual arena smoke optional**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(viz): confirmed hitscan/blade presentation with zone colors and muzzle"
```

---

### Task 4: `PlaytestFxBus` — host-forced session + replicate FX

**Files:**
- Create: `scripts/dev/playtest_fx_bus.gd`
- Modify: `project.godot` (autoload after `PlaytestViz`)
- Modify: `scripts/session/match_session.gd` (setup + host push on ready/start)
- Create: `tests/dev/test_playtest_fx_bus.gd`

**Interfaces:**
- Produces:
  - `PlaytestFxBus.setup() -> void`
  - `PlaytestFxBus.session_viz_forced() -> bool` — true when host policy requires viz
  - `PlaytestFxBus.apply_host_policy(forced_on: bool) -> void` — host only
  - `PlaytestFxBus.effective_enabled() -> bool` — used by `PlaytestViz.enabled()` after this task
  - `notify_hitscan(owner_peer, from, to, zone, damage, hit_player, weapon_key) -> void`
  - `notify_muzzle(owner_peer, origin) -> void` (optional if bundled in hitscan)
  - `notify_generic(kind: StringName, payload: Dictionary) -> void`
  - RPC: `@rpc("any_peer", "unreliable", "call_remote")` or authority-relay pattern:
    - **Recommended:** shooter peer sends to host `request_fx`, host validates rate limit and `rpc`s `broadcast_fx` to all (including spectators). Offline: local apply only.
  - Combat log ring buffer: `push_log(text: String) -> void`, `log_lines() -> PackedStringArray`

**Host-forced policy:**
1. On match start, if host and `debug.viz.host_force_session > 0.5`, host sets session flag from host’s `debug.playtest_viz`.
2. Host RPCs reliable `sync_viz_policy(forced: bool, master_on: bool)` to all peers.
3. Clients set local effective gate: `master_on` when forced; ignore client-only desire to disable while forced.
4. `PlaytestViz.enabled()` becomes:

```gdscript
func enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if _release_mode():
		return false
	if PlaytestFxBus.session_active():
		return PlaytestFxBus.session_viz_on()
	return MatchConfig.get_value("debug.playtest_viz") > 0.5
```

- [ ] **Step 1: Failing tests**

```gdscript
class_name TestPlaytestFxBus
extends GdUnitTestSuite


func before_test() -> void:
	MatchConfig.reset_to_defaults()
	PlaytestFxBus.reset_for_tests()


func test_host_policy_forces_clients() -> void:
	PlaytestFxBus.apply_host_policy(true, true)  # forced, on
	assert_bool(PlaytestFxBus.session_viz_on()).is_true()
	MatchConfig.set_value("debug.playtest_viz", 0.0)  # client local off
	assert_bool(PlaytestFxBus.session_active()).is_true()
	assert_bool(PlaytestViz.enabled() or PlaytestFxBus.session_viz_on()).is_true()


func test_notify_hitscan_pushes_log() -> void:
	PlaytestFxBus.reset_for_tests()
	PlaytestFxBus.apply_host_policy(true, true)
	PlaytestFxBus.notify_hitscan(1, Vector3.ZERO, Vector3.FORWARD, "body", 12.0, true, "pistol")
	var lines := PlaytestFxBus.log_lines()
	assert_int(lines.size()).is_greater(0)
	assert_str(lines[lines.size() - 1]).contains("pistol")
```

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement bus + wire match session**

```gdscript
# scripts/dev/playtest_fx_bus.gd
extends Node
# Autoload PlaytestFxBus — presentation only.

var _session_active: bool = false
var _session_viz_on: bool = false
var _log: PackedStringArray = PackedStringArray()
var _fx_budget: int = 0


func reset_for_tests() -> void:
	_session_active = false
	_session_viz_on = false
	_log.clear()
	_fx_budget = 0


func session_active() -> bool:
	return _session_active


func session_viz_on() -> bool:
	return _session_viz_on


func apply_host_policy(forced: bool, viz_on: bool) -> void:
	_session_active = forced
	_session_viz_on = viz_on and forced


func notify_hitscan(
		owner_peer: int, from: Vector3, to: Vector3, zone: String, damage: float,
		hit_player: bool, weapon_key: String
) -> void:
	if not PlaytestViz.enabled():
		return
	_push_log("%s %s %.0f" % [weapon_key, zone if hit_player else "miss", damage if hit_player else 0.0])
	# Local already drew in weapon_base; remotes need RPC:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	if MatchConfig.get_value("debug.viz.replicate") <= 0.5:
		return
	_send_hitscan.rpc(owner_peer, from, to, zone, damage, hit_player, weapon_key)


@rpc("any_peer", "call_remote", "unreliable")
func _send_hitscan(
		owner_peer: int, from: Vector3, to: Vector3, zone: String, damage: float,
		hit_player: bool, weapon_key: String
) -> void:
	if not PlaytestViz.enabled():
		return
	if owner_peer == multiplayer.get_unique_id():
		return  # already drew locally
	var col := PlaytestViz.zone_tracer_color(zone, hit_player)
	PlaytestViz.flash_line(get_tree(), from, to, col)
	PlaytestViz.flash_muzzle(get_tree(), from)
	if hit_player and damage > 0.0:
		PlaytestViz.flash_hit_marker(get_tree(), to, damage, zone)
	_push_log("%s %s %.0f (p%d)" % [weapon_key, zone, damage, owner_peer])
```

Host policy sync (reliable):

```gdscript
func host_publish_policy() -> void:
	if not _is_host():
		return
	var forced := MatchConfig.get_value("debug.viz.host_force_session") > 0.5
	var on := MatchConfig.get_value("debug.playtest_viz") > 0.5
	apply_host_policy(forced, on)
	_sync_policy.rpc(forced, on)


@rpc("authority", "call_remote", "reliable")
func _sync_policy(forced: bool, on: bool) -> void:
	apply_host_policy(forced, on)
```

Call `host_publish_policy()` from `match_session.gd` when the host starts the match / scene ready.

Integrate `PlaytestViz.enabled()` with bus session (Task 1 follow-up edit).

- [ ] **Step 4: Tests PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(viz): PlaytestFxBus host-forced policy and hitscan FX replication"
```

---

### Task 5: Ability silhouettes, Slip ghost, Reclaim flash, Smart Rig wedge, fields/familiar/grenade

**Files:**
- Modify: `scripts/player/fps_controller.gd`
- Modify: `scripts/abilities/placed_field.gd`
- Modify: `scripts/abilities/familiar.gd`
- Modify: `scripts/weapons/grenade.gd`
- Modify: `scripts/abilities/corpse.gd` (optional drag line)
- Test: `tests/dev/test_playtest_viz.gd`, ability tests only if pure helpers added

**Interfaces:**
- State silhouettes: each frame or on state edge in `_process` (view only), tint mesh when `is_wraithed` / `is_gliding` / `overclock_active` if `debug.viz.show_state_silhouettes`.
- Slip: after successful blink, `PlaytestViz.flash_slip_ghost` + line from start to end; `PlaytestFxBus` generic notify.
- Reclaim: on cast, flash disc/sphere `reclaim.radius_m`.
- **Smart Rig wedge (Phase B required):** when `smart_rig_active` and viz on, draw a debug wedge or cone in aim direction using `debug.viz.smart_rig_wedge_deg` and `debug.viz.smart_rig_wedge_range_m` (ImmediateMesh fan or two edge lines + arc). Must not deal damage.
- Fields: multiply disc color by `PlaytestViz.owner_color(owner_peer)`.
- Familiar: `Label3D` or billboard with FOLLOW/GUARD/HUNT.
- Grenade: in `_process` or tick presentation, every `grenade_trail_interval_s` spawn a tiny sphere along path while not detonated.

- [ ] **Step 1: Failing test for Smart Rig wedge config + silhouette flag**

```gdscript
func test_smart_rig_wedge_defaults() -> void:
	MatchConfig.reset_to_defaults()
	assert_float(MatchConfig.get_value("debug.viz.show_smart_rig_wedge")).is_equal(1.0)
	assert_float(MatchConfig.get_value("debug.viz.smart_rig_wedge_range_m")).is_equal(40.0)
```

- [ ] **Step 2: Run — PASS if Task 1 done; else add keys**

- [ ] **Step 3: Implement presentation hooks**

Example Slip (after successful teleport in controller):

```gdscript
	if is_fresh and PlaytestViz.enabled() and MatchConfig.get_value("debug.viz.show_slip_ghost") > 0.5:
		PlaytestViz.flash_line(get_tree(), start_pos, global_position, Color(0.2, 1.0, 0.4, 0.7))
		PlaytestViz.flash_slip_ghost(get_tree(), global_position)
		PlaytestFxBus.notify_generic(&"slip", {
			"from": start_pos, "to": global_position, "peer": input.get_multiplayer_authority()
		})
```

Smart Rig wedge in `_process` when active (view only):

```gdscript
func _draw_smart_rig_wedge() -> void:
	if not PlaytestViz.enabled():
		return
	if MatchConfig.get_value("debug.viz.show_smart_rig_wedge") <= 0.5:
		return
	if not smart_rig_active:
		return
	# Update or recreate a child ImmediateMesh wedge under camera; clear when inactive.
```

- [ ] **Step 4: Manual/MCP smoke: Slip ghost visible; Smart Rig wedge visible when equipped**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(viz): ability silhouettes, Slip/Reclaim FX, Smart Rig wedge, field ownership colors"
```

---

### Task 6: Combat log HUD + Dev Arsenal toggle

**Files:**
- Modify: `scripts/ui/player_hud.gd`, `scenes/ui/player_hud.tscn`
- Modify: `scripts/ui/dev_arsenal.gd` (+ scene if needed)
- Test: `tests/ui/test_player_hud.gd`

**Interfaces:**
- HUD reads `PlaytestFxBus.log_lines()` each frame when viz enabled; shows last N lines in a top-left or bottom `RichTextLabel` / `Label`.
- Dev Arsenal: checkbox “Playtest Viz” sets `MatchConfig.set_value("debug.playtest_viz", 1|0)` and if host, re-calls `PlaytestFxBus.host_publish_policy()`.

- [ ] **Step 1: Failing test**

```gdscript
func test_combat_log_format_helper() -> void:
	# If HUD exposes a pure formatter:
	assert_str(PlayerHud.format_combat_log_line("pistol", "body", 12.0)).contains("12")
```

Or test bus log → HUD property after `push_log`.

- [ ] **Step 2: FAIL then implement UI**

- [ ] **Step 3: Wire HUD**

```gdscript
func _process(_delta: float) -> void:
	# existing...
	if PlaytestViz.enabled() and _combat_log_label != null:
		_combat_log_label.visible = true
		_combat_log_label.text = "\n".join(PlaytestFxBus.log_lines())
	elif _combat_log_label != null:
		_combat_log_label.visible = false
```

- [ ] **Step 4: Tests PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(viz): combat log HUD and Dev Arsenal playtest viz toggle"
```

---

### Task 7: Release strip, prewarm, docs, dual-peer verification

**Files:**
- Modify: `tests/dev/test_release_strip.gd`
- Modify: `scripts/dev/shader_prewarm.gd` (if not done)
- Modify: `README.md` (playtest viz table)
- Modify: `docs/TESTING.md`
- Modify: `docs/ABILITY_TUNING_SHEET.md` §9 (implementation note)
- Optional: `tests/e2e/fx_smoke.py` or extend `net_smoke.py`

- [ ] **Step 1: Release strip test**

```gdscript
func test_playtest_viz_disabled_in_release() -> void:
	OS.set_environment("COUNTERSPELL_RELEASE", "1")
	assert_bool(PlaytestViz.enabled()).is_false()
	OS.set_environment("COUNTERSPELL_RELEASE", "")
```

- [ ] **Step 2: Run affected suites**

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot \
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s -d \
  addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a ./tests/dev \
  -a ./tests/weapons \
  -a ./tests/ui/test_player_hud.gd \
  -a ./tests/abilities/test_placed_field.gd \
  --ignoreHeadlessMode
```

Expected: `0 errors | 0 failures`.

- [ ] **Step 3: Update README table**

Document: longer tracers, zone colors, muzzle, confirmed damage pips, host-forced multiplayer FX, combat log, Smart Rig wedge, ability silhouettes, `debug.viz.*` keys, release off.

- [ ] **Step 4: Two-peer check (manual or script)**

```bash
# Document in TESTING.md:
# Terminal A/B: two instances net_test or match_session ENet
# Host keeps debug.playtest_viz=1; client should receive policy and see host tracers.
```

If automating: assert FX RPC handler increments a test counter on peer B (injection hook `PlaytestFxBus._test_remote_fx_count`).

- [ ] **Step 5: Commit**

```bash
git commit -m "docs(viz): playtest combat suite README/TESTING; release-strip coverage"
```

---

## Implementation order summary

| Task | Phase (PRD) | Deliverable |
|------|-------------|-------------|
| 1 | A foundation | Config + release gate |
| 2 | A | Viz primitives + pool |
| 3 | A | Confirmed local gun/blade FX |
| 4 | C (early) | Host-forced bus + replicate hitscan |
| 5 | B | Silhouettes, Slip, Reclaim, **Smart Rig wedge**, fields, grenade, familiar |
| 6 | B/D | Combat log + Dev Arsenal toggle |
| 7 | D | Strip, docs, multiplayer verify |

Task 4 is intentionally before Task 5 so ability FX can reuse `notify_generic` without a second networking pass.

---

## Spec coverage checklist

| PRD area | Task |
|----------|------|
| Longer zone-colored tracers | 2, 3 |
| Muzzle stub | 2, 3 |
| Confirmed damage pips + hit markers | 2, 3 |
| Blade FX | 3 |
| Host-forced session viz | 4 |
| Peer-visible tracers | 4 |
| Wraith/Glide/Overclock silhouettes | 5 |
| Slip ghost, Reclaim flash | 5 |
| Smart Rig wedge (Phase B) | 5 |
| Field owner colors | 5 |
| Grenade trail, Familiar label | 5 |
| Combat log HUD | 6 |
| Dev toggle | 6 |
| Release strip + docs | 7 |
| No audio | Global |
| No rollback FX state | Global / 4 |

---

## Self-review notes

- No TBD placeholders left for locked decisions (host force, confirmed pips, Smart Rig Phase B).  
- Types: `PlaytestFxBus.notify_hitscan(owner_peer: int, from: Vector3, to: Vector3, zone: String, damage: float, hit_player: bool, weapon_key: String)`.  
- Double-draw guard: local `is_fresh` draw + RPC skip if `owner_peer == unique_id`.  
- Confirmed damage: pip uses post-falloff damage float actually applied in the same branch as `take_zone_damage`.  
