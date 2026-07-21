# G13 — Release strip / EAC hooks (partial)

**Status:** EXECUTED (hooks + strip path) 2026-07-20

## Shipped
- `McpInteractionServer` no-ops when `COUNTERSPELL_RELEASE=1` or
  ProjectSettings `counterspell/release_build=true`.
- `InputTrace` similarly disabled in release.
- Headless tests tolerate failed Steam init (unchanged).

## EAC / EOS
- No SDK vendored in-repo (credentials/environment dependent).
- Integration point: call host-only ban/report from MatchState kill/score
  authority paths once EOS SDK is linked in a release export preset.
- Documented OWNER step: add EOS plugin + keys outside this repository.

## Verify
```bash
COUNTERSPELL_RELEASE=1 /Applications/Godot.app/Contents/MacOS/Godot --path . --quit-after 120
# Log should contain: McpInteractionServer: disabled (release build)
```
