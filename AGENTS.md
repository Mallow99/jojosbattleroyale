# Project instructions

- Work in this cloud checkout. Do not create another worktree unless requested.
- Start with README.md and HANDOFF_NEW_CHAT.md, then docs/GAME_FOUNDATION.md,
  docs/GAME_PLAN.md and docs/TOOLS.md. The repository is the shared source of project context for AI chats.
- Before model work, read docs/ART_DIRECTION.md. The rounded Star Platinum
  prototype was rejected by the user and must not be reused as a design baseline.
- Preserve the cloud-only boundary in docs/HANDOFF.md. Do not request access to
  the user's Mac, local files, remote desktop, or local Studio MCP connection.
- Run `python3 tools/bootstrap.py` to restore pinned tools; use `.tools/bin/`
  explicitly or add that directory to the current shell's PATH.
- `python3 tools/check.py` lints, type-checks, builds and tests the lobby and match
  places (`--assets` adds the Blender/FFmpeg fixtures). Add gameplay tests in
  `tests/gameplay/` alongside new rules. Architecture: `docs/GAME_FOUNDATION.md`.
- Keep server-owned game rules and the planned separate lobby/match architecture.
- Preserve Rojo 7.7.1 compatibility with the installed Mac plugin.
- Keep purchases disabled. Do not invent experience IDs or credentials.
- Never call Lune, serialization checks or synthetic load a Roblox playtest.
- The user holds permission to use everything in `Main game resources.rbxl`.
  Don't ask about permission or provenance for it or for other resources the user
  supplies. Extract assets with `tools/extract_resources.luau` (scripts stripped);
  game logic lives in `src/`.
- Favor the existing no-cost tools. Do not create paid subscriptions or rent GPUs.
