# Agent setup

Codex and Claude share `AGENTS.md`. `CLAUDE.md` imports it so project conventions have one maintained source. The repository-local Godot skill is `.agents/skills/godot-development/SKILL.md`; Codex discovers it automatically, and Claude can read it through the shared instructions.

## Godot tools in Codex

`.codex/config.toml` registers the same Node stdio server as `.mcp.json`. All server tools remain available, including project launch, diagnostics, runtime inputs, property inspection, evaluation, and screenshots.

1. Open this repository as a trusted project in Codex. Restart the MCP connection or start a new session after installing this configuration.
2. Run `codex mcp get godot` from the repository to inspect the effective configuration; use `/mcp` in the CLI to inspect connection status.
3. The server requires Node >= 18 and `tools/godot-mcp/build/index.js`. The existing vendored checkout is gitignored. If missing, follow the upstream source link in `docs/TESTING.md` to restore `tools/godot-mcp`, then run `npm install` and `npm run build` there. This checkout has local MCP changes, including port selection; preserve those when rebuilding or replacing it.
4. The checked-in `cwd` targets this local checkout so launching from a subdirectory works. Update it if moving/cloning the repository elsewhere, and adjust `GODOT_PATH` for another platform.
5. Keep the command, engine path, and port aligned between `.mcp.json` and `.codex/config.toml`. Both currently use port **9292**. For a game started manually:

   ```bash
   GODOT_MCP_PORT=9292 /Applications/Godot.app/Contents/MacOS/Godot --path .
   ```

Two agents controlling the same port control the same game. For separate instances, assign distinct ports to each server/game pair. The E2E harness already manages its own ports.

## Migration coverage

| Existing configuration | Codex equivalent |
| --- | --- |
| Root `CLAUDE.md` project conventions | Shared `AGENTS.md`, imported by Claude |
| Nested GdUnit assertion instructions | Explicit scoped reference in `AGENTS.md` |
| `.mcp.json` Godot server | `.codex/config.toml` Godot server |
| Personal Claude Godot skill | Repository-local `godot-development` skill, updated for current project conventions |
| Superpowers specs, plans, and resume notes | Preserved as project context, linked from `AGENTS.md` |
| `.claude/settings.local.json` tool approvals | Codex session permissions and approval rules; no direct import |

The repository's Claude settings contain accumulated tool approvals and a Godot server enablement entry, with no repo-defined hooks or custom agent roles. Plugin-specific commands referenced in historical approvals are not repository implementations. Codex uses its built-in shell, editing, search, and Git workflows; no global Claude plugins or personal configuration are modified here.

Model choice and sandbox policy remain controlled by the user's Codex setup. Project MCP configuration loads only for trusted projects; writing it does not attach new tools to an already-running conversation. The vendored server and live game must both be available to verify runtime interaction.

Official references: [project MCP configuration](https://learn.chatgpt.com/docs/extend/mcp?surface=cli), [repository skills](https://learn.chatgpt.com/docs/build-skills), and [AGENTS.md discovery](https://learn.chatgpt.com/docs/agent-configuration/agents-md).
