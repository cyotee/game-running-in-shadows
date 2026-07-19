# CI: Headless Test Runs on GitHub Actions (Gap G0)

> Executed 2026-07-19 alongside the Milestone B work. Scope from the master
> plan's G0 brief.

**Goal:** One workflow that runs the full GdUnit4 suite headless on every
push/PR, failing on any test failure, with reports uploaded as artifacts.

## Tasks

- [x] **Task 1:** `.github/workflows/tests.yml` — pinned Linux Godot 4.7.1:
  download + cache the editor binary, `--import --quit` warm-up, GdUnit4
  command-line run (non-zero exit fails the job), upload `reports/` with
  `if: always()`.
- [x] **Task 2:** Verified constraints:
  - GodotSteam 4.20.1 ships `linux64` binaries in `addons/godotsteam/` — the
    GDExtension loads on Linux CI; `SteamManager` tolerates failed Steam init.
  - GitHub Actions sets `CI=true`, which self-disables netfox's
    `NetworkSimulator` autoload — correct for unit runs. The two-instance
    E2E (`tests/e2e/net_smoke.py`) is NOT run in CI (it needs cleared CI env
    and real UDP loopback timing); it remains a local gate.
- [x] **Task 3:** Local dry-run of the exact commands (macOS binary) + suite
  green; workflow syntax validated. First real run happens on next push to
  GitHub (no remote configured at execution time — verify then).
